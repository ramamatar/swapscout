from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import List
from datetime import date

from database import get_db
from models import User, SwapRequest, SwapRequestStatus, HomeBooking, Notification
from schemas.swap_request_schemas import (
    SwapRequestCreate,
    SwapRequestUpdate,
    SwapRequestOut
)

# Standard auth via middleware token validation
from auth_middleware import get_current_user
from sockets import manager

router = APIRouter(
    prefix="/swap-requests",
    tags=["swap_requests"]
)

@router.post("/", response_model=SwapRequestOut, status_code=status.HTTP_201_CREATED)
def create_swap_request(
    request_data: SwapRequestCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Initiate a new swap request. The current user becomes the requester natively.
    """
    if current_user.id == request_data.host_id:
        raise HTTPException(status_code=400, detail="Cannot send a swap request to yourself.")

    # Create the Swap Request record matching enum parameters
    new_request = SwapRequest(
        requester_id=current_user.id,
        host_id=request_data.host_id,
        requester_home_id=request_data.requester_home_id,
        host_home_id=request_data.host_home_id,
        start_date=request_data.start_date,
        end_date=request_data.end_date,
        intro_message=request_data.intro_message,
        status=SwapRequestStatus.PENDING
    )
    
    db.add(new_request)
    
    # 2. Automatically generate the persistent database Notification
    new_notification = Notification(
        user_id=request_data.host_id,
        message="You have a new home swap request!",
        type="swap_request",
        is_read=False
    )
    db.add(new_notification)
    
    db.commit()
    db.refresh(new_request)
    
    # Notify User B in the background
    msg = {"type": "new_request", "message": "You have a new home swap request!"}
    background_tasks.add_task(manager.send_personal_message, msg, request_data.host_id)
    
    return new_request


@router.get("/me", response_model=List[SwapRequestOut])
def get_my_swap_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Fetch all swap requests involving the current user natively across dual axes.
    """
    requests = db.query(SwapRequest).filter(
        or_(
            SwapRequest.requester_id == current_user.id,
            SwapRequest.host_id == current_user.id
        )
    ).order_by(SwapRequest.created_at.desc()).all()
    
    # Auto-advance state machine for accepted requests whose end date has passed
    today = date.today()
    updated = False
    for req in requests:
        if req.status == SwapRequestStatus.ACCEPTED:
            # If the end_date is strictly before today, it is completed
            if req.end_date < today:
                req.status = SwapRequestStatus.COMPLETED
                updated = True
                
    if updated:
        db.commit()
    
    return requests


@router.patch("/{request_id}/status", response_model=SwapRequestOut)
def update_swap_request_status(
    request_id: int,
    update_data: SwapRequestUpdate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Strictly updates the state of a swap request checking constraints natively.
    Only involved parties can manipulate the state.
    Terminal states represent an absolute lock gracefully throwing 400 Bad Requests if bypassed.
    """
    swap_request = db.query(SwapRequest).filter(SwapRequest.id == request_id).first()
    
    if not swap_request:
        raise HTTPException(status_code=404, detail="Swap request not found")
        
    if current_user.id not in [swap_request.requester_id, swap_request.host_id]:
        raise HTTPException(status_code=403, detail="Not authorized to modify this swap request")
        
    old_status = swap_request.status
    new_status = update_data.status
    
    # State Machine Restrictions!
    terminal_states = [SwapRequestStatus.DECLINED, SwapRequestStatus.CANCELED, SwapRequestStatus.COMPLETED]
    
    if old_status in terminal_states:
        raise HTTPException(
            status_code=400, 
            detail=f"Transition rejected. Request is already securely anchored in {old_status.value}."
        )
        
    # Valid Transitions
    if old_status == SwapRequestStatus.PENDING:
        if new_status not in [SwapRequestStatus.ACCEPTED, SwapRequestStatus.DECLINED, SwapRequestStatus.CANCELED]:
            raise HTTPException(status_code=400, detail=f"Cannot transition from pending directly to {new_status.value}")
            
    elif old_status == SwapRequestStatus.ACCEPTED:
        if new_status not in [SwapRequestStatus.CANCELED, SwapRequestStatus.COMPLETED]:
            raise HTTPException(status_code=400, detail=f"Accepted requests can strictly only be marked as canceled or completed.")
            
    # Auto-Lockdown Intercept Strategy
    if new_status == SwapRequestStatus.ACCEPTED and old_status != SwapRequestStatus.ACCEPTED:
        # 1. Conflict checking
        overlap = db.query(HomeBooking).filter(
            HomeBooking.home_id.in_([swap_request.host_home_id, swap_request.requester_home_id]),
            HomeBooking.start_date <= swap_request.end_date,
            HomeBooking.end_date >= swap_request.start_date
        ).first()

        if overlap:
            raise HTTPException(
                status_code=409,
                detail=f"Warning: This overlap cannot be accepted because one of the homes (ID: {overlap.home_id}) is already booked for these exact dates."
            )

        # 2. Block the dates atomically
        host_booking = HomeBooking(
            home_id=swap_request.host_home_id,
            start_date=swap_request.start_date,
            end_date=swap_request.end_date
        )
        requester_booking = HomeBooking(
            home_id=swap_request.requester_home_id,
            start_date=swap_request.start_date,
            end_date=swap_request.end_date
        )
        db.add(host_booking)
        db.add(requester_booking)

        # 3. Auto decline other overlapping pending requests
        db.query(SwapRequest).filter(
            SwapRequest.id != swap_request.id,
            SwapRequest.status == SwapRequestStatus.PENDING,
            or_(
                SwapRequest.host_home_id.in_([swap_request.host_home_id, swap_request.requester_home_id]),
                SwapRequest.requester_home_id.in_([swap_request.host_home_id, swap_request.requester_home_id])
            ),
            SwapRequest.start_date <= swap_request.end_date,
            SwapRequest.end_date >= swap_request.start_date
        ).update({"status": SwapRequestStatus.DECLINED}, synchronize_session=False)

        # 4. Generate persistent notification for User A (Requester)
        accept_notification = Notification(
            user_id=swap_request.requester_id,
            message="Your swap was accepted!",
            type="swap_accepted",
            is_read=False
        )
        db.add(accept_notification)
        
        # PUSH Real-Time websocket notification to User A
        msg = {"type": "swap_accepted", "message": "Your swap was accepted!"}
        background_tasks.add_task(manager.send_personal_message, msg, swap_request.requester_id)

    # Apply and commit safely! Single unified transaction lock.
    swap_request.status = new_status
    db.commit()
    db.refresh(swap_request)
    
    return swap_request
