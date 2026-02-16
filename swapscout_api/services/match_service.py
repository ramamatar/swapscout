from sqlalchemy.orm import Session
from models import Home, TripPreference
from datetime import date
from models import Match

def dates_overlap(start1, end1, start2, end2):
    print(
        "DATES 1:", start1, end1,
        "DATES 2:", start2, end2
    )
    return start1 <= end2 and start2 <= end1


def find_matches(db: Session, preference: TripPreference, user_id: int):
    homes = db.query(Home).filter(
    Home.country.ilike(preference.preferred_country),
    Home.city.ilike(preference.preferred_city),
    Home.capacity >= preference.guests,
    Home.owner_id != user_id
).all()


    matches = []

    for home in homes:
        if not dates_overlap(
            home.available_from,
            home.available_to,
            preference.start_date,
            preference.end_date
        ):
            continue

        score = 0.0

        if home.amenities and preference.lifestyle_tags:
            overlap = set(home.amenities).intersection(
                set(preference.lifestyle_tags)
            )
            score += len(overlap) * 10

        matches.append({
            "home_id": home.id,
            "title": home.title,
            "country": home.country,
            "city": home.city,
            "score": score
        })

    matches.sort(key=lambda x: x["score"], reverse=True)

    return matches


def users_are_matched(db: Session, user1_id: int, user2_id: int) -> bool:
    return (
        db.query(Match)
        .filter(
            ((Match.user_id == user1_id) & (Match.matched_user_id == user2_id)) |
            ((Match.user_id == user2_id) & (Match.matched_user_id == user1_id))
        )
        .first()
        is not None
    )

def get_or_create_match(db, user1_id: int, user2_id: int):
    a, b = sorted([user1_id, user2_id])

    match = db.query(Match).filter(
        Match.user_a_id == a,
        Match.user_b_id == b
    ).first()

    if match:
        return match

    match = Match(
        user_a_id=a,
        user_b_id=b,
        status="pending"
    )

    db.add(match)
    db.commit()
    db.refresh(match)
    return match
