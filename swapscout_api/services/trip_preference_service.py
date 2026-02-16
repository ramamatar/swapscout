from sqlalchemy.orm import Session
from models import TripPreference

def get_preference_by_user(db: Session, user_id: int):
    return db.query(TripPreference).filter(
        TripPreference.user_id == user_id
    ).first()

def create_or_update_preference(db: Session, user_id: int, data):
    pref = get_preference_by_user(db, user_id)

    if pref:
        for key, value in data.dict(exclude_unset=True).items():
            setattr(pref, key, value)
    else:
        pref = TripPreference(user_id=user_id, **data.dict())
        db.add(pref)

    db.commit()
    db.refresh(pref)
    return pref
