import asyncio
from database import SessionLocal
from models import User
from endpoints.match_routes import get_matches

async def test():
    db = SessionLocal()
    # Find a user with a trip preference
    from models import TripPreference
    pref = db.query(TripPreference).first()
    if not pref:
        print("No trip preference found.")
        return
    user = db.query(User).filter(User.id == pref.user_id).first()
    
    print(f"Running get_matches for user {user.name} (id={user.id})")
    try:
        res = await get_matches(db, user)
        matches = res.get("matches", [])
        print(f"Returned {len(matches)} matches.")
        if matches:
            top_match = matches[0]
            print("Top Match AI Score:", top_match.get("compatibility_score"))
            print("Top Match AI Explanation Length:", len(top_match.get("match_explanation", "")))
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    asyncio.run(test())
