from database import SessionLocal
from models import Match

db = SessionLocal()
matches = db.query(Match).all()
cleared = 0
for m in matches:
    if m.match_explanation:
        m.match_explanation = None
        m.compatibility_score = None
        cleared += 1

db.commit()
print(f"Cleared {cleared} matches.")
