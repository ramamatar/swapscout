from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from database import get_db
from models import Match, TripPreference, User, Home
from auth_middleware import get_current_user
from services.match_service import find_matches
from schemas.match_schemas import MatchCreate, MatchResponse


router = APIRouter(prefix="/matches", tags=["Matches"])
@router.get("/")
def get_matches(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    preference = db.query(TripPreference).filter(
        TripPreference.user_id == current_user.id
    ).first()

    if not preference:
        return {"matches": []}
    
    matches = find_matches(db, preference, current_user.id)
    if not matches:
        return {"matches": []}

    return {
        "matches": matches
    }
@router.post("/", response_model=MatchResponse, status_code=201)
def create_match_request(
    data: MatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Get the home
    home = db.query(Home).filter(Home.id == data.home_id).first()
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")
    
    # Can't match with your own home
    if home.owner_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot match with your own home")
    
    # Check if match already exists
    existing_match = db.query(Match).filter(
        or_(
            and_(Match.user_a_id == current_user.id, Match.user_b_id == home.owner_id),
            and_(Match.user_a_id == home.owner_id, Match.user_b_id == current_user.id)
        )
    ).first()
    
    if existing_match:
        raise HTTPException(status_code=400, detail="Match request already exists")
    
    # Create match request (current user is user_a, home owner is user_b)
    match = Match(
        user_a_id=current_user.id,
        user_b_id=home.owner_id,
        status="pending"
    )
    db.add(match)
    db.commit()
    db.refresh(match)
    
    return match


@router.post("/{match_id}/accept", response_model=MatchResponse)
def accept_match(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.match_id == match_id).first()

    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if current_user.id != match.user_b_id:  # Only user_b can accept
        raise HTTPException(status_code=403, detail="Not authorized to accept this match")

    if match.status != "pending":
        raise HTTPException(status_code=400, detail="Match is not pending")

    match.status = "accepted"
    db.commit()
    db.refresh(match)

    return match

@router.post("/{match_id}/reject")
def reject_match(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.match_id == match_id).first()

    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if current_user.id != match.user_b_id:  # Only user_b can reject
        raise HTTPException(status_code=403, detail="Not authorized")

    match.status = "rejected"
    db.commit()

    return {"message": "Match rejected"}

@router.get("/incoming", response_model=list[MatchResponse])
def incoming_matches(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Match).filter(
        Match.user_b_id == current_user.id,
        Match.status == "pending"
    ).all()
@router.get("/outgoing", response_model=list[MatchResponse])
def outgoing_matches(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Match).filter(
        Match.user_a_id == current_user.id,
        Match.status == "pending"
    ).all()


from schemas.match_schemas import MatchCreate, MatchResponse, MatchResponseWithDetails

# ... (rest of imports)

@router.get("/accepted", response_model=list[MatchResponseWithDetails])
def accepted_matches(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    matches = db.query(Match).filter(
        Match.status == "accepted",
        or_(
            Match.user_a_id == current_user.id,
            Match.user_b_id == current_user.id
        )
    ).all()

    config_matches = []
    for match in matches:
        if match.user_a_id == current_user.id:
            other = match.user_b
        else:
            other = match.user_a
            
        match_dict = match.__dict__
        match_dict['other_user'] = {
            'id': other.id,
            'name': other.name,
            'email': other.email
        }
        config_matches.append(match_dict)
        
    return config_matches
