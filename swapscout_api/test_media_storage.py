import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import date, timedelta
import io

from main import app
from database import Base, get_db
from models import User, Home, HomeImage
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

    from auth_middleware import get_db as auth_get_db
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[auth_get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture
def test_data(db_session):
    user1 = User(email="user1@test.com", password="pwd", name="User 1")
    
    db_session.add(user1)
    db_session.commit()
    db_session.refresh(user1)
    
    home1 = Home(title="Home 1", description="Desc", country="US", city="NY", capacity=2, available_from=date.today(), available_to=date.today()+timedelta(days=30), owner_id=user1.id)
    
    db_session.add(home1)
    db_session.commit()
    db_session.refresh(home1)
    
    return {
        "user1": user1,
        "home1": home1
    }

def test_tc_4_1_bytea_image_insertion(client, db_session, test_data):
    """
    Test uploading a dummy .jpg file to PostgreSQL BYTEA storage.
    """
    user1 = test_data["user1"]
    home1 = test_data["home1"]
    
    app.dependency_overrides[get_current_user] = lambda: user1

    # Create dummy JPEG file in memory
    dummy_image = io.BytesIO(b"fake_jpeg_binary_data")
    files = {"file": ("test.jpg", dummy_image, "image/jpeg")}
    
    # Send POST multipart/form-data
    resp = client.post(f"/homes/{home1.id}/images", files=files)
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
    
    # Query test database to assert record was created in HomeImage
    home_image = db_session.query(HomeImage).filter(HomeImage.home_id == home1.id).first()
    
    assert home_image is not None, "HomeImage record was not created."
    assert home_image.image_data is not None, "BYTEA image_data is null."
    assert home_image.content_type == "image/jpeg", "Content type mismatch."

def test_tc_4_2_binary_image_streaming(client, db_session, test_data):
    """
    Test fetching and streaming the binary image data.
    """
    home1 = test_data["home1"]
    
    # Insert a dummy image directly into the database
    home_image = HomeImage(
        home_id=home1.id,
        image_data=b"fake_streaming_binary_data",
        content_type="image/jpeg"
    )
    db_session.add(home_image)
    db_session.commit()
    db_session.refresh(home_image)
    
    # Send GET request to image streaming endpoint
    resp = client.get(f"/images/{home_image.id}")
    
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
    assert resp.headers.get("content-type") == "image/jpeg"
    assert resp.content == b"fake_streaming_binary_data"
