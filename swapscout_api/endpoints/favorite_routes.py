from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from schemas.favorite_schemas import FavoriteCreate, FavoriteOut
from services.favorite_service import (
    add_favorite,
    remove_favorite,
    get_user_favorites
)
from auth_middleware import get_current_user

router = APIRouter(prefix="/favorites", tags=["Favorites"])


@router.post("/", response_model=FavoriteOut)
def favorite_home(
    data: FavoriteCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    return add_favorite(db, current_user.id, data.home_id)


@router.delete("/{home_id}", status_code=status.HTTP_204_NO_CONTENT)
def unfavorite_home(
    home_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    removed = remove_favorite(db, current_user.id, home_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Favorite not found")


@router.get("/", response_model=list[FavoriteOut])
def list_favorites(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    return get_user_favorites(db, current_user.id)
