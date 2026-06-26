import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import date, timedelta

from main import app
from database import Base, get_db
from models import User, Home, SwapRequest, SwapRequestStatus
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
    user3 = User(email="user3@test.com", password="pwd", name="User 3")
    
    db_session.add_all([user1, user2, user3])
    db_session.commit()
    
    home1 = Home(title="Home 1", description="Desc", country="US", city="NY", capacity=2, available_from=date.today(), available_to=date.today()+timedelta(days=30), owner_id=user1.id)
    home2 = Home(title="Home 2", description="Desc", country="UK", city="LDN", capacity=2, available_from=date.today(), available_to=date.today()+timedelta(days=30), owner_id=user2.id)
    home3 = Home(title="Home 3", description="Desc", country="FR", city="PAR", capacity=2, available_from=date.today(), available_to=date.today()+timedelta(days=30), owner_id=user3.id)
    
    db_session.add_all([home1, home2, home3])
    db_session.commit()
    
    return {
        "user1": user1, "user2": user2, "user3": user3,
        "home1": home1, "home2": home2, "home3": home3
    }

def test_tc_1_1_double_booking_prevention(client, db_session, test_data):
    user1 = test_data["user1"]
    user2 = test_data["user2"]
    user3 = test_data["user3"]
    
    home1 = test_data["home1"]
    home2 = test_data["home2"]
    home3 = test_data["home3"]
    
    start_dt = date.today()
    end_dt = date.today() + timedelta(days=5)
    
    req1 = SwapRequest(
        requester_id=user1.id,
        host_id=user2.id,
        requester_home_id=home1.id,
        host_home_id=home2.id,
        start_date=start_dt,
        end_date=end_dt,
        status=SwapRequestStatus.PENDING
    )
    
    db_session.add(req1)
    db_session.commit()
    
    app.dependency_overrides[get_current_user] = lambda: user2
    
    resp1 = client.patch(f"/swap-requests/{req1.id}/status", json={"status": "accepted"})
    assert resp1.status_code == 200
    
    # Create the second request AFTER the first is accepted to bypass auto-decline and hit the 409 overlap logic
    req2 = SwapRequest(
        requester_id=user3.id,
        host_id=user2.id,
        requester_home_id=home3.id,
        host_home_id=home2.id,
        start_date=start_dt,
        end_date=end_dt,
        status=SwapRequestStatus.PENDING
    )
    db_session.add(req2)
    db_session.commit()
    
    resp2 = client.patch(f"/swap-requests/{req2.id}/status", json={"status": "accepted"})
    assert resp2.status_code == 409, f"Expected 409 Conflict, got {resp2.status_code}"

def test_tc_1_2_invalid_status_transition(client, db_session, test_data):
    user1 = test_data["user1"]
    user2 = test_data["user2"]
    home1 = test_data["home1"]
    home2 = test_data["home2"]
    
    start_dt = date.today()
    end_dt = date.today() + timedelta(days=5)
    
    req = SwapRequest(
        requester_id=user1.id,
        host_id=user2.id,
        requester_home_id=home1.id,
        host_home_id=home2.id,
        start_date=start_dt,
        end_date=end_dt,
        status=SwapRequestStatus.PENDING
    )
    
    db_session.add(req)
    db_session.commit()
    
    app.dependency_overrides[get_current_user] = lambda: user2
    
    resp = client.patch(f"/swap-requests/{req.id}/status", json={"status": "completed"})
    assert resp.status_code in [400, 422], f"Expected 400 or 422, got {resp.status_code}"
