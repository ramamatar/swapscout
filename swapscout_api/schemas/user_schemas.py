from pydantic import BaseModel, EmailStr
from typing import Optional, List


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    name: Optional[str]
    country: Optional[str]
    city: Optional[str]
    lifestyle_tags: Optional[str]

    class Config:
        orm_mode = True


class UserUpdate(BaseModel):
    name: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    lifestyle_tags: Optional[str] = None
