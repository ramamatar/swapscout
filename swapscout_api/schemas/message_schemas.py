from pydantic import BaseModel
from datetime import datetime
from typing import Optional


# ----------- Request Schema -----------

class MessageCreate(BaseModel):
    receiver_id: int
    content: str


# ----------- Response Schema -----------

class MessageResponse(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    content: str
    created_at: datetime

    class Config:
        from_attributes = True  # SQLAlchemy → Pydantic
