from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sockets import manager

router = APIRouter(tags=["WebSockets"])

@router.websocket("/ws/notifications/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    await manager.connect(websocket, user_id)
    try:
        while True:
            # We don't expect the client to send much, but we must await to keep the connection alive
            # and detect when the client disconnects.
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id)
