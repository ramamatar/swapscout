from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from services.home_service import search_homes
from auth_middleware import get_current_user, get_db
from models import User
from schemas.home_schemas import HomeCreate, HomeUpdate, HomeResponse
from services.home_service import (
    create_home,
    get_home_by_id,
    get_user_homes,
    update_home,
    delete_home
)

router = APIRouter(prefix="/homes", tags=["Homes"])


@router.post("/", response_model=HomeResponse, status_code=status.HTTP_201_CREATED)
def create_new_home(
    data: HomeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_home(db, current_user, data)


@router.get("/mine", response_model=list[HomeResponse])
def my_homes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return get_user_homes(db, current_user.id)
@router.get("/search", response_model=list[HomeResponse])
def search(
    country: str | None = None,
    city: str | None = None,
    min_capacity: int | None = None,
    environment: str | None = None,
    property_type: str | None = None,
    amenities: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    db: Session = Depends(get_db)
):
    from datetime import datetime
    date_from_parsed = None
    date_to_parsed = None
    if date_from:
        try:
            date_from_parsed = datetime.strptime(date_from, "%Y-%m-%d").date()
        except:
            pass
    if date_to:
        try:
            date_to_parsed = datetime.strptime(date_to, "%Y-%m-%d").date()
        except:
            pass
    
    return search_homes(
        db=db,
        country=country,
        city=city,
        min_capacity=min_capacity,
        environment=environment,
        property_type=property_type,
        amenities=amenities,
        date_from=date_from_parsed,
        date_to=date_to_parsed
    )


@router.get("/{home_id}", response_model=HomeResponse)
def get_home(home_id: int, db: Session = Depends(get_db)):
    home = get_home_by_id(db, home_id)
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")
    if home.is_hidden:
        raise HTTPException(status_code=404, detail="Home not found")
    return home


@router.get("/{home_id}/owner", response_model=dict)
def get_home_owner(home_id: int, db: Session = Depends(get_db)):
    home = get_home_by_id(db, home_id)
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")
    
    owner = db.query(User).filter(User.id == home.owner_id).first()
    if not owner:
        raise HTTPException(status_code=404, detail="Owner not found")
    
    return {
        "id": owner.id,
        "name": owner.name,
        "email": owner.email,
        "city": owner.city,
        "country": owner.country,
    }


@router.put("/{home_id}", response_model=HomeResponse)
def edit_home(
    home_id: int,
    updates: HomeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    home = get_home_by_id(db, home_id)
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")

    if home.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    return update_home(db, home, updates)


@router.delete("/{home_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_home(
    home_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    home = get_home_by_id(db, home_id)
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")

    if home.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    delete_home(db, home)



