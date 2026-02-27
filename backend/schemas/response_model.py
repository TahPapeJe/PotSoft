from pydantic import BaseModel

class AnalysisResponse(BaseModel):
    success: bool
    analysis: str | None = None
    error: str | None = None
