from sqlalchemy.orm import Session
from models import Message
from fastapi import HTTPException
from services.match_service import users_are_matched

def send_message(db: Session, sender_id: int, receiver_id: int, content: str):
    if not users_are_matched(db, sender_id, receiver_id):
        raise HTTPException(
            status_code=403,
            detail="You can only message users you are matched with."
        )

    message = Message(
        sender_id=sender_id,
        receiver_id=receiver_id,
        content=content
    )

    db.add(message)
    db.commit()
    db.refresh(message)
    return message


def get_conversation(db: Session, user_id: int, other_user_id: int):
    return (
        db.query(Message)
        .filter(
            ((Message.sender_id == user_id) & (Message.receiver_id == other_user_id)) |
            ((Message.sender_id == other_user_id) & (Message.receiver_id == user_id))
        )
        .order_by(Message.created_at.asc())
        .all()
    )


def get_inbox(db: Session, user_id: int):
    return (
        db.query(Message)
        .filter(
            (Message.sender_id == user_id) |
            (Message.receiver_id == user_id)
        )
        .order_by(Message.created_at.desc())
        .all()
    )
