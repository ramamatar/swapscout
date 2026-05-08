import os
import json
import google.generativeai as genai
from models import User, Home, TripPreference

# Configure Gemini once on import
api_key = os.getenv("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

def _build_user_bio(user: User) -> str:
    parts = []
    if user.name:
        parts.append(f"Name: {user.name}")
    if user.city and user.country:
        parts.append(f"Location: {user.city}, {user.country}")
    elif user.city or user.country:
        parts.append(f"Location: {user.city or user.country}")
    
    synthesized = " | ".join(parts) if parts else "Unknown traveler profile."
    
    if user.bio:
        return f"{synthesized}\nAbout Me: {user.bio}"
    return synthesized

def _build_travel_style(pref: TripPreference) -> str:
    if not pref:
        return "Not specified."
    parts = []
    if pref.preferred_city and pref.preferred_country:
        parts.append(f"Looking to visit: {pref.preferred_city}, {pref.preferred_country}")
    if pref.guests:
        parts.append(f"Guests: {pref.guests}")
    if pref.start_date and pref.end_date:
        parts.append(f"Dates: {pref.start_date} to {pref.end_date}")
    return " | ".join(parts) if parts else "Not specified."

def generate_compatibility(traveler: User, host: User, home: Home, trip_pref: TripPreference) -> dict:
    """
    Calls the Gemini SDK to evaluate compatibility between a traveler and a host/home.
    Returns:
        dict: {"compatibility_score": int, "match_explanation": str}
    """
    if not api_key:
        print("WARNING: GEMINI_API_KEY Missing. Simulating random match score.")
        import random
        return {
            "compatibility_score": random.randint(50, 100),
            "match_explanation": f"{traveler.name or 'Traveler'} and {host.name or 'Host'} seem to have a good potential fit."
        }

    user_a_bio = _build_user_bio(traveler)
    user_a_tags = traveler.lifestyle_tags or "None"
    user_a_travel_style = _build_travel_style(trip_pref)

    user_b_bio = _build_user_bio(host)
    if host.lifestyle_tags:
        user_b_bio += f" | Host Tags: {host.lifestyle_tags}"

    home_b_description = home.description or "No description provided."
    home_b_amenities = home.amenities or "None"

    prompt = f"""You are an expert travel matchmaker and compatibility algorithm for a home-exchange platform. Your task is to analyze the compatibility between a Traveler and a Host's Home.

Traveler Profile:

Bio: {user_a_bio}

Lifestyle Tags: {user_a_tags}

Preferred Travel Style: {user_a_travel_style}

Host & Home Profile:

Host Bio: {user_b_bio}

Home Description: {home_b_description}

Home Amenities: {home_b_amenities}

Instructions:

Compare the Traveler's preferences and lifestyle against what the Host's home offers.

Calculate a 'Compatibility Score' from 0 to 100 based on shared interests, complementary lifestyles, and amenity matches.

Write a single, concise 'Match Explanation' (maximum 2 sentences) explaining why they are a good fit or where they differ.

Output Format:
You MUST return your response as a valid, raw JSON object. Do not use Markdown formatting, do not use ```json wrappers, and do not add any conversational text.

Strict JSON Schema:
{{
"compatibility_score": integer,
"match_explanation": "string"
}}"""

    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        
        cleaned_text = response.text.strip()
        if cleaned_text.startswith("```json"):
            cleaned_text = cleaned_text[7:]
        if cleaned_text.endswith("```"):
            cleaned_text = cleaned_text[:-3]
        cleaned_text = cleaned_text.strip()

        result = json.loads(cleaned_text)
        
        # Ensure fallback defaults if AI didn't follow perfectly
        score = int(result.get("compatibility_score", 75))
        explanation = result.get("match_explanation", "Good potential match.")
        
        return {
            "compatibility_score": score,
            "match_explanation": explanation
        }
        
    except Exception as e:
        print(f"Error calling Gemini for matchmaking: {e}")
        return {
            "compatibility_score": 75,
            "match_explanation": "We couldn't generate a compatibility score at this time, but this looks like a good match."
        }
