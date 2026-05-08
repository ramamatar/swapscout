from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import date

class TripPreferenceBase(BaseModel):
    preferred_country: Optional[str]
    preferred_city: Optional[str]
    start_date: Optional[date]
    end_date: Optional[date]
    guests: Optional[int]
    lifestyle_tags: Optional[List[str]]

class TripPreferenceCreate(TripPreferenceBase):
    pass

class TripPreferenceUpdate(TripPreferenceBase):
    pass

class TripPreferenceResponse(TripPreferenceBase):
    id: int
    user_id: int

    model_config = ConfigDict(from_attributes=True)
