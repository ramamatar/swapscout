import os
from dotenv import load_dotenv
load_dotenv()

from database import SessionLocal
from models import User, Home, TripPreference
from services.ai_match_service import generate_compatibility

db = SessionLocal()
traveler = db.query(User).first()
host = db.query(User).filter(User.id != traveler.id).first()
home = db.query(Home).filter(Home.owner_id == host.id).first()
trip_pref = db.query(TripPreference).filter(TripPreference.user_id == traveler.id).first()

print("Generating compatibility...")
res = generate_compatibility(traveler, host, home, trip_pref)
print(res)
