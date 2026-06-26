from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from auth_middleware import get_current_user, get_db
from models import User, Home, SwapRequest, Favorite
from schemas.user_schemas import UserResponse, UserUpdate, PublicUserWithHomesResponse, InsightsResponse
from schemas.home_schemas import HomeResponse
from sqlalchemy import or_

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserResponse)
def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
def update_my_profile(
    updates: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    for field, value in updates.dict(exclude_unset=True).items():
        setattr(current_user, field, value)

    db.commit()
    db.refresh(current_user)
    return current_user

@router.get("/me/insights", response_model=InsightsResponse)
def get_my_insights(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    total_swaps = db.query(SwapRequest).filter(
        or_(SwapRequest.requester_id == current_user.id, SwapRequest.host_id == current_user.id),
        SwapRequest.status.in_(["accepted", "completed"])
    ).count()

    pending_requests = db.query(SwapRequest).filter(
        SwapRequest.host_id == current_user.id,
        SwapRequest.status == "pending"
    ).count()

    favorites_count = db.query(Favorite).filter(
        Favorite.user_id == current_user.id
    ).count()

    accepted_swaps = db.query(SwapRequest).filter(
        or_(SwapRequest.requester_id == current_user.id, SwapRequest.host_id == current_user.id),
        SwapRequest.status == "accepted"
    ).count()

    declined_swaps = db.query(SwapRequest).filter(
        or_(SwapRequest.requester_id == current_user.id, SwapRequest.host_id == current_user.id),
        SwapRequest.status == "declined"
    ).count()

    total_decided = accepted_swaps + declined_swaps
    match_success_rate = int((accepted_swaps / total_decided) * 100) if total_decided > 0 else 0

    return {
        "total_swaps": total_swaps,
        "pending_requests": pending_requests,
        "favorites_count": favorites_count,
        "match_success_rate": match_success_rate
    }


@router.get("/{user_id}/public", response_model=PublicUserWithHomesResponse)
def get_public_profile(
    user_id: int,
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    homes = db.query(Home).filter(
        Home.owner_id == user_id,
        Home.is_hidden == False
    ).all()
    
    # We dynamically serialize Home schemas safely here
    serialized_homes = [HomeResponse.model_validate(h) for h in homes]

    return {
        "user": user,
        "homes": serialized_homes
    }
