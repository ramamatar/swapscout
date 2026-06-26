import asyncio
import os
from dotenv import load_dotenv
load_dotenv()

from database import SessionLocal
from models import User, Home, TripPreference
from services.ai_match_service import generate_compatibility_async

async def test():
    db = SessionLocal()
    pref = db.query(TripPreference).first()
    if not pref:
        print("No trip preference found.")
        return
    user = db.query(User).filter(User.id == pref.user_id).first()
    home = db.query(Home).filter(Home.owner_id != user.id).first()
    host = db.query(User).filter(User.id == home.owner_id).first()
    
    print(f"Running async test...")
    try:
        tasks = []
        for i in range(5):
            tasks.append(generate_compatibility_async(user, host, home, pref))
        
        results = await asyncio.gather(*tasks)
        for i, res in enumerate(results):
            print(f"Result {i}: score={res.get('compatibility_score')}")
            if "System Fallback" in res.get('match_explanation', ''):
                print("  -> HIT SYSTEM FALLBACK")
                
    except Exception as e:
        print("Main Error:", e)

if __name__ == "__main__":
    asyncio.run(test())
