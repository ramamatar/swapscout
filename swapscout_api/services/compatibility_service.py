import os
import json
import logging
import google.generativeai as genai
from pydantic import BaseModel
from typing import List, Optional, Tuple
from datetime import date

# Configure Gemini
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

logger = logging.getLogger(__name__)

# --- Strict DTO Models for Input ---

class UserRequest(BaseModel):
    requested_guest_count: int
    requested_dates: Tuple[date, date]
    requested_amenities: List[str]
    requested_radius: Optional[float] = None
    user_bio_preferences: List[str]

class CurrentListing(BaseModel):
    listing_id: int
    listing_capacity: int
    listing_available_dates: Tuple[date, date]
    listing_amenities: List[str]
    listing_distance: Optional[float] = None
    listing_environment_traits: List[str]


# --- Strictly Typed Output Models ---

class DateMatch(BaseModel):
    score: int
    matched: bool
    details: str

class CapacityMatch(BaseModel):
    score: int
    requested_guest_count: int
    listing_capacity: int

class AmenitiesMatch(BaseModel):
    score: int
    matched_amenities: List[str]
    missing_amenities: List[str]

class BioLifestyleMatch(BaseModel):
    score: int
    matched_traits: List[str]
    conflicting_traits: List[str]

class ListingDetails(BaseModel):
    listing_amenities: List[str]
    listing_environment_traits: List[str]

class CompatibilityFactors(BaseModel):
    date_match: DateMatch
    guest_capacity: CapacityMatch
    amenities: AmenitiesMatch
    bio_lifestyle: BioLifestyleMatch
    listing_details: ListingDetails

class CompatibilityResult(BaseModel):
    listing_id: int
    total_score: int
    factors: CompatibilityFactors


def dates_overlap(start1: date, end1: date, start2: date, end2: date) -> bool:
    return start1 <= end2 and start2 <= end1

def calculateCompatibility(userRequest: UserRequest, currentListing: CurrentListing) -> CompatibilityResult:
    # 1. Date Match (30%)
    if dates_overlap(
        currentListing.listing_available_dates[0], currentListing.listing_available_dates[1],
        userRequest.requested_dates[0], userRequest.requested_dates[1]
    ):
        date_score = 100
    else:
        date_score = 0

    date_match = DateMatch(
        score=date_score,
        matched=date_score > 0,
        details="Requested dates align with listing availability." if date_score > 0 else "Dates do not overlap with listing availability."
    )

    # 2. Guest Capacity (20%)
    capacity_score = 100 if currentListing.listing_capacity >= userRequest.requested_guest_count else 0
    guest_capacity = CapacityMatch(
        score=capacity_score,
        requested_guest_count=userRequest.requested_guest_count,
        listing_capacity=currentListing.listing_capacity
    )

    # 3. Amenities Match (25%)
    matched_amenities = list(set(currentListing.listing_amenities).intersection(set(userRequest.requested_amenities)))
    missing_amenities = list(set(userRequest.requested_amenities) - set(currentListing.listing_amenities))
    
    amenities_score = 100
    if userRequest.requested_amenities:
        amenities_score = int((len(matched_amenities) / len(userRequest.requested_amenities)) * 100)

    amenities = AmenitiesMatch(
        score=amenities_score,
        matched_amenities=matched_amenities,
        missing_amenities=missing_amenities
    )

    # 4. Bio / Lifestyle Match (25%)
    matched_traits = []
    conflicting_traits = []
    
    for tag in userRequest.user_bio_preferences:
        tag_lower = tag.lower()
        if any(tag_lower in trait.lower() for trait in currentListing.listing_environment_traits):
            matched_traits.append(tag)
        else:
            conflicting_traits.append(tag)
            
    bio_score = 100
    if userRequest.user_bio_preferences:
        bio_score = int((len(matched_traits) / len(userRequest.user_bio_preferences)) * 100)

    bio_lifestyle = BioLifestyleMatch(
        score=bio_score,
        matched_traits=matched_traits,
        conflicting_traits=conflicting_traits
    )

    # 5. Listing Details for LLM isolation
    listing_details = ListingDetails(
        listing_amenities=currentListing.listing_amenities,
        listing_environment_traits=currentListing.listing_environment_traits
    )

    factors = CompatibilityFactors(
        date_match=date_match,
        guest_capacity=guest_capacity,
        amenities=amenities,
        bio_lifestyle=bio_lifestyle,
        listing_details=listing_details
    )

    # Total Score Calculation
    base_score = int(
        (date_score * 0.30) + 
        (capacity_score * 0.20) + 
        (amenities_score * 0.25) + 
        (bio_score * 0.25)
    )
    
    bonus = min(5, len(currentListing.listing_amenities)) + min(5, (currentListing.listing_capacity - userRequest.requested_guest_count))
    total_score = min(100, int(base_score * 0.90 + bonus))

    # MANDATORY DEBUG LOGGING
    print(json.dumps({
        "listingId": currentListing.listing_id,
        "requested_guest_count": userRequest.requested_guest_count,
        "listing_capacity": currentListing.listing_capacity,
        "total_score": total_score
    }))

    return CompatibilityResult(
        listing_id=currentListing.listing_id,
        total_score=total_score,
        factors=factors
    )

def _build_deterministic_explanation(compatibility: CompatibilityResult) -> str:
    """Build a factual, deterministic explanation from structured compatibility data."""
    parts = []
    f = compatibility.factors

    if f.date_match.matched:
        parts.append("Dates align with listing availability.")
    else:
        parts.append("Dates do not overlap with listing availability.")

    gc = f.guest_capacity
    guest_word = "guest" if gc.requested_guest_count == 1 else "guests"
    if gc.score == 100:
        parts.append(f"Accommodates all {gc.requested_guest_count} requested {guest_word}.")
    else:
        parts.append(f"Cannot accommodate {gc.requested_guest_count} requested {guest_word} (capacity: {gc.listing_capacity}).")

    if f.amenities.matched_amenities:
        parts.append(f"Available: {', '.join(f.amenities.matched_amenities)}.")
    if f.amenities.missing_amenities:
        parts.append(f"Missing: {', '.join(f.amenities.missing_amenities)}.")

    if f.bio_lifestyle.matched_traits:
        parts.append(f"Lifestyle match: {', '.join(f.bio_lifestyle.matched_traits)}.")
    if f.bio_lifestyle.conflicting_traits:
        parts.append(f"Lifestyle not matched: {', '.join(f.bio_lifestyle.conflicting_traits)}.")

    return " ".join(parts)

def generateExplanation(compatibility: CompatibilityResult) -> str:
    # Build the scoring JSON but exclude verbose listing_details to keep prompt small
    compat_data = compatibility.model_dump()
    # Remove raw listing details (descriptions can be huge and cause slow LLM responses)
    if 'factors' in compat_data and 'listing_details' in compat_data['factors']:
        details = compat_data['factors']['listing_details']
        # Keep only short traits, drop full descriptions
        if 'listing_environment_traits' in details:
            details['listing_environment_traits'] = [
                t[:80] for t in details['listing_environment_traits'] if len(t) < 200
            ]

    import json as _json
    scoring_json = _json.dumps(compat_data, indent=2, default=str)

    prompt = f"""
You are an AI assistant that writes concise, factual explanations for a housing compatibility system.
You MUST ONLY explain the provided structured scoring JSON.

STRICT RULES:
- NEVER use fallback text
- NEVER invent information
- NEVER hallucinate missing amenities
- NEVER infer missing data
- NEVER speculate
- NEVER mention unavailable amenities unless listed in missing_amenities
- NEVER mention capacities not present in JSON
- NEVER mention date incompatibilities for already-filtered results
- NEVER generate subjective statements
- NEVER describe houses beyond provided data
- NEVER use generic marketing language
- NEVER calculate scores yourself
- NEVER generate raw JSON, only human-readable text.
- NEVER use ambiguous names like "guests", "capacity", "people", or "count".
- ALWAYS use the exact `requested_guest_count` from the JSON when mentioning guest accommodation. 
  For example, if `requested_guest_count` is 2, say "Accommodates all 2 requested guests." NEVER say "Accommodates 1 guests" unless `requested_guest_count` is 1.

If a field does not exist, do not mention it.

Format your explanation as a short paragraph (2-3 sentences max).
Example: "This listing strongly matches your practical requirements. Dates align with availability and it accommodates all 2 requested guests. Wi-Fi and kitchen are available, though parking is missing."

Structured Scoring JSON:
{scoring_json}
"""

    try:
        import concurrent.futures
        model = genai.GenerativeModel('gemini-2.5-flash')
        
        # Run with 15-second timeout to prevent hanging
        with concurrent.futures.ThreadPoolExecutor() as executor:
            future = executor.submit(model.generate_content, prompt)
            try:
                response = future.result(timeout=15)
                text = response.text.strip()
                if not text:
                    print("Gemini returned empty text, using deterministic fallback")
                    return _build_deterministic_explanation(compatibility)
                return text
            except concurrent.futures.TimeoutError:
                print("Gemini API timed out after 15s, using deterministic fallback")
                future.cancel()
                return _build_deterministic_explanation(compatibility)
    except Exception as e:
        print(f"Error generating AI explanation: {e}")
        return _build_deterministic_explanation(compatibility)

