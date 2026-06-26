import requests
from database import SessionLocal
from models import User, SwapRequest
from auth_middleware import create_access_token

db = SessionLocal()

# Find a completed swap request
req = db.query(SwapRequest).filter(SwapRequest.status == "completed").first()
if not req:
    print("No completed swap requests found.")
    exit()

# Get the host of this swap request
host = db.query(User).filter(User.id == req.host_id).first()

# Generate a token for the host
token = create_access_token(data={"sub": str(host.id)})

# Try to submit a review as the host for the requester
url = "http://127.0.0.1:8000/reviews/"
headers = {"Authorization": f"Bearer {token}"}
data = {
    "swap_request_id": req.id,
    "home_id": req.requester_home_id,
    "rating": 5,
    "comment": "Amazing stay!"
}

res = requests.post(url, headers=headers, json=data)
print(f"Status: {res.status_code}")
print(f"Response: {res.text}")
