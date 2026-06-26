import requests

login_res = requests.post("http://127.0.0.1:8000/auth/login", json={"email": "arda@test.com", "password": "password123"})
token = login_res.json().get("access_token")
if not token:
    print("Login failed:", login_res.text)
    exit()

headers = {"Authorization": f"Bearer {token}"}

trips_res = requests.get("http://127.0.0.1:8000/swap-requests/me", headers=headers)
trips = trips_res.json()
completed = [t for t in trips if t["status"] == "completed"]

if completed:
    req = completed[0]
    home_id = req["host_home_id"]
    print(f"Submitting review for swap {req['id']} and home {home_id}")
    rev_res = requests.post("http://127.0.0.1:8000/reviews/", headers=headers, json={
        "swap_request_id": req["id"],
        "home_id": home_id,
        "rating": 5,
        "comment": "Test review"
    })
    print("Status:", rev_res.status_code)
    print("Response:", rev_res.text)
else:
    print("No completed trips found for alice.")
