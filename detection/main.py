import os
import json
from io import BytesIO
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from PIL import Image
import google.generativeai as genai

# Load environment variables from .env file
load_dotenv()

# Configure Gemini API
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY environment variable is missing. Please check your .env file.")

genai.configure(api_key=api_key)

# Initialize FastAPI app
app = FastAPI(
    title="Pothole Detection API",
    description="Microservice for detecting and classifying potholes using Gemini 1.5 Flash",
    version="1.0.0"
)

# Enable CORS for all origins so frontend teammates don't get blocked
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the Gemini model - using models/ prefix format
model = genai.GenerativeModel('models/gemini-2.5-flash')

# The highly specific system prompt
SYSTEM_PROMPT = """
You are an AI computer vision assistant for road maintenance.
Analyze the provided image.
Determine if a pothole is present.
If present, classify the size as "Small", "Medium", or "Large" based on its relative scale to the road/surroundings. If no pothole is present, size should be "None".

Respond strictly in JSON format with the following structure:
{
  "has_pothole": boolean,
  "size": "Small" | "Medium" | "Large" | "None",
  "confidence": float
}
"""

@app.post("/api/detect-pothole")
async def detect_pothole(file: UploadFile = File(...)):
    # 1. Error Handling: Validate that the uploaded file is an image
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file type '{file.content_type}'. Please upload an image."
        )
    
    try:
        # 2. Read the image bytes and convert to PIL Image
        image_data = await file.read()
        image = Image.open(BytesIO(image_data))
        
        # 3. Call Gemini API with strict JSON enforcement
        response = model.generate_content(
            [SYSTEM_PROMPT, image],
            generation_config=genai.types.GenerationConfig(
                response_mime_type="application/json",
            )
        )
        
        # 5. Parse and return the JSON response
        result = json.loads(response.text)
        return result
        
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=500, 
            detail="Failed to parse the AI response into valid JSON."
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail=f"An error occurred during AI processing: {str(e)}"
        )