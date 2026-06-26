import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import date, timedelta
import json

from main import app
from database import Base, get_db
from models import User, Home, TripPreference
from auth_middleware import get_current_user

# Test database
SQLALCHEMY_DATABASE_URL = "postgresql://ramamatar:@localhost/swapscout_test_db"
engine = create_engine(SQLALCHEMY_DATABASE_URL)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="module")
def setup_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db_session(setup_database):
    db = TestingSessionLocal()
    try:
        for table in reversed(Base.metadata.sorted_tables):
            db.execute(table.delete())
        db.commit()
        yield db
    finally:
        db.close()

@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture
def test_data(db_session):
    user1 = User(email="user1@test.com", password="pwd", name="User 1")
    user2 = User(email="user2@test.com", password="pwd", name="User 2")
    
    db_session.add_all([user1, user2])
    db_session.commit()
    db_session.refresh(user1)
    db_session.refresh(user2)
    
    home1 = Home(title="Home 1", description="Desc", country="US", city="NY", capacity=2, available_from=date.today(), available_to=date.today()+timedelta(days=30), owner_id=user1.id)
    home2 = Home(title="Home 2", description="Desc", country="UK", city="LDN", capacity=2, available_from=date.today(), available_to=date.today()+timedelta(days=30), owner_id=user2.id)
    
    db_session.add_all([home1, home2])
    db_session.commit()
    db_session.refresh(home1)
    db_session.refresh(home2)
    
    return {
        "user1": user1,
        "user2": user2,
        "home1": home1,
        "home2": home2
    }

def test_tc_3_1_instant_push_notification(client, test_data):
    """
    Test real-time notifications by opening a WebSocket and triggering a swap request creation.
    """
    user1 = test_data["user1"]
    user2 = test_data["user2"]
    home1 = test_data["home1"]
    home2 = test_data["home2"]
    
    # We will simulate the request as user1
    app.dependency_overrides[get_current_user] = lambda: user1

    # Connect to user2's notification websocket
    with client.websocket_connect(f"/ws/notifications/{user2.id}") as websocket:
        
        # Make an HTTP POST to create a swap request (from user1 to user2)
        payload = {
            "host_id": user2.id,
            "requester_home_id": home1.id,
            "host_home_id": home2.id,
            "start_date": str(date.today()),
            "end_date": str(date.today() + timedelta(days=5)),
            "intro_message": "Hello, I want to swap!"
        }
        
        resp = client.post("/swap-requests/", json=payload)
        assert resp.status_code == 201
        
        # TestClient executes background tasks inline automatically.
        # The WebSocket should now have the real-time notification.
        data = websocket.receive_json()
        
        assert "type" in data
        assert data["type"] == "new_request"
        assert "message" in data
