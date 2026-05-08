from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import date, datetime

from models import SwapRequestStatus
from schemas.user_schemas import UserResponse
from schemas.home_schemas import HomeResponse

class SwapRequestCreate(BaseModel):
    host_id: int
    requester_home_id: int
    host_home_id: int
    start_date: date
    end_date: date
    intro_message: Optional[str] = None

class SwapRequestUpdate(BaseModel):
    status: SwapRequestStatus

class SwapRequestOut(BaseModel):
    id: int
    requester_id: int
    host_id: int
    requester_home_id: int
    host_home_id: int
    start_date: date
    end_date: date
    intro_message: Optional[str]
    status: SwapRequestStatus
    created_at: datetime
    
    requester: UserResponse
    host: UserResponse
    requester_home: HomeResponse
    host_home: HomeResponse

    model_config = ConfigDict(from_attributes=True)
