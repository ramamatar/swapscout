from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from typing import Optional
from datetime import date, timedelta

from database import get_db
from models import Match, TripPreference, User, Home
from auth_middleware import get_current_user
from services.match_service import find_matches
from schemas.match_schemas import MatchCreate, MatchResponse
from services.compatibility_service import calculateCompatibility, generateExplanation, UserRequest, CurrentListing
import asyncio


router = APIRouter(prefix="/matches", tags=["Matches"])
@router.get("/")
async def get_matches(
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

@router.get("/compatibility/{home_id}")
def get_ai_compatibility(
    home_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Get the preference for the user
    preference = db.query(TripPreference).filter(TripPreference.user_id == current_user.id).first()
    if not preference:
        raise HTTPException(status_code=400, detail="No trip preferences found for user")

    home = db.query(Home).filter(Home.id == home_id).first()
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")

    owner = db.query(User).filter(User.id == home.owner_id).first()

    # Bio/lifestyle preferences from lifestyle_tags (moods + environments like "Relaxing", "Beach")
    bio_preferences = [t.strip().lower() for t in preference.lifestyle_tags] if preference.lifestyle_tags else []
    
    userRequest = UserRequest(
        requested_guest_count=preference.guests,
        requested_dates=(preference.start_date, preference.end_date),
        requested_amenities=[],  # DreamTrip flow does not collect amenity preferences
        requested_radius=None,
        user_bio_preferences=bio_preferences
    )

    listing_amenities = [a.strip().lower() for a in home.amenities.split(',')] if home.amenities else []
    
    # Build richer listing traits from actual home data for better bio matching
    listing_traits = []
    if home.environment:
        listing_traits.append(home.environment.lower())
    if home.property_type:
        listing_traits.append(home.property_type.lower())
    if home.description:
        listing_traits.append(home.description.lower())
    if owner and owner.bio:
        listing_traits.append(owner.bio.lower())

    currentListing = CurrentListing(
        listing_id=home.id,
        listing_capacity=home.capacity,
        listing_available_dates=(home.available_from, home.available_to),
        listing_amenities=listing_amenities,
        listing_distance=None,
        listing_environment_traits=listing_traits
    )

    # Calculate deterministic compatibility
    compatibility = calculateCompatibility(userRequest, currentListing)

    # Generate factual explanation
    explanation = generateExplanation(compatibility)

    return {
        "compatibility_score": compatibility.total_score,
        "factors": compatibility.factors.model_dump(),
        "match_explanation": explanation
    }

@router.get("/compatibility/{home_id}/search")
def get_search_compatibility(
    home_id: int,
    requested_guest_count: int = 1,
    check_in: Optional[str] = None,
    check_out: Optional[str] = None,
    amenities: Optional[str] = None,
    environment: Optional[str] = None,
    property_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Calculate compatibility using explicit search parameters instead of saved TripPreference."""
    home = db.query(Home).filter(Home.id == home_id).first()
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")

    owner = db.query(User).filter(User.id == home.owner_id).first()

    # Parse dates from search params
    try:
        start_date = date.fromisoformat(check_in) if check_in else date.today()
        end_date = date.fromisoformat(check_out) if check_out else date.today() + timedelta(days=30)
    except ValueError:
        start_date = date.today()
        end_date = date.today() + timedelta(days=30)

    # Parse amenities from comma-separated search param
    requested_amenities = [a.strip().lower() for a in amenities.split(',')] if amenities else []

    # Build bio preferences from environment and property type search filters
    bio_preferences = []
    if environment:
        bio_preferences.append(environment.strip().lower())
    if property_type:
        bio_preferences.append(property_type.strip().lower())

    userRequest = UserRequest(
        requested_guest_count=requested_guest_count,
        requested_dates=(start_date, end_date),
        requested_amenities=requested_amenities,
        requested_radius=None,
        user_bio_preferences=bio_preferences
    )

    listing_amenities = [a.strip().lower() for a in home.amenities.split(',')] if home.amenities else []

    # Build richer listing traits from actual home data
    listing_traits = []
    if home.environment:
        listing_traits.append(home.environment.lower())
    if home.property_type:
        listing_traits.append(home.property_type.lower())
    if home.description:
        listing_traits.append(home.description.lower())
    if owner and owner.bio:
        listing_traits.append(owner.bio.lower())

    currentListing = CurrentListing(
        listing_id=home.id,
        listing_capacity=home.capacity,
        listing_available_dates=(home.available_from, home.available_to),
        listing_amenities=listing_amenities,
        listing_distance=None,
        listing_environment_traits=listing_traits
    )

    # Calculate deterministic compatibility
    compatibility = calculateCompatibility(userRequest, currentListing)

    # Generate factual explanation
    explanation = generateExplanation(compatibility)

    return {
        "compatibility_score": compatibility.total_score,
        "factors": compatibility.factors.model_dump(),
        "match_explanation": explanation
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
        if existing_match.status == "pending":
            raise HTTPException(status_code=400, detail="Match request is already pending")
        
        # Recycle the old match (it was accepted, rejected, or expired)
        existing_match.user_a_id = current_user.id
        existing_match.user_b_id = home.owner_id
        existing_match.status = "pending"
        db.commit()
        db.refresh(existing_match)
        return existing_match
    
    # Create new match request (current user is user_a, home owner is user_b)
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
