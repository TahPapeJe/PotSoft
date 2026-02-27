from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import analyze
from routes import reports

app = FastAPI(
    title="PotSoft API",
    description="Pothole detection & reporting API powered by Gemini Vision.",
    version="1.0.0",
)

# Add CORS middleware to allow requests from the Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins (restrict in production)
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Include routers
app.include_router(analyze.router)
app.include_router(reports.router)


@app.get("/")
def read_root():
    return {"message": "Welcome to the PotSoft API"}
