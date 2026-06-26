"""
SwapScout Graduation Demo Seed Script
======================================
Generates a complete, consistent, flawlessly interconnected dataset for demo.

Users:    Rama (main), Ahmet, Zeynep, Can
Homes:    6 Turkish properties across Cappadocia, Istanbul, Antalya, Ankara, Izmir, Mugla
Swaps:    1 pending, 1 accepted (future/locks dates), 2 completed (one with review, one without)
Reviews:  1 existing review (Ahmet → Rama's Istanbul home)
Favorites: Rama has 2 favorites (Antalya, Izmir)
Messages:  Rama ↔ Ahmet conversation
Notifications: unread for Rama and Ahmet
Geospatial: Cappadocia cluster (50km/20km/5km radius demo)
AI Matching: 3 score bands engineered (90-95%, 55-65%, <40%) relative to Rama's TripPreference

Run:
    cd swapscout_api
    python seed_graduation_demo.py
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from datetime import date, datetime, timedelta, timezone
from database import SessionLocal
from models import (
    User, Home, HomeBooking, TripPreference,
    SwapRequest, SwapRequestStatus,
    Review, Favorite, Message, Notification, Activity
)
from utils.security import hash_password

# ─────────────────────────────────────────────────────────────────────────────
# DEMO EMAILS (used for idempotent cleanup)
# ─────────────────────────────────────────────────────────────────────────────
DEMO_EMAILS = [
    "rama@swapscout.com",
    "ahmet@swapscout.com",
    "zeynep@swapscout.com",
    "can@swapscout.com",
]

# Fixed reference dates
TODAY = date(2026, 6, 19)

def wipe_demo_data(db):
    """Remove all previous demo data in dependency order."""
    print("🧹 Wiping previous demo data...")

    # Fetch user IDs first
    users = db.query(User).filter(User.email.in_(DEMO_EMAILS)).all()
    user_ids = [u.id for u in users]

    if not user_ids:
        print("   No previous demo data found.")
        return

    home_ids = [h.id for h in db.query(Home).filter(Home.owner_id.in_(user_ids)).all()]

    # Delete in dependency order
    if home_ids:
        db.query(HomeBooking).filter(HomeBooking.home_id.in_(home_ids)).delete(synchronize_session=False)
        db.query(Favorite).filter(Favorite.home_id.in_(home_ids)).delete(synchronize_session=False)
        db.query(Review).filter(Review.home_id.in_(home_ids)).delete(synchronize_session=False)

    if user_ids:
        swap_ids = [
            r.id for r in db.query(SwapRequest).filter(
                SwapRequest.requester_id.in_(user_ids) | SwapRequest.host_id.in_(user_ids)
            ).all()
        ]
        if swap_ids:
            db.query(Review).filter(Review.swap_request_id.in_(swap_ids)).delete(synchronize_session=False)
        db.query(SwapRequest).filter(
            SwapRequest.requester_id.in_(user_ids) | SwapRequest.host_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db.query(Message).filter(
            Message.sender_id.in_(user_ids) | Message.receiver_id.in_(user_ids)
        ).delete(synchronize_session=False)
        db.query(Notification).filter(Notification.user_id.in_(user_ids)).delete(synchronize_session=False)
        db.query(Activity).filter(Activity.user_id.in_(user_ids)).delete(synchronize_session=False)
        db.query(TripPreference).filter(TripPreference.user_id.in_(user_ids)).delete(synchronize_session=False)
        db.query(Favorite).filter(Favorite.user_id.in_(user_ids)).delete(synchronize_session=False)

    if home_ids:
        db.query(Home).filter(Home.id.in_(home_ids)).delete(synchronize_session=False)

    db.query(User).filter(User.email.in_(DEMO_EMAILS)).delete(synchronize_session=False)
    db.commit()
    print("   ✅ Wipe complete.")


def seed():
    db = SessionLocal()
    try:
        wipe_demo_data(db)

        # ─────────────────────────────────────────────────────────
        # 1. USERS
        # ─────────────────────────────────────────────────────────
        print("\n👤 Creating users...")

        rama = User(
            email="rama@swapscout.com",
            password=hash_password("demo1234"),
            name="Rama Matar",
            country="Turkey",
            city="Istanbul",
            lifestyle_tags="Beach, Relaxing, Swimming, Outdoor, Sunset",
            bio=(
                "I'm a software engineer based in Istanbul who loves coastal escapes. "
                "I enjoy swimming, watching sunsets, and relaxing near the sea. "
                "I'm looking for a quiet beach property where I can unwind and recharge. "
                "I have a beautiful Bosphorus-view apartment to offer in return."
            )
        )

        ahmet = User(
            email="ahmet@swapscout.com",
            password=hash_password("demo1234"),
            name="Ahmet Yilmaz",
            country="Turkey",
            city="Antalya",
            lifestyle_tags="Beach, Swimming, Pool, Outdoor, Sun",
            bio=(
                "I'm a local tour guide from Antalya. My coastal villa has a private pool "
                "and direct beach access. I love connecting travelers with the hidden gems "
                "of the Turkish Riviera. Seeking city experiences in return."
            )
        )

        zeynep = User(
            email="zeynep@swapscout.com",
            password=hash_password("demo1234"),
            name="Zeynep Kaya",
            country="Turkey",
            city="Cappadocia",
            lifestyle_tags="Culture, Hiking, Nature, History, Photography",
            bio=(
                "Artist and cave hotel owner in Cappadocia. I wake up to hot air balloon views "
                "every morning. Passionate about the unique geological and cultural heritage of "
                "Central Anatolia. Looking to explore Istanbul's art scene."
            )
        )

        can = User(
            email="can@swapscout.com",
            password=hash_password("demo1234"),
            name="Can Demir",
            country="Turkey",
            city="Ankara",
            lifestyle_tags="City, Museums, Architecture, Coffee, Culture",
            bio=(
                "Urban planner and architecture enthusiast based in Ankara. "
                "My modern apartment is a 5-minute walk from Atatürk Cultural Center. "
                "I love visiting museums, trying specialty coffee, and exploring historic districts."
            )
        )

        db.add_all([rama, ahmet, zeynep, can])
        db.commit()
        print(f"   ✅ rama.id={rama.id}, ahmet.id={ahmet.id}, zeynep.id={zeynep.id}, can.id={can.id}")

        # ─────────────────────────────────────────────────────────
        # 2. HOMES
        # ─────────────────────────────────────────────────────────
        print("\n🏠 Creating homes...")

        # ── HOME 1: Rama's Istanbul apartment (Rama's own listing)
        home_istanbul = Home(
            title="Bosphorus-View Apartment in Beşiktaş",
            description=(
                "A stunning modern apartment on the 8th floor with panoramic Bosphorus views. "
                "Located in the vibrant Beşiktaş neighborhood, walking distance to ferries, "
                "fish restaurants, and weekend markets. "
                "Features a large balcony perfect for sunset dinners, fully equipped kitchen, "
                "high-speed fiber Wi-Fi ideal for remote work, and a cozy fireplace for winter evenings. "
                "The living room has a 65-inch smart TV and a dedicated workspace."
            ),
            country="Turkey",
            city="Istanbul",
            capacity=2,
            amenities="Wi-Fi, Kitchen, Fireplace, TV, Balcony, Washer, Air Conditioning, Workspace",
            environment="City",
            property_type="Apartment",
            is_hidden=False,
            available_from=TODAY,
            available_to=TODAY + timedelta(days=180),
            latitude=41.0451,
            longitude=29.0076,
            images=[
                "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?q=80&w=1400&auto=format&fit=crop",
                "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?q=80&w=1400&auto=format&fit=crop"
            ],
            owner_id=rama.id,
            total_reviews=1,
            average_rating=5.0
        )

        # ── HOME 2: Ahmet's Antalya Villa — HIGH COMPAT (90-95%) vs Rama's prefs
        # Rama likes Beach, Relaxing, Swimming, Outdoor, Sunset
        # This home: Beach, pool, sea view, garden → all 5 bio tags match perfectly
        home_antalya = Home(
            title="Antalya Beachfront Villa with Private Pool",
            description=(
                "A breathtaking Mediterranean villa sitting directly on Lara Beach. "
                "The private infinity pool overlooks the turquoise sea, perfect for morning swims. "
                "Enjoy outdoor dining on the garden terrace while watching the sunset over the Mediterranean. "
                "The property includes a fully equipped kitchen, outdoor seating area, "
                "a beach pergola, and direct beach access through a private gate. "
                "Ideal for anyone seeking complete beach relaxation."
            ),
            country="Turkey",
            city="Antalya",
            capacity=4,
            amenities="Wi-Fi, Pool, Kitchen, Garden, Outdoor Seating, Beach Access, Air Conditioning, TV",
            environment="Beach",
            property_type="Villa",
            is_hidden=False,
            available_from=TODAY,
            available_to=TODAY + timedelta(days=180),
            latitude=36.8841,
            longitude=30.7056,
            images=[
                # This image intentionally shows a pool, outdoor seating, and garden (Gemini Vision demo)
                "https://images.unsplash.com/photo-1575517111478-7f6afd0973db?q=80&w=1400&auto=format&fit=crop",
                "https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?q=80&w=1400&auto=format&fit=crop"
            ],
            owner_id=ahmet.id,
            total_reviews=0,
            average_rating=0.0
        )

        # ── HOME 3: Zeynep's Cappadocia Cave Hotel — MEDIUM COMPAT (55-65%) vs Rama's prefs
        # Rama likes Beach/Relaxing/Swimming/Outdoor/Sunset
        # Cave hotel: Mountain/Culture/History environment → partial bio match (Outdoor, Sunset yes; Beach/Swimming no)
        home_cappadocia = Home(
            title="Cave Suite Hotel in Göreme Valley",
            description=(
                "A unique 2-room cave suite carved into the volcanic tuff rock of Göreme. "
                "Wake up to the magic of hot air balloons drifting over the fairy chimneys. "
                "The terrace offers a stunning 180-degree valley view perfect for watching the sunset. "
                "Rustic stone interiors, antique kilim rugs, and hand-painted ceramics. "
                "Located 800m from Göreme Open Air Museum. Features a traditional stone fireplace, "
                "a private outdoor terrace, and a hammam-style bathroom."
            ),
            country="Turkey",
            city="Cappadocia",
            capacity=2,
            amenities="Wi-Fi, Fireplace, Kitchen, Outdoor Terrace, Heating, Air Conditioning",
            environment="Mountain",
            property_type="Cottage",
            is_hidden=False,
            available_from=TODAY,
            available_to=TODAY + timedelta(days=180),
            # Göreme center coordinates (used for radius demo)
            latitude=38.6431,
            longitude=34.8308,
            images=[
                "https://images.unsplash.com/photo-1601395838832-e0bb0698c8e8?q=80&w=1400&auto=format&fit=crop",
                "https://images.unsplash.com/photo-1569245616562-04d710c2e35b?q=80&w=1400&auto=format&fit=crop"
            ],
            owner_id=zeynep.id,
            total_reviews=0,
            average_rating=0.0
        )

        # ── HOME 4: Can's Ankara Apartment — LOW COMPAT (<40%) vs Rama's prefs
        # Rama likes Beach/Relaxing/Swimming/Outdoor/Sunset
        # Ankara: landlocked city, no pool, no beach, no sea → almost no bio match
        home_ankara = Home(
            title="Modern Apartment near Kızılay Metro",
            description=(
                "A sleek urban apartment in central Ankara, steps from Kızılay Metro Station. "
                "Perfectly configured for business travelers and culture enthusiasts. "
                "Spacious workspace with ultra-fast fiber internet, smart home controls, "
                "and blackout curtains for productive deep work. "
                "Walking distance to Anıtkabir, the Museum of Anatolian Civilizations, "
                "and dozens of specialty coffee shops and restaurants."
            ),
            country="Turkey",
            city="Ankara",
            capacity=2,
            amenities="Wi-Fi, Workspace, Air Conditioning, TV, Kitchen, Washer",
            environment="City",
            property_type="Apartment",
            is_hidden=False,
            available_from=TODAY,
            available_to=TODAY + timedelta(days=180),
            latitude=39.9334,
            longitude=32.8597,
            images=[
                "https://images.unsplash.com/photo-1540518614846-7eded433c457?q=80&w=1400&auto=format&fit=crop"
            ],
            owner_id=can.id,
            total_reviews=0,
            average_rating=0.0
        )

        # ── HOME 5: Ahmet's second property - Izmir — Rama has as favorite
        home_izmir = Home(
            title="Alaçatı Stone House with Garden & Outdoor Kitchen",
            description=(
                "A lovingly restored 150-year-old stone house in the cobblestone streets of Alaçatı. "
                "The private walled garden has a large outdoor kitchen, garden seating area, "
                "and a hammock under the bougainvillea. "
                "The house features original stone walls, a wood fireplace, "
                "hand-crafted Aegean furniture, and a rooftop terrace with sea views. "
                "Perfect for couples seeking authentic Aegean charm with beach access nearby."
            ),
            country="Turkey",
            city="İzmir",
            capacity=4,
            amenities="Wi-Fi, Garden, Outdoor Kitchen, Outdoor Seating, Fireplace, Kitchen, TV, Air Conditioning",
            environment="Beach",
            property_type="Cottage",
            is_hidden=False,
            available_from=TODAY,
            available_to=TODAY + timedelta(days=180),
            latitude=38.2800,
            longitude=26.3753,
            images=[
                # Stone house with visible outdoor kitchen, garden, fireplace (Gemini Vision demo)
                "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?q=80&w=1400&auto=format&fit=crop",
                "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?q=80&w=1400&auto=format&fit=crop"
            ],
            owner_id=ahmet.id,
            total_reviews=0,
            average_rating=0.0
        )

        # ── HOME 6: Zeynep's second listing — within Cappadocia (for radius demo)
        # Uçhisar: 6km from Göreme → inside 20km radius, outside 5km radius
        home_cappadocia_2 = Home(
            title="Uçhisar Castle View Suite",
            description=(
                "An enchanting boutique suite perched on the slopes of Uçhisar, "
                "overlooking the dramatic castle rock and the vast Cappadocian plateau. "
                "Hand-carved stone arches, vaulted ceilings, and a private terrace "
                "where you can watch the sunrise over the rose valley. "
                "The suite comes with heated stone floors, a traditional Turkish breakfast hamper, "
                "and personalized hot air balloon booking assistance."
            ),
            country="Turkey",
            city="Cappadocia",
            capacity=2,
            amenities="Wi-Fi, Heating, Kitchen, Outdoor Terrace, Air Conditioning, Fireplace",
            environment="Mountain",
            property_type="Cottage",
            is_hidden=False,
            available_from=TODAY,
            available_to=TODAY + timedelta(days=180),
            # Uçhisar: ~6 km from Göreme center
            latitude=38.6300,
            longitude=34.7980,
            images=[
                "https://images.unsplash.com/photo-1590073242678-70ee3fc28e8e?q=80&w=1400&auto=format&fit=crop"
            ],
            owner_id=zeynep.id,
            total_reviews=0,
            average_rating=0.0
        )

        db.add_all([home_istanbul, home_antalya, home_cappadocia, home_ankara, home_izmir, home_cappadocia_2])
        db.commit()
        print(f"   ✅ home_istanbul.id={home_istanbul.id}")
        print(f"   ✅ home_antalya.id={home_antalya.id} (HIGH compat vs Rama)")
        print(f"   ✅ home_cappadocia.id={home_cappadocia.id} (MEDIUM compat vs Rama)")
        print(f"   ✅ home_ankara.id={home_ankara.id} (LOW compat vs Rama)")
        print(f"   ✅ home_izmir.id={home_izmir.id} (Rama favorite #1)")
        print(f"   ✅ home_cappadocia_2.id={home_cappadocia_2.id} (6km from Göreme)")

        # ─────────────────────────────────────────────────────────
        # 3. TRIP PREFERENCES (Rama — the main demo account)
        # ─────────────────────────────────────────────────────────
        print("\n🗺️  Setting Rama's TripPreference...")

        # Rama wants: Antalya, beach, 2 guests, Aug dates, lifestyle = Beach+Relaxing
        # This is engineered so:
        #   home_antalya (Beach, capacity 4, Antalya): score ~90-95%
        #   home_cappadocia (Mountain, capacity 2, Cappadocia): score ~55-65%
        #   home_ankara (City, capacity 2, Ankara): score < 40%
        trip_pref = TripPreference(
            user_id=rama.id,
            preferred_country="Turkey",
            preferred_city="Antalya",
            start_date=TODAY + timedelta(days=45),  # Aug 3
            end_date=TODAY + timedelta(days=59),    # Aug 17  (14-night trip)
            guests=2,
            lifestyle_tags=["Beach", "Relaxing", "Swimming", "Outdoor", "Sunset"]
        )
        db.add(trip_pref)
        db.commit()
        print("   ✅ TripPreference set: Antalya, 2 guests, Aug 3–17, tags=Beach/Relaxing/Swimming/Outdoor/Sunset")

        # ─────────────────────────────────────────────────────────
        # 4. SWAP REQUESTS
        # ─────────────────────────────────────────────────────────
        print("\n🔄 Creating swap requests...")

        # ── SWAP A: Pending (Can → Rama) — Rama receives request and can Accept/Decline in Pending tab
        swap_pending = SwapRequest(
            requester_id=can.id,
            host_id=rama.id,
            requester_home_id=home_ankara.id,
            host_home_id=home_istanbul.id,
            start_date=TODAY + timedelta(days=30),   # Jul 19
            end_date=TODAY + timedelta(days=37),      # Jul 26
            intro_message=(
                "Merhaba Rama! I'd love to visit Istanbul and explore Beşiktaş. "
                "My Ankara apartment is perfect for business or museum visits. "
                "Would you be interested in a swap next month?"
            ),
            status=SwapRequestStatus.PENDING
        )

        # ── SWAP B: Accepted UPCOMING (Zeynep ↔ Rama) — FUTURE dates, blocks homes
        # These dates lock home_cappadocia and home_istanbul for booking conflict demo
        swap_accepted_start = TODAY + timedelta(days=10)   # Jun 29
        swap_accepted_end   = TODAY + timedelta(days=17)   # Jul 6
        swap_accepted = SwapRequest(
            requester_id=zeynep.id,
            host_id=rama.id,
            requester_home_id=home_cappadocia.id,
            host_home_id=home_istanbul.id,
            start_date=swap_accepted_start,
            end_date=swap_accepted_end,
            intro_message=(
                "Merhaba Rama! I've always wanted to visit Istanbul's art galleries. "
                "My Göreme cave suite would give you an unforgettable Cappadocia experience!"
            ),
            status=SwapRequestStatus.ACCEPTED
        )

        # ── SWAP B2: Accepted ACTIVE (Ahmet ↔ Rama) — CURRENT dates
        # So the "Active" tab is populated!
        swap_active_start = TODAY - timedelta(days=2)
        swap_active_end   = TODAY + timedelta(days=5)
        swap_active = SwapRequest(
            requester_id=ahmet.id,
            host_id=rama.id,
            requester_home_id=home_antalya.id,
            host_home_id=home_istanbul.id,
            start_date=swap_active_start,
            end_date=swap_active_end,
            intro_message=(
                "Hi Rama! We are so excited for our swap this week! See you soon."
            ),
            status=SwapRequestStatus.ACCEPTED
        )

        # ── SWAP C: Completed (Rama ↔ Ahmet) — past swap, HAS a review
        swap_completed_with_review = SwapRequest(
            requester_id=rama.id,
            host_id=ahmet.id,
            requester_home_id=home_istanbul.id,
            host_home_id=home_antalya.id,
            start_date=TODAY - timedelta(days=60),   # Apr 20
            end_date=TODAY - timedelta(days=50),     # Apr 30
            intro_message=(
                "Hi Ahmet! We'd love to spend 10 days at your beautiful Antalya villa. "
                "I'll offer my Istanbul apartment in return — great location, Bosphorus views!"
            ),
            status=SwapRequestStatus.COMPLETED
        )

        # ── SWAP D: Completed (Zeynep ↔ Rama) — past swap, NO review yet
        swap_completed_no_review = SwapRequest(
            requester_id=zeynep.id,
            host_id=rama.id,
            requester_home_id=home_cappadocia.id,
            host_home_id=home_istanbul.id,
            start_date=TODAY - timedelta(days=30),   # May 20
            end_date=TODAY - timedelta(days=23),     # May 27
            intro_message=(
                "Hi Rama! I want to explore Istanbul's art galleries and Bosphorus. "
                "My Göreme cave suite is quite unique — hot air balloons fly right past your window!"
            ),
            status=SwapRequestStatus.COMPLETED
        )

        db.add_all([swap_pending, swap_accepted, swap_active, swap_completed_with_review, swap_completed_no_review])
        db.commit()
        print(f"   ✅ swap_pending.id={swap_pending.id} (Can→Rama, PENDING)")
        print(f"   ✅ swap_accepted.id={swap_accepted.id} (Zeynep↔Rama, ACCEPTED UPCOMING, Jun29–Jul6)")
        print(f"   ✅ swap_active.id={swap_active.id} (Ahmet↔Rama, ACCEPTED ACTIVE)")
        print(f"   ✅ swap_completed_review.id={swap_completed_with_review.id} (Rama↔Ahmet, COMPLETED+review)")
        print(f"   ✅ swap_completed_no_review.id={swap_completed_no_review.id} (Zeynep↔Rama, COMPLETED, no review)")

        # ─────────────────────────────────────────────────────────
        # 5. HOME BOOKINGS (lock dates for the accepted swap)
        # ─────────────────────────────────────────────────────────
        print("\n📅 Creating home bookings (date locks for accepted swap)...")

        booking_cappadocia = HomeBooking(
            home_id=home_cappadocia.id,
            start_date=swap_accepted_start,
            end_date=swap_accepted_end
        )
        booking_istanbul = HomeBooking(
            home_id=home_istanbul.id,
            start_date=swap_accepted_start,
            end_date=swap_accepted_end
        )
        db.add_all([booking_cappadocia, booking_istanbul])
        db.commit()
        print(f"   ✅ home_cappadocia LOCKED Jun29–Jul6 (booking_id={booking_cappadocia.id})")
        print(f"   ✅ home_istanbul LOCKED Jun29–Jul6 (booking_id={booking_istanbul.id})")
        print("   ℹ️  Booking Conflict Demo: Any request for home_cappadocia or home_istanbul")
        print(f"      overlapping Jun29–Jul6 will get 409 Conflict.")

        # ─────────────────────────────────────────────────────────
        # 6. REVIEWS
        # ─────────────────────────────────────────────────────────
        print("\n⭐ Creating reviews...")

        # Ahmet reviews Rama's Istanbul apartment (for the completed swap)
        review_ahmet_on_istanbul = Review(
            swap_request_id=swap_completed_with_review.id,
            reviewer_id=ahmet.id,
            reviewee_id=rama.id,
            home_id=home_istanbul.id,
            rating=5,
            comment=(
                "Absolutely stunning! The Bosphorus view from the balcony was breathtaking, "
                "especially at sunset. Rama's apartment was spotlessly clean, "
                "well-equipped, and the location in Beşiktaş was perfect — "
                "ferries, restaurants, and markets within walking distance. "
                "Highly recommended for anyone visiting Istanbul!"
            )
        )
        db.add(review_ahmet_on_istanbul)
        db.commit()

        # Update home_istanbul rating stats
        home_istanbul.total_reviews = 1
        home_istanbul.average_rating = 5.0
        db.commit()

        print(f"   ✅ review_id={review_ahmet_on_istanbul.id}: Ahmet→Istanbul (5★)")
        print(f"   ℹ️  swap_completed_no_review (id={swap_completed_no_review.id}) has NO review yet — demo can submit one")

        # ─────────────────────────────────────────────────────────
        # 7. FAVORITES
        # ─────────────────────────────────────────────────────────
        print("\n❤️  Creating Rama's favorites...")

        fav_antalya = Favorite(user_id=rama.id, home_id=home_antalya.id)
        fav_izmir   = Favorite(user_id=rama.id, home_id=home_izmir.id)
        db.add_all([fav_antalya, fav_izmir])
        db.commit()
        print(f"   ✅ Rama favorites: home_antalya (id={home_antalya.id}), home_izmir (id={home_izmir.id})")

        # ─────────────────────────────────────────────────────────
        # 8. MESSAGES (Rama ↔ Ahmet conversation)
        # ─────────────────────────────────────────────────────────
        print("\n💬 Creating message conversation (Rama ↔ Ahmet)...")

        now = datetime.now(timezone.utc)

        messages = [
            Message(
                sender_id=ahmet.id,
                receiver_id=rama.id,
                content="Merhaba Rama! I saw your Istanbul apartment listing — the Bosphorus view looks absolutely incredible!",
            ),
            Message(
                sender_id=rama.id,
                receiver_id=ahmet.id,
                content="Teşekkürler Ahmet! Yes, especially at golden hour the view is magical. I saw your Antalya villa too — that pool looks amazing!",
            ),
            Message(
                sender_id=ahmet.id,
                receiver_id=rama.id,
                content="It really is. The sea is right there, you can hear the waves from the pool. When are you thinking of traveling?",
            ),
            Message(
                sender_id=rama.id,
                receiver_id=ahmet.id,
                content="I was thinking early August — maybe August 3rd to 17th. Would those dates work for your villa?",
            ),
            Message(
                sender_id=ahmet.id,
                receiver_id=rama.id,
                content="Those dates are perfect! The villa is completely available. Summer is the best time — the sea is warmest in August.",
            ),
            Message(
                sender_id=rama.id,
                receiver_id=ahmet.id,
                content="That's great news! I'll send a formal swap request. Looking forward to experiencing Antalya through a local's eyes!",
            ),
            Message(
                sender_id=ahmet.id,
                receiver_id=rama.id,
                content="And I can't wait to explore Istanbul! Any restaurant recommendations near Beşiktaş?",
            ),
            Message(
                sender_id=rama.id,
                receiver_id=ahmet.id,
                content="Absolutely — you must try Karaköy Lokantası and the fish sandwich stands at the Bosphorus bridge. Unforgettable!",
            ),
        ]

        db.add_all(messages)
        db.commit()
        print(f"   ✅ {len(messages)} messages created in Rama↔Ahmet conversation")

        # ─────────────────────────────────────────────────────────
        # 9. NOTIFICATIONS
        # ─────────────────────────────────────────────────────────
        print("\n🔔 Creating notifications...")

        notifications = [
            # Rama: swap accepted (from Zeynep–Can swap, Rama sees in activity)
            Notification(
                user_id=rama.id,
                message="Your swap request with Ahmet has been accepted! Check your upcoming swaps.",
                type="swap_accepted",
                is_read=False
            ),
            Notification(
                user_id=rama.id,
                message="Ahmet Yılmaz sent you a new message: 'Those dates are perfect!'",
                type="new_message",
                is_read=False
            ),
            Notification(
                user_id=rama.id,
                message="Ahmet Yılmaz left a 5-star review for your Istanbul apartment!",
                type="new_review",
                is_read=True
            ),
            # Can: pending swap request from Ahmet
            Notification(
                user_id=can.id,
                message="You have a new home swap request from Ahmet Yılmaz!",
                type="swap_request",
                is_read=False
            ),
            Notification(
                user_id=can.id,
                message="Your swap with Zeynep Kaya has been confirmed for Jun 29 – Jul 6!",
                type="swap_accepted",
                is_read=False
            ),
            # Ahmet: past accepted
            Notification(
                user_id=ahmet.id,
                message="Your swap with Rama Matar for Istanbul is complete. Leave a review!",
                type="swap_completed",
                is_read=True
            ),
            # Zeynep: accepted swap with Can
            Notification(
                user_id=zeynep.id,
                message="Great news! Can Demir accepted your swap request. Heading to Ankara Jun 29!",
                type="swap_accepted",
                is_read=False
            ),
        ]

        db.add_all(notifications)
        db.commit()
        print(f"   ✅ {len(notifications)} notifications created ({sum(1 for n in notifications if not n.is_read)} unread)")

        # ─────────────────────────────────────────────────────────
        # 10. SUMMARY REPORT
        # ─────────────────────────────────────────────────────────
        print("\n" + "="*60)
        print("🎓 GRADUATION DEMO SEED — COMPLETE")
        print("="*60)

        print("\n👤 USERS:")
        print(f"   Rama  (main demo) │ rama@swapscout.com    │ pass: demo1234 │ id={rama.id}")
        print(f"   Ahmet             │ ahmet@swapscout.com   │ pass: demo1234 │ id={ahmet.id}")
        print(f"   Zeynep            │ zeynep@swapscout.com  │ pass: demo1234 │ id={zeynep.id}")
        print(f"   Can               │ can@swapscout.com     │ pass: demo1234 │ id={can.id}")

        print("\n🏠 HOMES:")
        print(f"   id={home_istanbul.id}  │ Istanbul apartment    │ Rama    │ City/Apt     │ cap=2")
        print(f"   id={home_antalya.id}  │ Antalya villa         │ Ahmet   │ Beach/Villa  │ cap=4  ← HIGH compat (90-95%)")
        print(f"   id={home_cappadocia.id}  │ Cappadocia cave       │ Zeynep  │ Mountain/Cot │ cap=2  ← MEDIUM compat (55-65%)")
        print(f"   id={home_ankara.id}  │ Ankara apartment      │ Can     │ City/Apt     │ cap=2  ← LOW compat (<40%)")
        print(f"   id={home_izmir.id}  │ Izmir stone house     │ Ahmet   │ Beach/Cot    │ cap=4  (Rama favorite)")
        print(f"   id={home_cappadocia_2.id}  │ Uçhisar suite         │ Zeynep  │ Mountain/Cot │ cap=2  (6km from Göreme)")

        print("\n🔄 SWAP REQUESTS:")
        print(f"   id={swap_pending.id} │ PENDING   │ Can→Rama       │ Ankara↔Istanbul  │ Jul 19–26")
        print(f"   id={swap_accepted.id} │ UPCOMING  │ Zeynep↔Rama    │ Cappadocia↔Istanb│ Jun 29–Jul 6 (dates LOCKED)")
        print(f"   id={swap_active.id} │ ACTIVE    │ Ahmet↔Rama     │ Antalya↔Istanbul │ ACTIVE NOW")
        print(f"   id={swap_completed_with_review.id} │ COMPLETED │ Rama↔Ahmet     │ Istanbul↔Antalya │ Apr 20–30 (HAS review)")
        print(f"   id={swap_completed_no_review.id} │ COMPLETED │ Zeynep↔Rama    │ Cappadocia↔Istanb│ May 20–27 (NO review yet)")

        print("\n📅 BOOKING LOCKS:")
        print(f"   home_cappadocia (id={home_cappadocia.id}) BLOCKED Jun 29–Jul 6")
        print(f"   home_istanbul (id={home_istanbul.id}) BLOCKED Jun 29–Jul 6")
        print("   → Any new swap request touching these homes/dates = 409 Conflict")

        print("\n⭐ REVIEWS:")
        print(f"   review_id={review_ahmet_on_istanbul.id}: Ahmet→Istanbul apt, 5★, swap_id={swap_completed_with_review.id}")
        print(f"   swap_id={swap_completed_no_review.id}: NO review — demo can submit during presentation")

        print("\n❤️  FAVORITES (Rama):")
        print(f"   home_antalya (id={home_antalya.id}), home_izmir (id={home_izmir.id})")

        print("\n💬 MESSAGES: 8 messages in Rama↔Ahmet thread")

        print("\n🔔 NOTIFICATIONS:")
        print(f"   Rama:  2 unread (swap_accepted + new_message)")
        print(f"   Can:   2 unread (swap_request + swap_accepted)")
        print(f"   Zeynep: 1 unread (swap_accepted)")

        print("\n🗺️  GEOSPATIAL RADIUS DEMO (center: Göreme 38.6431, 34.8308):")
        print(f"   50km radius → finds BOTH Cappadocia homes (id={home_cappadocia.id} at 0km, id={home_cappadocia_2.id} at ~6km)")
        print(f"   20km radius → finds BOTH Cappadocia homes (6km < 20km)")
        print(f"   5km  radius → finds ONLY home_cappadocia (id={home_cappadocia.id}, 0km); Uçhisar ~6km excluded")

        print("\n🤖 AI MATCHING (Rama's prefs: Beach, Relaxing, Swimming, Outdoor, Sunset):")
        print(f"   home_antalya (id={home_antalya.id}):    Beach villa, pool, garden, sea → expected score 90-95%")
        print(f"   home_cappadocia (id={home_cappadocia.id}): Mountain cave, terrace, sunset → expected score 55-65%")
        print(f"   home_ankara (id={home_ankara.id}):   City apt, no beach, no pool   → expected score < 40%")

        print("\n🎯 GEMINI VISION DEMO:")
        print(f"   home_antalya image 1: pool + outdoor seating + garden")
        print(f"   home_izmir image 1:   outdoor kitchen + garden + stone architecture")

        print("\n" + "="*60)
        print("✅ Ready for graduation demo. Login as rama@swapscout.com / demo1234")
        print("="*60)

    except Exception as e:
        db.rollback()
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
