from sqlalchemy.orm import Session
from datetime import date, timedelta
from passlib.context import CryptContext

import sys
import os
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

def seed_db():
    db = SessionLocal()
    
    # Clean up old test data to ensure fresh seed
    test_emails = [
        "tester@swapscout.com",
        "host_a@example.com",
        "host_b@example.com",
        "host_c@example.com",
        "host_d@example.com",
        "host_e@example.com",
        "host_f@example.com"
    ]
    db.query(User).filter(User.email.in_(test_emails)).delete(synchronize_session=False)
    db.commit()
        
    print("Seeding test users...")
    
    # 1. Main Test User (The one the user logs into)
    user_main = User(
        email="tester@swapscout.com",
        password=get_password_hash("testpass123"),
        name="Alex the Tester",
        country="USA",
        city="New York",
        lifestyle_tags="Remote Worker, Coffee Enthusiast, Fitness, Tech",
        bio="Hi! I am a remote software engineer from NYC. I love exploring new cities, working from local cafes, and running in the mornings. I'm looking for a quiet place with good Wi-Fi to work from, preferably somewhere with beautiful views or a vibrant city life."
    )
    
    # 2. Host A (Mountain Cabin)
    user_host_a = User(
        email="host_a@example.com",
        password=get_password_hash("pass"),
        name="Sarah Hiker",
        country="Switzerland",
        city="Zermatt",
        lifestyle_tags="Nature Lover, Hiking, Skiing, Photography",
        bio="I am an outdoor enthusiast living in the Swiss Alps. In my free time, I ski, hike, and take landscape photos. Let me host you in my cozy cabin!"
    )
    
    # 3. Host B (Beach Villa)
    user_host_b = User(
        email="host_b@example.com",
        password=get_password_hash("pass"),
        name="David Waves",
        country="Spain",
        city="Ibiza",
        lifestyle_tags="Surfing, Nightlife, Beach, Swimming",
        bio="Sun, sand, and surf! I live in beautiful Ibiza and love to share the island life. I enjoy good parties, electronic music, and surfing early in the morning."
    )
    
    # 4. Host C (City Apartment)
    user_host_c = User(
        email="host_c@example.com",
        password=get_password_hash("pass"),
        name="Emma Culture",
        country="Japan",
        city="Tokyo",
        lifestyle_tags="Foodie, Anime, Technology, Architecture",
        bio="I'm an architect living in the heart of Tokyo. I love exploring hidden ramen shops, visiting modern art museums, and enjoying high-tech living."
    )
    
    # 5. Host D (Traditional Ryokan)
    user_host_d = User(
        email="host_d@example.com",
        password=get_password_hash("pass"),
        name="Kenji History",
        country="Japan",
        city="Tokyo",
        lifestyle_tags="History, Tea, Zen, Traditional, Nature",
        bio="I am an elderly history professor. I live in a preserved historic district of Tokyo in a traditional Ryokan. I enjoy making matcha tea, gardening my bonsai trees, and leading a quiet, zen lifestyle away from the fast-paced city."
    )
    
    # 6. Host E (Minimalist Capsule)
    user_host_e = User(
        email="host_e@example.com",
        password=get_password_hash("pass"),
        name="Yuki Artist",
        country="Japan",
        city="Tokyo",
        lifestyle_tags="Introvert, Manganese, Art, Coffee, Night Owl",
        bio="I draw manga for a living and spend most of my time indoors. My tiny capsule home is super minimalist, strictly focused on productivity and drawing. I love drinking strong black coffee at 3 AM."
    )

    # 7. Host F (Luxury Penthouse)
    user_host_f = User(
        email="host_f@example.com",
        password=get_password_hash("pass"),
        name="Toshiro Executive",
        country="Japan",
        city="Tokyo",
        lifestyle_tags="Luxury, Fine Dining, Business, Nightlife, Fitness",
        bio="I am a corporate executive running a tech firm in Roppongi. I love the high life, eating at Michelin star sushi restaurants, networking, and working out in my private gym overlooking the city skyline."
    )
    
    db.add_all([user_main, user_host_a, user_host_b, user_host_c, user_host_d, user_host_e, user_host_f])
    db.commit()
    
    print("Seeding test homes...")
    
    # Seed Homes
    home_a = Home(
        title="Cozy Alpine Cabin with Matterhorn Views",
        description="A beautiful wooden cabin tucked away in the Alps. Includes a large fireplace, heavy winter blankets, and a spectacular balcony view of the Matterhorn. Perfect for nature lovers.",
        country="Switzerland",
        city="Zermatt",
        capacity=4,
        amenities="Wi-Fi, Heating, Fireplace, Kitchen, Balcony, Mountain View",
        environment="Mountain",
        property_type="Cabin",
        is_hidden=False,
        available_from=date.today(),
        available_to=date.today() + timedelta(days=90),
        images=["https://images.unsplash.com/photo-1510798831971-661eb04b3739?q=80&w=1400&auto=format&fit=crop"],
        owner_id=user_host_a.id,
        latitude=46.0207,
        longitude=7.7491
    )
    
    home_b = Home(
        title="Modern Ibiza Beach Villa",
        description="Luxurious modern villa steps away from the beach. Features a private infinity pool, massive outdoor grill, and a rooftop bar. Ideal for anyone looking to enjoy the sun and sea.",
        country="Spain",
        city="Ibiza",
        capacity=8,
        amenities="Wi-Fi, Air Conditioning, Pool, Outdoor Grill, Beach Access, Kitchen",
        environment="Beach",
        property_type="Villa",
        is_hidden=False,
        available_from=date.today(),
        available_to=date.today() + timedelta(days=90),
        images=["https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?q=80&w=1400&auto=format&fit=crop"],
        owner_id=user_host_b.id,
        latitude=38.9067,
        longitude=1.4206
    )
    
    home_c = Home(
        title="High-Tech Shinjuku Apartment",
        description="A sleek, modern apartment in Shinjuku. Equipped with a smart home system, blazing fast fiber internet perfectly suited for remote work, and is just a 5 minute walk from the nearest subway station.",
        country="Japan",
        city="Tokyo",
        capacity=2,
        amenities="Wi-Fi, Air Conditioning, Workspace, TV, Kitchen, Washer",
        environment="City",
        property_type="Apartment",
        is_hidden=False,
        available_from=date.today(),
        available_to=date.today() + timedelta(days=90),
        images=["https://images.unsplash.com/photo-1503899036084-c55cdd92da26?q=80&w=1400&auto=format&fit=crop"],
        owner_id=user_host_c.id,
        latitude=35.6938,
        longitude=139.7034
    )

    home_d = Home(
        title="Authentic Asakusa Ryokan",
        description="A 100-year-old preserved traditional Ryokan. Sleep on tatami mats, slide open shoji screens to view a private zen garden, and enjoy complete silence. No TVs, no loud noises, just peace.",
        country="Japan",
        city="Tokyo",
        capacity=4,
        amenities="Heating, Tea Set, Tatami, Zen Garden, Bathhouse, Quiet",
        environment="City",
        property_type="House",
        is_hidden=False,
        available_from=date.today(),
        available_to=date.today() + timedelta(days=90),
        images=["https://images.unsplash.com/photo-1542052125323-e69ad37a47c2?q=80&w=1400&auto=format&fit=crop"],
        owner_id=user_host_d.id,
        latitude=35.7118,
        longitude=139.7967
    )

    home_e = Home(
        title="Akihabara Minimalist Capsule",
        description="A tiny, incredibly efficient capsule apartment in the heart of Anime central. Perfect for a solo traveler who just needs a desk, strong coffee machine, and a bed.",
        country="Japan",
        city="Tokyo",
        capacity=1,
        amenities="Wi-Fi, Workspace, Coffee Maker, Air Conditioning",
        environment="City",
        property_type="Apartment",
        is_hidden=False,
        available_from=date.today(),
        available_to=date.today() + timedelta(days=90),
        images=["https://images.unsplash.com/photo-1510271796-0153efdb09ff?q=80&w=1400&auto=format&fit=crop"],
        owner_id=user_host_e.id,
        latitude=35.6983,
        longitude=139.7731
    )
    
    home_f = Home(
        title="Roppongi Ultra-Luxury Penthouse",
        description="Incredible penthouse spanning the entire top floor. 360-degree views of the Tokyo skyline, private gym, massive chef's kitchen, and a private elevator. Surrounded by the best nightclubs and restaurants.",
        country="Japan",
        city="Tokyo",
        capacity=6,
        amenities="Wi-Fi, Air Conditioning, Private Gym, Chef Kitchen, Elevator, City View, TV, Pool",
        environment="City",
        property_type="Villa",
        is_hidden=False,
        available_from=date.today(),
        available_to=date.today() + timedelta(days=90),
        images=["https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=1400&auto=format&fit=crop"],
        owner_id=user_host_f.id,
        latitude=35.6628,
        longitude=139.7314
    )
    
    db.add_all([home_a, home_b, home_c, home_d, home_e, home_f])
    db.commit()
    
    print("Seeding test trip preferences...")
    
    # Trip Preference for main user (So the app automatically searches for matches!)
    pref = TripPreference(
        user_id=user_main.id,
        preferred_country="Japan", # Initial preference
        preferred_city="Tokyo",
        start_date=date.today() + timedelta(days=10),
        end_date=date.today() + timedelta(days=20),
        guests=1,
        lifestyle_tags=["Technology", "Foodie", "Remote Work"]
    )
    db.add(pref)
    db.commit()
    
    print("Database seeding complete!")
    print("="*40)
    print("You can now test the AI Matchmaking system.")
    print("1. Login Email: tester@swapscout.com")
    print("2. Password:   testpass123")
    print("="*40)

if __name__ == "__main__":
    seed_db()
