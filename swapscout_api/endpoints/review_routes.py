from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import exc

from database import get_db
from models import User, SwapRequest, SwapRequestStatus, Review, Home
from auth_middleware import get_current_user
from schemas.review_schemas import ReviewCreate, ReviewResponse

router = APIRouter(prefix="/reviews", tags=["Reviews"])

@router.post("/", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
def submit_review(
    review_data: ReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 1. Validation lock: Check SwapRequest exists and is COMPLETED
    swap_request = db.query(SwapRequest).filter(SwapRequest.id == review_data.swap_request_id).first()
    if not swap_request:
        raise HTTPException(status_code=404, detail="Swap Request not found.")

    if swap_request.status != SwapRequestStatus.COMPLETED:
        raise HTTPException(
            status_code=400, 
            detail="You can only leave a review for fully completed swaps."
        )

    # 2. Validation lock: Check participant authority
    if current_user.id not in [swap_request.host_id, swap_request.requester_id]:
        raise HTTPException(status_code=403, detail="You were not a participant in this swap.")

    # Assign reviewee natively
    reviewee_id = swap_request.host_id if current_user.id == swap_request.requester_id else swap_request.requester_id

    # Validate Rating integer natively
    if review_data.rating < 1 or review_data.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be strictly between 1 and 5.")

    # 3. Apply Submission Safely
    new_review = Review(
        swap_request_id=swap_request.id,
        reviewer_id=current_user.id,
        reviewee_id=reviewee_id,
        home_id=review_data.home_id,
        rating=review_data.rating,
        comment=review_data.comment
    )

    db.add(new_review)

    try:
        db.commit()
        db.refresh(new_review)
    except exc.IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="You have already reviewed this swap."
        )

    # 4. Aggregation Lock: Update Home Ratings natively gracefully
    home = db.query(Home).filter(Home.id == review_data.home_id).first()
    if home:
        total = db.query(Review).filter(Review.home_id == home.id).count()
        # Postgres returns None on sum if table is empty, handle safely
        from sqlalchemy import func
        avg = db.query(func.avg(Review.rating)).filter(Review.home_id == home.id).scalar()
        
        home.total_reviews = total
        home.average_rating = round(avg, 1) if avg else 0.0
        db.commit()

    return new_review

@router.get("/homes/{home_id}", response_model=list[ReviewResponse])
def get_home_reviews(
    home_id: int,
    db: Session = Depends(get_db)
):
    reviews = db.query(Review).filter(Review.home_id == home_id).order_by(Review.created_at.desc()).all()
    
    # We dynamically attach reviewer_name for the UI without massive refactoring easily
    out = []
    for r in reviews:
        reviewer = db.query(User).filter(User.id == r.reviewer_id).first()
        name = "Unknown"
        if reviewer and reviewer.email:
            name = reviewer.email.split('@')[0].capitalize()
        
        rout = ReviewResponse.model_validate(r)
        rout.reviewer_name = name
        out.append(rout)
        
    return out

@router.get("/swap-request/{swap_request_id}/my-review", response_model=ReviewResponse)
def get_my_review_for_swap(
    swap_request_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    review = db.query(Review).filter(
        Review.swap_request_id == swap_request_id,
        Review.reviewer_id == current_user.id
    ).first()
    
    if not review:
        raise HTTPException(status_code=404, detail="Review not found.")
        
    rout = ReviewResponse.model_validate(review)
    rout.reviewer_name = "You"
    return rout
