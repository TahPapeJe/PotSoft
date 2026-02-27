"""
Reports API routes: GET, POST, PATCH
Prototype — in-memory store, no auth.
"""

from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from schemas.response_model import PotholeReportModel, StatusUpdateRequest
from services.gemini_service import analyze_image, parse_gemini_response
from services.jurisdiction import resolve_jurisdiction
from store import reports, next_id
import base64
from datetime import datetime, timezone

router = APIRouter(prefix="/api/reports", tags=["reports"])


# ── GET /api/reports ─────────────────────────────────────────────────────────
@router.get("", response_model=list[PotholeReportModel])
async def get_reports():
    """Return all pothole reports."""
    return reports


# ── POST /api/reports ────────────────────────────────────────────────────────
@router.post("", response_model=PotholeReportModel, status_code=201)
async def create_report(
    lat: float = Form(...),
    long: float = Form(...),
    image: UploadFile = File(...),
):
    """
    Submit a new pothole report.
    1. Accept image + GPS coords
    2. Send image to Gemini for analysis
    3. Build structured report and store it
    """
    # Read and encode image
    contents = await image.read()
    image_b64 = base64.b64encode(contents).decode("utf-8")
    mime_type = image.content_type or "image/jpeg"

    # Store image as data URI in the report (prototype — no cloud bucket)
    image_data_uri = f"data:{mime_type};base64,{image_b64}"

    # Call Gemini
    gemini_result = analyze_image(image_b64, mime_type, lat=lat, lng=long)

    if gemini_result.success and gemini_result.analysis:
        analysis = parse_gemini_response(gemini_result.analysis)
    else:
        # Fallback defaults if Gemini fails — still create the report
        analysis = {
            "is_pothole": False,
            "size_category": "Small",
            "priority_color": "Green",
            "estimated_duration": "4 hours",
            "jurisdiction": "Unknown",
        }

    # Always resolve jurisdiction from coordinates (more reliable than Gemini)
    jurisdiction = resolve_jurisdiction(lat, long)
    analysis["jurisdiction"] = jurisdiction

    report = {
        "id": next_id(),
        "user_lat": lat,
        "user_long": long,
        "image_file": image_data_uri,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "is_pothole": analysis["is_pothole"],
        "size_category": analysis["size_category"],
        "priority_color": analysis["priority_color"],
        "jurisdiction": analysis["jurisdiction"],
        "estimated_duration": analysis["estimated_duration"],
        "status": "Analyzed",
    }

    reports.append(report)
    return report


# ── PATCH /api/reports/{report_id}/status ────────────────────────────────────
@router.patch("/{report_id}/status", response_model=PotholeReportModel)
async def update_report_status(report_id: str, body: StatusUpdateRequest):
    """Update the status of an existing report."""
    allowed = {"Reported", "Analyzed", "In Progress", "Finished"}
    if body.status not in allowed:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid status. Must be one of: {', '.join(sorted(allowed))}",
        )

    for report in reports:
        if report["id"] == report_id:
            report["status"] = body.status
            return report

    raise HTTPException(status_code=404, detail=f"Report {report_id} not found.")
