from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


# Routers
from endpoints import (
    auth_routes,
    user_routes,
    home_routes,
    preference_routes,
    match_routes,
    message_routes,
    favorite_routes,
    activity_routes,
    notification_routes,
    ai_routes,
    swap_request_routes,
    image_routes,
    websocket_routes,
    review_routes,
)

# Database
from database import engine
import models

# Create DB tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="SwapScout API",
    version="1.0.0",
    description="Backend API for SwapScout home exchange platform"
)

# CORS (important for Flutter / frontend)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # later restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth_routes.router)
app.include_router(user_routes.router)
app.include_router(home_routes.router)
app.include_router(preference_routes.router)
app.include_router(match_routes.router)
app.include_router(message_routes.router)
app.include_router(favorite_routes.router)
app.include_router(activity_routes.router)
app.include_router(notification_routes.router)
app.include_router(ai_routes.router)
app.include_router(swap_request_routes.router)
app.include_router(image_routes.router)
app.include_router(websocket_routes.router)
app.include_router(review_routes.router)

@app.get("/")
def root():
    return {
        "message": "SwapScout API is running 🚀"
    }
