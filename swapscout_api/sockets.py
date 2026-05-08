from fastapi import WebSocket
from typing import Dict
import json

class ConnectionManager:
    def __init__(self):
        # Maps user_id -> WebSocket
        self.active_connections: Dict[int, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_personal_message(self, message: dict, user_id: int):
        websocket = self.active_connections.get(user_id)
        if websocket:
            await websocket.send_text(json.dumps(message))

# Global Connection Manager instance
manager = ConnectionManager()
