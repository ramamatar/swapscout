from sqlalchemy.orm import Session
from models import Favorite

def add_favorite(db: Session, user_id: int, home_id: int):
    existing = db.query(Favorite).filter(
        Favorite.user_id == user_id,
        Favorite.home_id == home_id
    ).first()

    if existing:
        return existing

    favorite = Favorite(user_id=user_id, home_id=home_id)
    db.add(favorite)
    db.commit()
    db.refresh(favorite)
    return favorite


def remove_favorite(db: Session, user_id: int, home_id: int):
    favorite = db.query(Favorite).filter(
        Favorite.user_id == user_id,
        Favorite.home_id == home_id
    ).first()

    if favorite:
        db.delete(favorite)
        db.commit()

    return favorite


def get_user_favorites(db: Session, user_id: int):
    return db.query(Favorite).filter(Favorite.user_id == user_id).all()
