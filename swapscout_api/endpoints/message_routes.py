from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from database import get_db
from models import Message, Match, User
from auth_middleware import get_current_user
from schemas.message_schemas import (
    MessageCreate,
    MessageResponse
)

router = APIRouter(prefix="/messages", tags=["Messages"])

def users_are_matched(db, user_id: int, other_user_id: int) -> bool:
    match = db.query(Match).filter(
        or_(
            and_(
                Match.user_a_id == user_id,
                Match.user_b_id == other_user_id
            ),
            and_(
                Match.user_a_id == other_user_id,
                Match.user_b_id == user_id
            )
        )
    ).first()

    return match is not None
@router.post("/", response_model=MessageResponse)
def send_message(
    payload: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if payload.receiver_id == current_user.id:
        raise HTTPException(
            status_code=400,
            detail="You cannot message yourself"
        )

    if not users_are_matched(db, current_user.id, payload.receiver_id):
        raise HTTPException(
            status_code=403,
            detail="You can only message matched users"
        )

    message = Message(
        sender_id=current_user.id,
        receiver_id=payload.receiver_id,
        content=payload.content
    )

    db.add(message)
    db.commit()
    db.refresh(message)

    return message
@router.get("/conversation/{user_id}", response_model=list[MessageResponse])
def get_conversation(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not users_are_matched(db, current_user.id, user_id):
        raise HTTPException(
            status_code=403,
            detail="You can only view conversations with matched users"
        )

    messages = db.query(Message).filter(
        or_(
            and_(Message.sender_id == current_user.id, Message.receiver_id == user_id),
            and_(Message.sender_id == user_id, Message.receiver_id == current_user.id)
        )
    ).order_by(Message.created_at.asc()).all()

    return messages
@router.get("/inbox")
def inbox(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    messages = db.query(Message).filter(
        or_(
            Message.sender_id == current_user.id,
            Message.receiver_id == current_user.id
        )
    ).order_by(Message.created_at.desc()).all()

    conversations = {}
    for msg in messages:
        other_user_id = (
            msg.receiver_id if msg.sender_id == current_user.id else msg.sender_id
        )

        if other_user_id not in conversations:
            conversations[other_user_id] = {
                "user_id": other_user_id,
                "last_message": msg.content,
                "timestamp": msg.created_at
            }

    return list(conversations.values())

