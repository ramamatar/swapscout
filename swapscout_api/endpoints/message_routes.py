import json
from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from database import get_db, SessionLocal
from models import Message, Match, User
from auth_middleware import get_current_user
from utils.token import decode_token
from schemas.message_schemas import (
    MessageCreate,
    MessageResponse
)

router = APIRouter(prefix="/messages", tags=["Messages"])

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_personal_message(self, message: dict, user_id: int):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                await connection.send_json(message)

manager = ConnectionManager()

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

@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...)
):
    payload = decode_token(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    db = SessionLocal()
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        db.close()
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    await manager.connect(websocket, user.id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                message_data = json.loads(data)
                receiver_id = message_data.get("receiver_id")
                content = message_data.get("content")
                
                if not receiver_id or not content:
                    continue
                    
                if receiver_id == user.id:
                    continue
                    
                if not users_are_matched(db, user.id, receiver_id):
                    await manager.send_personal_message(
                        {"error": "You can only message matched users"}, user.id
                    )
                    continue
                    
                new_message = Message(
                    sender_id=user.id,
                    receiver_id=receiver_id,
                    content=content
                )
                db.add(new_message)
                db.commit()
                db.refresh(new_message)
                
                message_dict = {
                    "id": new_message.id,
                    "sender_id": new_message.sender_id,
                    "receiver_id": new_message.receiver_id,
                    "content": new_message.content,
                    "created_at": new_message.created_at.isoformat() if new_message.created_at else None
                }
                
                await manager.send_personal_message(message_dict, user.id)
                await manager.send_personal_message(message_dict, receiver_id)
                
            except json.JSONDecodeError:
                pass
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, user.id)
    finally:
        db.close()

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
            other_user = db.query(User).filter(User.id == other_user_id).first()
            if other_user and hasattr(other_user, 'email') and other_user.email:
                name = other_user.email.split('@')[0].capitalize()
            else:
                name = f"User {other_user_id}"
            
            conversations[other_user_id] = {
                "user_id": other_user_id,
                "user_name": name,
                "last_message": msg.content,
                "timestamp": msg.created_at
            }

    return list(conversations.values())

