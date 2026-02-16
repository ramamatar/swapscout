from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Set
import os
import json
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

router = APIRouter(prefix="/ai", tags=["AI"])

# Configure Gemini
api_key = os.getenv("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)
else:
    print("WARNING: GEMINI_API_KEY not found in environment variables.")

class AISuggestionRequest(BaseModel):
    prompt: str
    tags: Set[str]

@router.post("/suggest-destination")
async def suggest_destination(request: AISuggestionRequest):
    """
    Get AI-powered destination suggestions using Google Gemini.
    """
    if not api_key:
         raise HTTPException(status_code=500, detail="Server configuration error: AI API key missing.")

    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        
        prompt_text = (
            f"You are a travel assistant. Suggest 3 travel destinations based on this user description: '{request.prompt}' "
            f"and these preferred tags: {', '.join(request.tags)}. "
            "Return the answer ONLY as a valid JSON list of objects. "
            "Each object must have these exact keys: 'city', 'country', 'description', 'matchReason'. "
            "Do not include any markdown formatting like ```json or backticks. Just the raw JSON string."
        )

        response = model.generate_content(prompt_text)
        
        # Clean up response text if necessary
        cleaned_text = response.text.strip()
        if cleaned_text.startswith("```json"):
            cleaned_text = cleaned_text[7:]
        if cleaned_text.endswith("```"):
            cleaned_text = cleaned_text[:-3]
        cleaned_text = cleaned_text.strip()

        suggestions = json.loads(cleaned_text)
        return {"suggestions": suggestions}

    except Exception as e:
        print(f"AI Error: {e}")
        raise HTTPException(status_code=500, detail=f"AI Service Error: {str(e)}")
