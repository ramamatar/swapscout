from sqlalchemy.orm import Session
from models import Home, User
from schemas.home_schemas import HomeCreate, HomeUpdate
from datetime import date


def create_home(db: Session, owner: User, data: HomeCreate) -> Home:
    home = Home(
        **data.dict(),
        owner_id=owner.id
    )
    db.add(home)
    db.commit()
    db.refresh(home)
    return home


def get_home_by_id(db: Session, home_id: int) -> Home | None:
    return db.query(Home).filter(Home.id == home_id).first()


def get_user_homes(db: Session, user_id: int):
    return db.query(Home).filter(Home.owner_id == user_id).all()


def update_home(db: Session, home: Home, updates: HomeUpdate) -> Home:
    for field, value in updates.dict(exclude_unset=True).items():
        setattr(home, field, value)

    db.commit()
    db.refresh(home)
    return home


def delete_home(db: Session, home: Home):
    db.delete(home)
    db.commit()

def search_homes(
    db: Session,
    country: str | None = None,
    city: str | None = None,
    min_capacity: int | None = None,
    environment: str | None = None,
    property_type: str | None = None,
    amenities: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None
):
    query = db.query(Home).filter(Home.is_hidden == False)  # Only show non-hidden homes

    if country:
        query = query.filter(Home.country.ilike(f"%{country}%"))

    if city:
        query = query.filter(Home.city.ilike(f"%{city}%"))

    if min_capacity:
        query = query.filter(Home.capacity >= min_capacity)

    if environment:
        query = query.filter(Home.environment.ilike(f"%{environment}%"))

    if property_type:
        query = query.filter(Home.property_type.ilike(f"%{property_type}%"))

    if amenities:
        # Match if any of the requested amenities is in the home's amenities
        amenity_list = [a.strip() for a in amenities.split(',')]
        from sqlalchemy import or_
        conditions = [Home.amenities.ilike(f"%{amenity}%") for amenity in amenity_list]
        if conditions:
            query = query.filter(or_(*conditions))

    # Availability overlap logic
    if date_from and date_to:
        query = query.filter(
            Home.available_from <= date_to,
            Home.available_to >= date_from
        )

    return query.all()
