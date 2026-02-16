from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from auth_middleware import get_current_user
from models import User
from database import get_db

from schemas.trip_preference_schemas import (
    TripPreferenceCreate,
    TripPreferenceResponse
)
from services.trip_preference_service import (
    get_preference_by_user,
    create_or_update_preference
)
router = APIRouter(prefix="/preferences", tags=["Preferences"])


@router.get("/")
def get_preferences(current_user: User = Depends(get_current_user)):
    return {"message": "Preferences endpoint working"}

router = APIRouter(prefix="/preferences", tags=["Trip Preferences"])

@router.get("/me", response_model=TripPreferenceResponse)
def get_my_preferences(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return get_preference_by_user(db, current_user.id)

@router.post("/me", response_model=TripPreferenceResponse)
def set_my_preferences(
    data: TripPreferenceCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return create_or_update_preference(db, current_user.id, data)
