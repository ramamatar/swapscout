from pydantic import BaseModel, ConfigDict, EmailStr
from typing import Optional, List, Any


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    name: Optional[str]
    country: Optional[str]
    city: Optional[str]
    lifestyle_tags: Optional[str]
    bio: Optional[str]

    model_config = ConfigDict(from_attributes=True)


class UserUpdate(BaseModel):
    name: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    lifestyle_tags: Optional[str] = None
    bio: Optional[str] = None

class PublicProfileResponse(BaseModel):
    id: int
    name: Optional[str]
    country: Optional[str]
    city: Optional[str]
    lifestyle_tags: Optional[str]
    bio: Optional[str]

    model_config = ConfigDict(from_attributes=True)

class PublicUserWithHomesResponse(BaseModel):
    user: PublicProfileResponse
    homes: List[Any] # Uses Any safely here to prevent circular imports with home schemas

    model_config = ConfigDict(from_attributes=True)

class InsightsResponse(BaseModel):
    total_swaps: int
    pending_requests: int
    favorites_count: int
    match_success_rate: int
