"""
AI Insights API routes.

Four endpoints that leverage Gemini to produce analytics:
  GET /api/insights/summary        — executive briefing
  GET /api/insights/trends         — trend analysis
  GET /api/insights/recommendations — prioritised fix list
  GET /api/insights/jurisdictions  — jurisdiction scorecards
"""

from fastapi import APIRouter, HTTPException
from store import reports
from services.insights_service import (
    generate_summary,
    generate_trends,
    generate_recommendations,
    generate_jurisdiction_scores,
    clear_cache,
)

router = APIRouter(prefix="/api/insights", tags=["insights"])


@router.get("/summary")
async def get_summary():
    """Gemini-generated executive summary of all reports."""
    try:
        return generate_summary(reports)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Insight generation failed: {e}")


@router.get("/trends")
async def get_trends():
    """Gemini-generated trend analysis."""
    try:
        return generate_trends(reports)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Insight generation failed: {e}")


@router.get("/recommendations")
async def get_recommendations():
    """Gemini-generated priority fix recommendations."""
    try:
        return generate_recommendations(reports)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Insight generation failed: {e}")


@router.get("/jurisdictions")
async def get_jurisdictions():
    """Gemini-generated jurisdiction performance scorecards."""
    try:
        return generate_jurisdiction_scores(reports)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Insight generation failed: {e}")


@router.post("/clear-cache")
async def post_clear_cache():
    """Force clear the insights cache so the next call re-queries Gemini."""
    clear_cache()
    return {"status": "cache cleared"}
