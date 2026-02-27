from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import analyze

app = FastAPI(
    title="AI Image Analyzer API",
    description="An API that uses Google Gemini Vision to analyze images.",
    version="1.0.0"
)

# Add CORS middleware to allow requests from the Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Include the router for the /analyze endpoint
app.include_router(analyze.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to the AI Image Analyzer API"}
