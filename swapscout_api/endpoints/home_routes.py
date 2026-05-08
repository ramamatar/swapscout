from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from services.home_service import search_homes
from auth_middleware import get_current_user, get_db
from models import User
from schemas.home_schemas import HomeCreate, HomeUpdate, HomeResponse, HomeBookingCreate, BookingSchema, DetectedAmenities
import google.generativeai as genai
import json
import io
from PIL import Image
import os
from services.home_service import (
    create_home,
    get_home_by_id,
    get_user_homes,
    update_home,
    delete_home,
    add_local_image_to_home,
    add_home_booking
)

router = APIRouter(prefix="/homes", tags=["Homes"])


@router.post("/", response_model=HomeResponse, status_code=status.HTTP_201_CREATED)
def create_new_home(
    data: HomeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_home(db, current_user, data)


@router.post("/detect-amenities", response_model=DetectedAmenities)
async def detect_amenities(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    if not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be a valid image.")
        
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="Gemini API Key missing from environment.")
        
    try:
        # Read the file and convert to PIL Image
        contents = await image.read()
        pil_image = Image.open(io.BytesIO(contents))
        
        # We explicitly configure inline to ensure thread safety or fallback
        genai.configure(api_key=api_key)
        
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        system_prompt = (
            "You are a highly skilled real estate image analyzer. Examine this photo of a home. "
            "Identify and detect any visible amenities or features. Examples include 'Television', "
            "'Air Conditioning', 'Fireplace', 'Pool', 'Balcony', 'Kitchenette', 'Sofa', 'Oven', etc. "
            "Output exactly a JSON object matching this schema: {\"amenities\": [\"item1\", \"item2\"]}. "
            "Do not include any conversational text, markdown formatting, or anything other than the raw JSON string."
        )
        
        response = model.generate_content([system_prompt, pil_image])
        
        cleaned_text = response.text.strip()
        if cleaned_text.startswith("```json"):
            cleaned_text = cleaned_text[7:]
        if cleaned_text.endswith("```"):
            cleaned_text = cleaned_text[:-3]
        cleaned_text = cleaned_text.strip()
        
        data = json.loads(cleaned_text)
        amenities = data.get("amenities", [])
        
        return DetectedAmenities(amenities=amenities)
        
    except Exception as e:
        print(f"Gemini AI Error: {e}")
        return DetectedAmenities(amenities=[])

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

@router.get("/search/nearby", response_model=list[HomeResponse])
def search_nearby(
    target_lat: float,
    target_lng: float,
    radius_km: float = 10.0,
    db: Session = Depends(get_db)
):
    from services.home_service import search_homes_nearby
    return search_homes_nearby(
        db=db,
        target_lat=target_lat,
        target_lng=target_lng,
        radius_km=radius_km
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


@router.post("/{home_id}/images", response_model=HomeResponse)
def upload_home_image(
    home_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    home = get_home_by_id(db, home_id)
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")

    if home.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Read file to bytes
    try:
        image_data = file.file.read()
        if len(image_data) > 5 * 1024 * 1024:  # 5 MB limit
            raise HTTPException(status_code=413, detail="File too large. Maximum size is 5MB.")
            
        content_type = file.content_type
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process image: {str(e)}")
        
    # Save image to home record
    return add_local_image_to_home(db, home, image_data, content_type)

@router.post("/{home_id}/bookings", response_model=BookingSchema, status_code=status.HTTP_201_CREATED)
def create_home_booking(
    home_id: int,
    booking_data: HomeBookingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    home = get_home_by_id(db, home_id)
    if not home:
        raise HTTPException(status_code=404, detail="Home not found")

    if home.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    return add_home_booking(db, home, booking_data)

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



