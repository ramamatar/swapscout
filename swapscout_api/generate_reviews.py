from sqlalchemy.orm import Session
from datetime import date, timedelta
import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import User, Home, SwapRequest, SwapRequestStatus, Review

def seed_reviews():
    db = SessionLocal()
    print("Starting review generation...")

    # 1. Fetch users
    tester = db.query(User).filter(User.email == "tester@swapscout.com").first()
    host_a = db.query(User).filter(User.email == "host_a@example.com").first()
    host_b = db.query(User).filter(User.email == "host_b@example.com").first()

    if not all([tester, host_a, host_b]):
        print("Users missing, run generate_test_data.py first.")
        return

    # Check if tester has a home, if not create one
    tester_home = db.query(Home).filter(Home.owner_id == tester.id).first()
    if not tester_home:
        print("Creating a home for tester...")
        tester_home = Home(
            title="Tester's NYC Loft",
            description="A spacious loft in Brooklyn with great views and lots of plants.",
            country="USA",
            city="New York",
            capacity=2,
            amenities="Wi-Fi, Kitchen, AC, Washer",
            environment="City",
            property_type="Apartment",
            available_from=date.today(),
            available_to=date.today() + timedelta(days=90),
            owner_id=tester.id,
            latitude=40.7128,
            longitude=-74.0060,
            images=["https://images.unsplash.com/photo-1502672260266-1c1e52409818?q=80&w=1400&auto=format&fit=crop"]
        )
        db.add(tester_home)
        db.commit()
        db.refresh(tester_home)

    home_a = db.query(Home).filter(Home.owner_id == host_a.id).first()
    home_b = db.query(Home).filter(Home.owner_id == host_b.id).first()

    # 2. Clear old reviews and requests to prevent duplicates
    db.query(Review).delete()
    db.query(SwapRequest).filter(SwapRequest.intro_message == "Test Swap for Reviews").delete(synchronize_session=False)
    db.commit()

    # 3. Create completed swap requests
    print("Creating completed swap requests...")
    req1 = SwapRequest(
        requester_id=tester.id,
        host_id=host_a.id,
        requester_home_id=tester_home.id,
        host_home_id=home_a.id,
        start_date=date.today() - timedelta(days=20),
        end_date=date.today() - timedelta(days=15),
        intro_message="Test Swap for Reviews",
        status=SwapRequestStatus.COMPLETED
    )
    
    req2 = SwapRequest(
        requester_id=host_b.id,
        host_id=tester.id,
        requester_home_id=home_b.id,
        host_home_id=tester_home.id,
        start_date=date.today() - timedelta(days=30),
        end_date=date.today() - timedelta(days=25),
        intro_message="Test Swap for Reviews",
        status=SwapRequestStatus.COMPLETED
    )

    db.add_all([req1, req2])
    db.commit()
    db.refresh(req1)
    db.refresh(req2)

    # 4. Create reviews
    print("Creating reviews...")
    # Tester reviews Host A
    rev1 = Review(
        swap_request_id=req1.id,
        reviewer_id=tester.id,
        reviewee_id=host_a.id,
        home_id=home_a.id,
        rating=5,
        comment="Absolutely amazing cabin! Sarah was a wonderful host and the views of the Matterhorn were breathtaking. Highly recommend!"
    )
    
    # Host A reviews Tester
    rev2 = Review(
        swap_request_id=req1.id,
        reviewer_id=host_a.id,
        reviewee_id=tester.id,
        home_id=tester_home.id,
        rating=4,
        comment="Alex was a great guest. Left the cabin very clean. The NYC loft was spacious and close to the subway."
    )

    # Host B reviews Tester
    rev3 = Review(
        swap_request_id=req2.id,
        reviewer_id=host_b.id,
        reviewee_id=tester.id,
        home_id=tester_home.id,
        rating=5,
        comment="Awesome experience swapping with Alex! Very communicative and friendly."
    )

    db.add_all([rev1, rev2, rev3])
    db.commit()

    # 5. Update Home averages
    print("Updating home averages...")
    for home in [tester_home, home_a]:
        reviews = db.query(Review).filter(Review.home_id == home.id).all()
        if reviews:
            home.total_reviews = len(reviews)
            home.average_rating = sum([r.rating for r in reviews]) / len(reviews)
            db.add(home)
    
    db.commit()
    print("Review generation complete!")
    print(f"Tester's NYC Loft now has {tester_home.total_reviews} reviews with a {tester_home.average_rating} rating.")
    print(f"Host A's Cabin now has {home_a.total_reviews} reviews with a {home_a.average_rating} rating.")

if __name__ == "__main__":
    seed_reviews()
