
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel, EmailStr
from datetime import date, datetime, timedelta
import models
from database import SessionLocal
from passlib.context import CryptContext
from jose import JWTError, jwt


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = "your-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt



class LoginRequest(BaseModel):
    email: str
    password: str

class SignUpRequest(BaseModel):
    full_name: str
    email: str
    password: str
    phone_number: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: int

@router.post("/auth/login", response_model=TokenResponse)
def login(credentials: LoginRequest, db: Session = Depends(get_db)):
    """Login endpoint"""
    user = db.query(models.User).filter(models.User.email == credentials.email).first()
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email, "user_id": user.user_id},
        expires_delta=access_token_expires
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.user_id
    }

@router.post("/auth/signup", response_model=TokenResponse)
def signup(user_data: SignUpRequest, db: Session = Depends(get_db)):
    """Sign up endpoint"""
    # Check if user exists
    existing_user = db.query(models.User).filter(models.User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    new_user = models.User(
        full_name=user_data.full_name,
        email=user_data.email,
        password_hash=hashed_password,
        phone_number=user_data.phone_number,
        country=user_data.country,
        city=user_data.city
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": new_user.email, "user_id": new_user.user_id},
        expires_delta=access_token_expires
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": new_user.user_id
    }


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    lifestyle_tags: Optional[List[str]] = None
    preferred_travel_style: Optional[str] = None

@router.get("/users/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db)):
    """Get user profile"""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.put("/users/{user_id}")
def update_user(user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)):
    """Update user profile"""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    update_data = user_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    return user

@router.get("/users/{user_id}/home")
def get_user_home(user_id: int, db: Session = Depends(get_db)):
    """Get user's home listing"""
    home = db.query(models.Home).filter(models.Home.user_id == user_id).first()
    if not home:
        raise HTTPException(status_code=404, detail="Home listing not found")
    return home

class HomeUpdate(BaseModel):
    location: Optional[str] = None
    home_type: Optional[str] = None
    description: Optional[str] = None
    amenities: Optional[List[str]] = None
    guest_capacity: Optional[int] = None
    available_from: Optional[date] = None
    available_to: Optional[date] = None
    images: Optional[List[str]] = None

@router.put("/users/{user_id}/home")
def update_user_home(user_id: int, home_update: HomeUpdate, db: Session = Depends(get_db)):
    """Update user's home listing"""
    home = db.query(models.Home).filter(models.Home.user_id == user_id).first()
    if not home:
        raise HTTPException(status_code=404, detail="Home listing not found")
    
    update_data = home_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(home, field, value)
    
    db.commit()
    db.refresh(home)
    return home


class TripPreferencesCreate(BaseModel):
    mood_description: Optional[str] = None
    selected_moods: Optional[List[str]] = None
    preferred_environments: Optional[List[str]] = None
    lifestyle_fit: Optional[List[str]] = None
    travel_dates_from: Optional[date] = None
    travel_dates_to: Optional[date] = None
    home_location: Optional[str] = None

class TripPreferencesUpdate(TripPreferencesCreate):
    pass

@router.post("/users/{user_id}/trip-preferences")
def create_trip_preferences(user_id: int, preferences: TripPreferencesCreate, db: Session = Depends(get_db)):
    """Create or update trip preferences"""
    # Check if user exists
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if preferences already exist
    existing = db.query(models.TripPreferences).filter(
        models.TripPreferences.user_id == user_id
    ).first()
    
    if existing:
        # Update existing preferences
        update_data = preferences.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(existing, field, value)
        existing.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(existing)
        return existing
    else:
        # Create new preferences
        new_preferences = models.TripPreferences(
            user_id=user_id,
            **preferences.dict()
        )
        db.add(new_preferences)
        db.commit()
        db.refresh(new_preferences)
        return new_preferences

@router.get("/users/{user_id}/trip-preferences")
def get_trip_preferences(user_id: int, db: Session = Depends(get_db)):
    """Get user's trip preferences"""
    preferences = db.query(models.TripPreferences).filter(
        models.TripPreferences.user_id == user_id
    ).first()
    if not preferences:
        raise HTTPException(status_code=404, detail="Trip preferences not found")
    return preferences


# ==================== SEARCH ====================

class SearchRequest(BaseModel):
    location: Optional[str] = None
    check_in_date: Optional[date] = None
    check_out_date: Optional[date] = None
    guest_count: Optional[int] = None
    environments: Optional[List[str]] = None
    property_types: Optional[List[str]] = None
    amenities: Optional[List[str]] = None
    min_match_score: Optional[float] = 0.0

@router.post("/search")
def search_homes(search_request: SearchRequest, db: Session = Depends(get_db)):
    """Search for homes with filters"""
    query = db.query(models.Home)
    
    # Location filter
    if search_request.location:
        query = query.filter(models.Home.location.ilike(f"%{search_request.location}%"))
    
    # Date availability filter
    if search_request.check_in_date and search_request.check_out_date:
        query = query.filter(
            models.Home.available_from <= search_request.check_in_date,
            models.Home.available_to >= search_request.check_out_date
        )
    
    # Guest capacity filter
    if search_request.guest_count:
        query = query.filter(models.Home.guest_capacity >= search_request.guest_count)
    
    # Home type filter
    if search_request.property_types:
        query = query.filter(models.Home.home_type.in_(search_request.property_types))
    
    homes = query.all()
    
    # Filter by amenities (in-memory since ARRAY contains doesn't work well in SQLAlchemy)
    if search_request.amenities:
        filtered_homes = []
        for home in homes:
            if home.amenities and any(amenity in (home.amenities or []) for amenity in search_request.amenities):
                filtered_homes.append(home)
        homes = filtered_homes
    
    results = []
    for home in homes:
        user = db.query(models.User).filter(models.User.user_id == home.user_id).first()
        results.append({
            "home_id": home.home_id,
            "location": home.location,
            "home_type": home.home_type,
            "description": home.description,
            "amenities": home.amenities,
            "guest_capacity": home.guest_capacity,
            "images": home.images,
            "rating": home.rating,
            "available_from": home.available_from.isoformat() if home.available_from else None,
            "available_to": home.available_to.isoformat() if home.available_to else None,
            "host_name": user.full_name if user else None,
            "host_id": home.user_id
        })
    
    return {"results": results, "count": len(results)}



def calculate_match_score(user, home_owner, user_home, owner_home, trip_preferences=None):
    """Enhanced compatibility scoring function"""
    score = 0.0
    
    # Lifestyle tags match
    if user.lifestyle_tags and home_owner.lifestyle_tags:
        shared_tags = set(user.lifestyle_tags) & set(home_owner.lifestyle_tags)
        score += len(shared_tags) * 10
    
    # Travel style match
    if user.preferred_travel_style and home_owner.preferred_travel_style:
        if user.preferred_travel_style == home_owner.preferred_travel_style:
            score += 20
    
    # Trip preferences match
    if trip_preferences:
        if trip_preferences.preferred_environments:
            # Check if home location matches preferred environments (simplified)
            score += 15
        
        if trip_preferences.selected_moods and home_owner.lifestyle_tags:
            # Match moods with lifestyle
            score += 10
    
    # Date availability overlap - FIXED
    if user_home and owner_home:
        if (user_home.available_from and user_home.available_to and 
            owner_home.available_from and owner_home.available_to):
            try:
                overlap_days = (
                    min(owner_home.available_to, user_home.available_to)
                    - max(owner_home.available_from, user_home.available_from)
                ).days
                if overlap_days > 0:
                    score += min(overlap_days, 10)
            except (TypeError, AttributeError):
                # Handle case where dates might not be properly set
                pass
    
    # Home rating bonus
    if owner_home and owner_home.rating:
        score += owner_home.rating * 2
    
    return min(round(score, 2), 100.0)

@router.post("/users/{user_id}/matches/generate")
def generate_matches(user_id: int, db: Session = Depends(get_db)):
    """Generate AI-based matches for user"""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_home = db.query(models.Home).filter(models.Home.user_id == user_id).first()
    trip_preferences = db.query(models.TripPreferences).filter(
        models.TripPreferences.user_id == user_id
    ).first()
    
    # Delete old matches for this user to avoid duplicates
    db.query(models.Match).filter(models.Match.user_id == user_id).delete()
    db.commit()
    
    # Get other users and homes
    other_users = db.query(models.User).filter(models.User.user_id != user_id).all()
    
    matches = []
    for other_user in other_users:
        other_home = db.query(models.Home).filter(
            models.Home.user_id == other_user.user_id
        ).first()
        
        if other_home:
            match_score = calculate_match_score(
                user, other_user, user_home, other_home, trip_preferences
            )
            
            if match_score > 40:  # Only return reasonable matches
                # Save match to database
                match = models.Match(
                    user_id=user_id,
                    matched_user_id=other_user.user_id,
                    matched_home_id=other_home.home_id,
                    match_score=match_score
                )
                db.add(match)
                db.flush()  # Flush to get the match_id
                
                # Create activity for new match
                activity = models.Activity(
                    user_id=user_id,
                    activity_type="match_found",
                    title="New swap match found",
                    description=f"Match with {other_home.location}",
                    related_user_id=other_user.user_id,
                    related_home_id=other_home.home_id
                )
                db.add(activity)
                
                matches.append({
                    "match_id": match.match_id,
                    "match_score": match_score,
                    "location": other_home.location,
                    "host_name": other_user.full_name,
                    "host_id": other_user.user_id,
                    "home_id": other_home.home_id,
                    "description": other_home.description,
                    "guest_capacity": other_home.guest_capacity,
                    "amenities": other_home.amenities or [],
                    "rating": other_home.rating,
                    "availability": f"{other_home.available_from} to {other_home.available_to}" if other_home.available_from else None,
                    "image_url": other_home.images[0] if other_home.images else None
                })
    
    db.commit()
    
    matches.sort(key=lambda x: x["match_score"], reverse=True)
    return {"matches": matches, "count": len(matches)}

@router.get("/users/{user_id}/matches")
def get_user_matches(user_id: int, db: Session = Depends(get_db)):
    """Get user's matches"""
    matches = db.query(models.Match).filter(
        models.Match.user_id == user_id
    ).order_by(models.Match.match_score.desc()).all()
    
    results = []
    for match in matches:
        matched_user = db.query(models.User).filter(
            models.User.user_id == match.matched_user_id
        ).first()
        matched_home = db.query(models.Home).filter(
            models.Home.home_id == match.matched_home_id
        ).first()
        
        if matched_user and matched_home:
            results.append({
                "match_id": match.match_id,
                "match_score": match.match_score,
                "status": match.status,
                "host_name": matched_user.full_name,
                "location": matched_home.location,
                "description": matched_home.description,
                "amenities": matched_home.amenities,
                "rating": matched_home.rating,
                "created_at": match.created_at.isoformat() if match.created_at else None
            })
    
    return {"matches": results, "count": len(results)}


# ==================== INSIGHTS ====================

@router.get("/users/{user_id}/insights")
def get_user_insights(user_id: int, db: Session = Depends(get_db)):
    """Get user insights and analytics"""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Total swaps
    total_swaps = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.status == "accepted"
    ).count()
    
    # Total matches
    total_matches = db.query(models.Match).filter(
        models.Match.user_id == user_id
    ).count()
    
    # Upcoming swaps
    upcoming_swaps = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.status == "accepted"
    ).count()  # Simplified - could check dates
    
    # Get messages
    messages = db.query(models.Message).filter(
        models.Message.receiver_id == user_id
    ).all()
    
    # Calculate response rate (simplified)
    total_received = len(messages)
    responded = sum(1 for m in messages if m.read)
    response_rate = (responded / total_received * 100) if total_received > 0 else 0
    
    # Match success rate
    match_success_rate = (total_swaps / total_matches * 100) if total_matches > 0 else 0
    
    # Popular destinations
    matches = db.query(models.Match).filter(
        models.Match.user_id == user_id
    ).all()
    destinations = {}
    for match in matches:
        home = db.query(models.Home).filter(
            models.Home.home_id == match.matched_home_id
        ).first()
        if home:
            location = home.location
            destinations[location] = destinations.get(location, 0) + 1
    
    popular_destinations = [
        {"destination": dest, "count": count}
        for dest, count in sorted(destinations.items(), key=lambda x: x[1], reverse=True)[:4]
    ]
    
    # Recent activities
    activities = db.query(models.Activity).filter(
        models.Activity.user_id == user_id
    ).order_by(models.Activity.created_at.desc()).limit(10).all()
    
    activity_list = [
        {
            "activity_type": activity.activity_type,
            "title": activity.title,
            "description": activity.description,
            "created_at": activity.created_at.isoformat() if activity.created_at else None
        }
        for activity in activities
    ]
    
    return {
        "overview": {
            "total_swaps": total_swaps,
            "matches": total_matches,
            "upcoming": upcoming_swaps
        },
        "performance": {
            "response_rate": round(response_rate, 1),
            "match_success_rate": round(match_success_rate, 1),
            "avg_response_time": "2.5 hours"  # Placeholder
        },
        "popular_destinations": popular_destinations,
        "recent_activity": activity_list
    }


# ==================== MESSAGES ====================

class MessageCreate(BaseModel):
    receiver_id: int
    home_id: Optional[int] = None
    subject: Optional[str] = None
    content: str

@router.post("/messages")
def create_message(
    message: MessageCreate, 
    sender_id: int = Query(..., description="ID of the user sending the message"), 
    db: Session = Depends(get_db)
):
    """Send a message"""
    
    new_message = models.Message(
        sender_id=sender_id,
        receiver_id=message.receiver_id,
        home_id=message.home_id,
        subject=message.subject or "Message about home swap",
        content=message.content
    )
    db.add(new_message)
    
    # Create activity for receiver
    sender = db.query(models.User).filter(models.User.user_id == sender_id).first()
    sender_name = sender.full_name if sender else f"User {sender_id}"
    
    activity = models.Activity(
        user_id=message.receiver_id,
        activity_type="message",
        title="Message received",
        description=f"From {sender_name}",
        related_user_id=sender_id
    )
    db.add(activity)
    
    db.commit()
    db.refresh(new_message)
    return new_message

@router.get("/users/{user_id}/messages")
def get_user_messages(user_id: int, db: Session = Depends(get_db)):
    """Get user's messages"""
    messages = db.query(models.Message).filter(
        (models.Message.sender_id == user_id) | (models.Message.receiver_id == user_id)
    ).order_by(models.Message.created_at.desc()).all()
    
    results = []
    for message in messages:
        sender = db.query(models.User).filter(models.User.user_id == message.sender_id).first()
        receiver = db.query(models.User).filter(models.User.user_id == message.receiver_id).first()
        results.append({
            "message_id": message.message_id,
            "sender_id": message.sender_id,
            "sender_name": sender.full_name if sender else None,
            "receiver_id": message.receiver_id,
            "receiver_name": receiver.full_name if receiver else None,
            "subject": message.subject,
            "content": message.content,
            "read": message.read,
            "created_at": message.created_at.isoformat() if message.created_at else None
        })
    
    return {"messages": results, "count": len(results)}


# ==================== FAVORITES ====================

class FavoriteCreate(BaseModel):
    home_id: int

@router.post("/users/{user_id}/favorites")
def add_favorite(user_id: int, favorite: FavoriteCreate, db: Session = Depends(get_db)):
    """Add home to favorites"""
    # Check if already favorited
    existing = db.query(models.Favorite).filter(
        models.Favorite.user_id == user_id,
        models.Favorite.home_id == favorite.home_id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Home already in favorites")
    
    new_favorite = models.Favorite(user_id=user_id, home_id=favorite.home_id)
    db.add(new_favorite)
    db.commit()
    db.refresh(new_favorite)
    return new_favorite

@router.get("/users/{user_id}/favorites")
def get_favorites(user_id: int, db: Session = Depends(get_db)):
    """Get user's favorite homes"""
    favorites = db.query(models.Favorite).filter(
        models.Favorite.user_id == user_id
    ).all()
    
    results = []
    for favorite in favorites:
        home = db.query(models.Home).filter(models.Home.home_id == favorite.home_id).first()
        if home:
            user = db.query(models.User).filter(models.User.user_id == home.user_id).first()
            results.append({
                "favorite_id": favorite.favorite_id,
                "home_id": home.home_id,
                "location": home.location,
                "description": home.description,
                "amenities": home.amenities,
                "rating": home.rating,
                "images": home.images,
                "host_name": user.full_name if user else None,
                "created_at": favorite.created_at.isoformat() if favorite.created_at else None
            })
    
    return {"favorites": results, "count": len(results)}

@router.delete("/users/{user_id}/favorites/{home_id}")
def remove_favorite(user_id: int, home_id: int, db: Session = Depends(get_db)):
    """Remove home from favorites"""
    favorite = db.query(models.Favorite).filter(
        models.Favorite.user_id == user_id,
        models.Favorite.home_id == home_id
    ).first()
    
    if not favorite:
        raise HTTPException(status_code=404, detail="Favorite not found")
    
    db.delete(favorite)
    db.commit()
    return {"message": "Favorite removed"}


# ==================== ACTIVITIES ====================

@router.get("/users/{user_id}/activities")
def get_user_activities(user_id: int, limit: int = Query(20, ge=1, le=100), db: Session = Depends(get_db)):
    """Get user's activity timeline"""
    activities = db.query(models.Activity).filter(
        models.Activity.user_id == user_id
    ).order_by(models.Activity.created_at.desc()).limit(limit).all()
    
    results = []
    for activity in activities:
        related_user = None
        if activity.related_user_id:
            related_user = db.query(models.User).filter(
                models.User.user_id == activity.related_user_id
            ).first()
        
        results.append({
            "activity_id": activity.activity_id,
            "activity_type": activity.activity_type,
            "title": activity.title,
            "description": activity.description,
            "related_user_name": related_user.full_name if related_user else None,
            "created_at": activity.created_at.isoformat() if activity.created_at else None
        })
    
    return {"activities": results, "count": len(results)}
