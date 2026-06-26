from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import date, datetime

class MatchCreate(BaseModel):
    home_id: int  # The home that the current user wants to match with

class MatchResponse(BaseModel):
    match_id: int
    user_a_id: int
    user_b_id: int
    status: str
    created_at: Optional[datetime]
    updated_at: Optional[datetime]

    model_config = ConfigDict(from_attributes=True)

class MatchUserDetail(BaseModel):
    id: int
    name: Optional[str]
    email: str

    model_config = ConfigDict(from_attributes=True)

class MatchResponseWithDetails(MatchResponse):
    other_user: MatchUserDetail

class HomeMatch(BaseModel):
    home_id: int
    title: str
    country: str
    city: str
