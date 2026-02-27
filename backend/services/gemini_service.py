import os
import google.generativeai as genai
from dotenv import load_dotenv
import base64
from schemas.response_model import AnalysisResponse

# Explicitly load .env from the backend directory
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

# Configure the Gemini API key
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

prompts = "Return ONLY valid JSON. Do not include explanations outside JSON. Use this structure:" \
"{isPothole: true, sizeCategory: 'Small',jurisdiction: 'JKR Perlis', estimatedDurationtoRepair: '4 hours'}" \
"Jurisdiction is based on latitude and longitude that is given by the user."
def analyze_image(image_base64: str, mime_type: str = "image/jpeg") -> AnalysisResponse:
    """
    Sends the image to the Gemini Vision API for analysis.
    """
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        
        # The Gemini API expects a specific format for image data.
        # We need to strip the metadata from the base64 string.
        image_parts = [
            {
                "mime_type": mime_type,
                "data": image_base64
            }
        ]
        
        prompt = prompts
        
        response = model.generate_content([prompt, image_parts[0]])
        
        if response.text:
            return AnalysisResponse(success=True, analysis=response.text)
        else:
            return AnalysisResponse(success=False, error="Could not analyze the image.")

    except Exception as e:
        return AnalysisResponse(success=False, error=f"An error occurred: {str(e)}")
