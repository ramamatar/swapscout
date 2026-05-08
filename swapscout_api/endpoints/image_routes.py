from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session
from auth_middleware import get_db
from models import HomeImage

router = APIRouter(prefix="/images", tags=["Images"])

@router.get("/{image_id}")
def get_image(image_id: int, db: Session = Depends(get_db)):
    image = db.query(HomeImage).filter(HomeImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
        
    return Response(content=image.image_data, media_type=image.content_type)
