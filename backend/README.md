# PotSoft Backend

FastAPI server that handles pothole image analysis via Google Gemini Vision, stores reports in memory, and resolves GPS coordinates to Malaysian local authorities.

---

## Prerequisites

- Python 3.10 or later
- A Google Gemini API key ([get one here](https://aistudio.google.com/app/apikey))

## Setup

```bash
cd backend
pip install -r requirements.txt
```

Create a `.env` file in this directory:

```
GEMINI_API_KEY=your_key_here
```

## Running

```bash
uvicorn main:app --reload
```

Server starts at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

## API Endpoints

### GET /api/reports

Returns all pothole reports as a JSON array.

**Response:** `200 OK`

```json
[
  {
    "id": "pg01",
    "user_lat": 5.4141,
    "user_long": 100.3288,
    "image_file": "data:image/jpeg;base64,...",
    "timestamp": "2026-02-27T10:00:00+00:00",
    "is_pothole": true,
    "size_category": "Large",
    "priority_color": "Red",
    "jurisdiction": "MBPP George Town",
    "estimated_duration": "3 days",
    "status": "Reported"
  }
]
```

### POST /api/reports

Submit a new pothole report. Accepts multipart form data.

**Form fields:**

| Field   | Type  | Description          |
| ------- | ----- | -------------------- |
| `lat`   | float | Latitude             |
| `long`  | float | Longitude            |
| `image` | file  | Photo of the pothole |

**What happens:**

1. Image is sent to Gemini 2.5 Flash for analysis.
2. Gemini returns severity, priority, and estimated repair time.
3. GPS coordinates are resolved to the nearest Malaysian local authority using haversine distance.
4. A structured report is stored and returned.

**Response:** `201 Created` -- returns the full report object.

### PATCH /api/reports/{id}/status

Update the status of an existing report.

**Body:**

```json
{ "status": "In Progress" }
```

Allowed values: `Reported`, `Analyzed`, `In Progress`, `Finished`.

**Response:** `200 OK` -- returns the updated report.

### POST /analyze

Standalone image analysis endpoint. Upload any image to get Gemini's assessment.

**Response:**

```json
{ "success": true, "analysis": "{...}" }
```

## Project Layout

```
backend/
  main.py                 FastAPI app entry point, CORS, router mounting
  store.py                In-memory report store with 10 seed reports
  requirements.txt        Python dependencies
  .env                    Gemini API key (not committed)
  routes/
    reports.py            GET, POST, PATCH endpoints for reports
    analyze.py            Standalone image analysis endpoint
  schemas/
    response_model.py     Pydantic models (AnalysisResponse, PotholeReportModel)
  services/
    gemini_service.py     Gemini Vision API integration and response parsing
    jurisdiction.py       Haversine-based Malaysian local authority resolver
```

## Seed Data

The store ships with 10 pre-loaded reports distributed across Penang, Kuala Lumpur, Johor Bahru, Kota Kinabalu, and Kuching. This ensures the map has data on first load without requiring Gemini calls.

## Notes

- CORS is set to allow all origins for development. Restrict in production.
- Data is stored in memory only. Restarting the server resets all reports to the seed set.
- The jurisdiction resolver covers major Malaysian cities. Unknown coordinates fall back to the nearest match by distance.
