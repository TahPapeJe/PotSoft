from fastapi import APIRouter, File, UploadFile, HTTPException
from services.gemini_service import analyze_image
from schemas.response_model import AnalysisResponse
import base64
import os

router = APIRouter()

ALLOWED_IMAGE_EXTENSIONS = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.heic', '.avif'
}

@router.post("/analyze", response_model=AnalysisResponse)
async def analyze(file: UploadFile = File(...)):
    """
    Endpoint to upload an image and get an analysis from the Gemini Vision API.
    """
    content_type = file.content_type or ""
    _, ext = os.path.splitext((file.filename or "").lower())
    is_image = content_type.startswith('image/') or ext in ALLOWED_IMAGE_EXTENSIONS

    if not is_image:
        raise HTTPException(status_code=400, detail="File provided is not an image.")

    try:
        contents = await file.read()
        image_base64 = base64.b64encode(contents).decode("utf-8")
        
        mime_type = file.content_type if file.content_type and file.content_type.startswith('image/') else f"image/{os.path.splitext(file.filename or '')[1].lstrip('.')}"
        analysis_result = analyze_image(image_base64, mime_type)
        
        if not analysis_result.success:
            raise HTTPException(status_code=500, detail=analysis_result.error)
            
        return analysis_result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred during analysis: {str(e)}")
