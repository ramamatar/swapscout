import os
import sys
import random
from datetime import date, timedelta
from faker import Faker
from sqlalchemy.orm import Session

# Add current dir to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import User, Home, TripPreference

try:
    from utils.security import hash_password as get_password_hash
except ImportError:
    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
    def get_password_hash(password):
        return pwd_context.hash(password)

fake = Faker()

# Data Pools
LOCATIONS = [
    ("France", "Paris", "City"),
    ("France", "Lyon", "City"),
    ("France", "Nice", "Beach"),
    ("UK", "London", "City"),
    ("UK", "Edinburgh", "City"),
    ("UK", "Cornwall", "Beach"),
    ("USA", "New York", "City"),
    ("USA", "Los Angeles", "Beach"),
    ("USA", "Denver", "Mountain"),
    ("USA", "Miami", "Beach"),
    ("Japan", "Tokyo", "City"),
    ("Japan", "Kyoto", "City"),
    ("Japan", "Okinawa", "Beach"),
    ("Italy", "Rome", "City"),
    ("Italy", "Milan", "City"),
    ("Italy", "Amalfi", "Beach"),
    ("Italy", "Dolomites", "Mountain"),
    ("Australia", "Sydney", "Beach"),
    ("Australia", "Melbourne", "City"),
    ("Switzerland", "Zurich", "City"),
    ("Switzerland", "Zermatt", "Mountain")
]

PROPERTY_TYPES = [
    "Apartment", "House", "Villa", "Cottage", "Cabin", "Studio", "Penthouse"
]

LIFESTYLE_TAGS = [
    "Foodie", "Remote Worker", "Architecture", "Art", "Nightlife", "Nature", 
    "Hiking", "Skiing", "Surfing", "History", "Coffee", "Yoga", "Photography", 
    "Vegan", "Fitness", "Music", "Pet Lover"
]

AMENITIES = [
    "Wi-Fi", "Air Conditioning", "Heating", "Pool", "Gym", "Kitchen", "Workspace",
    "Balcony", "Parking", "Washer", "Dryer", "TV", "Fireplace", "Garden", "Beach Access",
    "Mountain View", "City View", "Pet Friendly", "Elevator", "Hot Tub"
]

HOME_IMAGES = [
    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=1400&auto=format&fit=crop", # Apartment
    "https://images.unsplash.com/photo-1510798831971-661eb04b3739?q=80&w=1400&auto=format&fit=crop", # Cabin
    "https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?q=80&w=1400&auto=format&fit=crop", # Villa
    "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?q=80&w=1400&auto=format&fit=crop", # Modern
    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?q=80&w=1400&auto=format&fit=crop", # Pool
    "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?q=80&w=1400&auto=format&fit=crop", # House Exterior
    "https://images.unsplash.com/photo-1484154218962-a197022b5858?q=80&w=1400&auto=format&fit=crop", # Kitchen
    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?q=80&w=1400&auto=format&fit=crop", # Living Room
    "https://images.unsplash.com/photo-1502672260266-1c1c65d6cff7?q=80&w=1400&auto=format&fit=crop", # Bedroom
    "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?q=80&w=1400&auto=format&fit=crop"  # Beautiful house
]

def generate_sentence():
    return fake.sentence(nb_words=12)

def generate_bio():
    return f"Hi, I'm {fake.first_name()}. {fake.paragraph(nb_sentences=3)} I love traveling and experiencing new cultures. I work as a {fake.job()} and enjoy my free time."

def seed_massive_db(num_users=50, num_homes=50):
    db = SessionLocal()
    
    print(f"Generating {num_users} Users...")
    users = []
    
    # Random default password for all
    hashed_pwd = get_password_hash("password123")
    
    for i in range(num_users):
        user_country, user_city, _ = random.choice(LOCATIONS)
        
        # Pick 3-5 random lifestyle tags
        tags = random.sample(LIFESTYLE_TAGS, random.randint(3, 5))
        
        user = User(
            email=f"{fake.user_name()}_{i}@fakemail.com",
            password=hashed_pwd,
            name=fake.name(),
            country=user_country,
            city=user_city,
            lifestyle_tags=", ".join(tags),
            bio=generate_bio()
        )
        db.add(user)
        users.append(user)
    
    db.commit()
    for user in users:
        db.refresh(user)
        
    print(f"Generating {num_homes} Homes...")
    homes = []
    for i in range(num_homes):
        home_country, home_city, environment = random.choice(LOCATIONS)
        prop_type = random.choice(PROPERTY_TYPES)
        
        # Pick 5-10 random amenities
        amenities = random.sample(AMENITIES, random.randint(5, 10))
        
        # Pick a random owner from our newly generated users
        owner = random.choice(users)
        
        # Ensure available dates
        start_date = date.today() + timedelta(days=random.randint(0, 30))
        end_date = start_date + timedelta(days=random.randint(30, 180))
        
        home = Home(
            title=f"{fake.word().capitalize()} {prop_type} in {home_city}",
            description=f"A beautiful {prop_type.lower()} located in the heart of {home_city}. {fake.paragraph(nb_sentences=4)} It features amazing {environment.lower()} vibes.",
            country=home_country,
            city=home_city,
            capacity=random.randint(1, 8),
            amenities=", ".join(amenities),
            environment=environment,
            property_type=prop_type,
            is_hidden=False,
            available_from=start_date,
            available_to=end_date,
            images=[random.choice(HOME_IMAGES)],
            owner_id=owner.id
        )
        db.add(home)
        homes.append(home)
        
    db.commit()
    
    print("Database seeding entirely complete!")
    print("="*50)
    print(f"Successfully injected {num_users} diverse users and {num_homes} interactive homes globally.")
    print("You can search anywhere from Paris, to Sydney, to Zermatt!")
    print("Password for all newly generated accounts if u want to login to them: password123")
    print("="*50)


if __name__ == "__main__":
    seed_massive_db()
