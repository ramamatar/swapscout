from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import date


class HomeBookingCreate(BaseModel):
    start_date: date
    end_date: date

class BookingSchema(BaseModel):
    id: int
    home_id: int
    start_date: date
    end_date: date
    
    model_config = ConfigDict(from_attributes=True)

class HomeCreate(BaseModel):
    title: str
    description: str
    country: str
    city: str
    capacity: int
    amenities: str  # Required, comma-separated
    environment: str  # Required: Beach, City, Mountain, Countryside, Lakeside
    property_type: str  # Required: Apartment, House, Villa, Cottage, Cabin
    available_from: date
    available_to: date
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class HomeUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    capacity: Optional[int] = None
    amenities: Optional[str] = None
    environment: Optional[str] = None
    property_type: Optional[str] = None
    available_from: Optional[date] = None
    available_to: Optional[date] = None
    is_hidden: Optional[bool] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class HomeResponse(BaseModel):
    id: int
    title: str
    description: str
    country: str
    city: str
    capacity: int
    amenities: Optional[str]
    environment: Optional[str]
    property_type: Optional[str]
    is_hidden: bool
    available_from: date
    available_to: date
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance: Optional[float] = None
    images: list[str] = []
    owner_id: int
    bookings: list[BookingSchema] = []
    total_reviews: int = 0
    average_rating: float = 0.0

    model_config = ConfigDict(from_attributes=True)



class HomeSearchQuery:
    country: Optional[str] = None
    city: Optional[str] = None
    min_capacity: Optional[int] = None
    environment: Optional[str] = None
    property_type: Optional[str] = None
    amenities: Optional[str] = None 
    date_from: Optional[date] = None
    date_to: Optional[date] = None

class DetectedAmenities(BaseModel):
    amenities: list[str]
