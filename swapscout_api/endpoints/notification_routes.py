from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from database import get_db
from models import Match, Message, Favorite, Home
from auth_middleware import get_current_user
from models import User

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/")
def get_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    notifications = []
    
    # Get pending incoming matches
    incoming_matches = db.query(Match).filter(
        Match.user_b_id == current_user.id,
        Match.status == "pending"
    ).all()
    
    for match in incoming_matches:
        notifications.append({
            "id": match.match_id,
            "match_id": match.match_id,
            "type": "match_request",
            "title": "New Match Request",
            "message": f"You have a new match request",
            "created_at": match.created_at.isoformat() if match.created_at else None,
            "read": False
        })
    
    # Get unread messages
    unread_messages = db.query(Message).filter(
        Message.receiver_id == current_user.id
    ).order_by(Message.created_at.desc()).limit(10).all()
    
    for msg in unread_messages:
        notifications.append({
            "id": msg.id,
            "type": "message",
            "title": "New Message",
            "message": msg.content[:50] + "..." if len(msg.content) > 50 else msg.content,
            "created_at": msg.created_at.isoformat() if msg.created_at else None,
            "read": False
        })
    
    # Get accepted matches
    accepted_matches = db.query(Match).filter(
        or_(
            Match.user_a_id == current_user.id,
            Match.user_b_id == current_user.id
        ),
        Match.status == "accepted"
    ).order_by(Match.updated_at.desc()).limit(5).all()
    
    for match in accepted_matches:
        other_user_id = match.user_b_id if match.user_a_id == current_user.id else match.user_a_id
        notifications.append({
            "id": match.match_id,
            "match_id": match.match_id,
            "type": "match_accepted",
            "title": "Match Accepted",
            "message": f"Your match request has been accepted",
            "created_at": match.updated_at.isoformat() if match.updated_at else None,
            "read": False
        })
    
    # Sort by created_at descending
    notifications.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    
    return {"notifications": notifications[:20]}  # Return latest 20

