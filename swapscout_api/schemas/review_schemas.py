from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class ReviewCreate(BaseModel):
    swap_request_id: int
    home_id: int
    rating: int  # 1-5
    comment: Optional[str] = None

class ReviewResponse(BaseModel):
    id: int
    swap_request_id: int
    reviewer_id: int
    reviewee_id: int
    home_id: int
    rating: int
    comment: Optional[str] = None
    created_at: datetime
    
    # Natively resolve reviewer name if possible, or just raw output
    reviewer_name: Optional[str] = None

    class Config:
        from_attributes = True
