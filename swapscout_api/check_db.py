from database import SessionLocal
from models import SwapRequest, SwapRequestStatus

db = SessionLocal()
reqs = db.query(SwapRequest).all()

for r in reqs:
    print(f"ID: {r.id}, Status: {r.status}, Requester: {r.requester_id}, Host: {r.host_id}, Requester Home: {r.requester_home_id}, Host Home: {r.host_home_id}")

db.close()
