from fastapi import APIRouter, Depends
from auth_middleware import get_current_user
from models import User

router = APIRouter(prefix="/activity", tags=["Activity"])


@router.get("/")
def get_activity(current_user: User = Depends(get_current_user)):
    return {"message": "User activity endpoint"}
