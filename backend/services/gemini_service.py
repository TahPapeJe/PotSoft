import os
import json
import re
import google.generativeai as genai
from dotenv import load_dotenv
import base64
from schemas.response_model import AnalysisResponse

# Explicitly load .env from the backend directory
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

# Configure the Gemini API key
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

ANALYSIS_PROMPT = """Analyse this road image and respond with ONLY a valid JSON object (no markdown, no code fences, no extra text):
{{
  "is_pothole": true or false,
  "size_category": "Small" | "Medium" | "Large",
  "priority_color": "Green" | "Yellow" | "Red",
  "estimated_duration": "4 hours" | "1 day" | "3 days",
  "jurisdiction": "<local authority name>"
}}

Rules:
- is_pothole: true only if a pothole is clearly visible in the image
- size_category: Small (<20cm), Medium (20-50cm), Large (>50cm)
- priority_color: Green = Small, Yellow = Medium, Red = Large
- estimated_duration: "4 hours" for Small, "1 day" for Medium, "3 days" for Large
- jurisdiction: Determine the responsible Malaysian local authority based on the GPS coordinates provided: lat={lat}, long={lng}. Use the format like "JKR Perlis", "MBPP George Town", "DBKL Kuala Lumpur", etc.
"""


def parse_gemini_response(raw_text: str) -> dict:
    """
    Parse the raw Gemini response text into a structured dict.
    Strips markdown fences and extracts JSON.
    Returns sensible defaults if parsing fails.
    """
    defaults = {
        "is_pothole": False,
        "size_category": "Small",
        "priority_color": "Green",
        "estimated_duration": "4 hours",
        "jurisdiction": "Unknown",
    }

    try:
        # Strip markdown code fences if present
        cleaned = raw_text.strip()
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        # Validate and normalise fields
        result = {}
        result["is_pothole"] = bool(parsed.get("is_pothole", False))
        result["size_category"] = parsed.get("size_category", "Small")
        if result["size_category"] not in ("Small", "Medium", "Large"):
            result["size_category"] = "Small"

        result["priority_color"] = parsed.get("priority_color", "Green")
        if result["priority_color"] not in ("Green", "Yellow", "Red"):
            result["priority_color"] = "Green"

        result["estimated_duration"] = parsed.get("estimated_duration", "4 hours")
        result["jurisdiction"] = parsed.get("jurisdiction", "Unknown")

        return result
    except (json.JSONDecodeError, AttributeError, TypeError):
        return defaults


def analyze_image(
    image_base64: str, mime_type: str = "image/jpeg", lat: float = 0.0, lng: float = 0.0
) -> AnalysisResponse:
    """
    Sends the image to the Gemini Vision API for analysis.
    Returns an AnalysisResponse with the raw text in `analysis`.
    """
    try:
        model = genai.GenerativeModel("gemini-2.5-flash")

        image_parts = [{"mime_type": mime_type, "data": image_base64}]

        prompt = ANALYSIS_PROMPT.format(lat=lat, lng=lng)

        response = model.generate_content([prompt, image_parts[0]])

        if response.text:
            return AnalysisResponse(success=True, analysis=response.text)
        else:
            return AnalysisResponse(success=False, error="Could not analyze the image.")

    except Exception as e:
        return AnalysisResponse(success=False, error=f"An error occurred: {str(e)}")
