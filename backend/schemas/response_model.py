from pydantic import BaseModel
from typing import Optional


class AnalysisResponse(BaseModel):
    success: bool
    analysis: str | None = None
    error: str | None = None


class PotholeReportModel(BaseModel):
    id: str
    user_lat: float
    user_long: float
    image_file: str
    timestamp: str
    is_pothole: bool
    size_category: str
    priority_color: str
    jurisdiction: str
    estimated_duration: str
    status: str


class StatusUpdateRequest(BaseModel):
    status: str
