from sqlalchemy.orm import Session
from models import Home, User, HomeBooking
from schemas.home_schemas import HomeCreate, HomeUpdate, HomeBookingCreate
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


def add_local_image_to_home(db: Session, home: Home, image_data: bytes, content_type: str) -> Home:
    from models import HomeImage
    
    # 1. Save byte data into HomeImage table
    new_image = HomeImage(
        home_id=home.id,
        image_data=image_data,
        content_type=content_type
    )
    db.add(new_image)
    db.commit()
    db.refresh(new_image)
    
    # 2. Append the relative DB URL to the images array
    if home.images is None:
        home.images = []
        
    image_url = f"/images/{new_image.id}"
    
    # We must create a new list or SQLAlchemy won't detect the change on ARRAY
    current_images = list(home.images)
    current_images.append(image_url)
    home.images = current_images
    
    db.commit()
    db.refresh(home)
    return home

def add_home_booking(db: Session, home: Home, booking_data: HomeBookingCreate) -> HomeBooking:
    booking = HomeBooking(
        home_id=home.id,
        start_date=booking_data.start_date,
        end_date=booking_data.end_date
    )
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking


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

    # Availability overlap logic against the general available_from/to
    # AND ensure it doesn't overlap with any HomeBooking block-outs
    if date_from and date_to:
        query = query.filter(
            Home.available_from <= date_to,
            Home.available_to >= date_from
        )
        # Check that there is NO booking that overlaps with the requested dates
        # Overlap occurs if: booking.start_date <= requested.end_date AND booking.end_date >= requested.start_date
        query = query.filter(
            ~Home.bookings.any(
                (HomeBooking.start_date <= date_to) & (HomeBooking.end_date >= date_from)
            )
        )

    return query.all()

def search_homes_nearby(
    db: Session,
    target_lat: float,
    target_lng: float,
    radius_km: float
):
    from sqlalchemy import func
    
    # Haversine formula implemented in SQLAlchemy
    distance_expr = (
        6371 * func.acos(
            func.cos(func.radians(target_lat)) * func.cos(func.radians(Home.latitude)) *
            func.cos(func.radians(Home.longitude) - func.radians(target_lng)) +
            func.sin(func.radians(target_lat)) * func.sin(func.radians(Home.latitude))
        )
    ).label("distance")
    
    # Query homes that have coordinates
    query = db.query(Home, distance_expr).filter(
        Home.is_hidden == False,
        Home.latitude.isnot(None),
        Home.longitude.isnot(None)
    ).filter(distance_expr <= radius_km).order_by(distance_expr)
    
    results = query.all()
    
    # Map raw results to model instances and inject the distance attribute dynamically
    homes_with_distance = []
    for home, distance in results:
        # Since SQLAlchemy instances can be mutated locally:
        setattr(home, 'distance', distance)
        homes_with_distance.append(home)
        
    return homes_with_distance
