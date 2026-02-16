from sqlalchemy.orm import Session
from models import User
from utils.security import verify_password, hash_password
from utils.token import create_access_token


def authenticate_user(db: Session, email: str, password: str):
    user = db.query(User).filter(User.email == email).first()
    if not user:
        return None
    if not verify_password(password, user.password):
        return None
    return user


def register_user(db: Session, email: str, password: str):
    user = User(email=email, password=hash_password(password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def generate_token(user: User):
    return create_access_token({"sub": str(user.id)})