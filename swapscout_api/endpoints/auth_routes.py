from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal
from services.auth_service import authenticate_user, register_user, generate_token
from schemas.auth_schemas import LoginRequest, TokenResponse


router = APIRouter(prefix="/auth", tags=["Auth"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, data.email, data.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"access_token": generate_token(user), "token_type": "bearer"}


@router.post("/register")
def register(data: LoginRequest, db: Session = Depends(get_db)):
    user = register_user(db, data.email, data.password)
    return {"id": user.id, "email": user.email}     