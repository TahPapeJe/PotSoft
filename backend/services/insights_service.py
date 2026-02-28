"""
Gemini-powered analytics insights engine.

Builds structured data summaries from the in-memory report store and sends
them to Gemini 2.5 Flash for natural-language analysis across four domains:
  1. Executive Summary
  2. Trend Analysis
  3. Priority Recommendations
  4. Jurisdiction Scorecards

Results are cached for 5 minutes to avoid excessive Gemini API calls.
"""

import json
import os
import re
import time
from datetime import datetime, timezone
from collections import defaultdict

from dotenv import load_dotenv
import google.generativeai as genai

# Load .env and configure Gemini API key
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# ── Cache ────────────────────────────────────────────────────────────────────
_cache: dict[str, tuple[float, dict]] = {}
_CACHE_TTL = 300  # 5 minutes


def _get_cached(key: str) -> dict | None:
    if key in _cache:
        ts, data = _cache[key]
        if time.time() - ts < _CACHE_TTL:
            return data
    return None


def _set_cached(key: str, data: dict):
    _cache[key] = (time.time(), data)


def clear_cache():
    _cache.clear()


# ── Helpers ──────────────────────────────────────────────────────────────────


def _build_data_summary(reports: list[dict]) -> dict:
    """Build an aggregate summary dict from the raw report list."""
    now = datetime.now(timezone.utc)
    total = len(reports)

    # Counts by priority / status / size
    priority_counts = defaultdict(int)
    status_counts = defaultdict(int)
    size_counts = defaultdict(int)
    jurisdiction_map: dict[str, list[dict]] = defaultdict(list)

    overdue_ids = []
    ages_hours = []

    for r in reports:
        priority_counts[r.get("priority_color", "Green")] += 1
        status_counts[r.get("status", "Reported")] += 1
        size_counts[r.get("size_category", "Small")] += 1
        jurisdiction_map[r.get("jurisdiction", "Unknown")].append(r)

        try:
            ts = datetime.fromisoformat(r["timestamp"])
            age_h = (now - ts).total_seconds() / 3600
            ages_hours.append(age_h)
            if r.get("status") == "Reported" and age_h > 24:
                overdue_ids.append(r["id"])
        except Exception:
            pass

    finished = status_counts.get("Finished", 0)
    resolution_rate = round(finished / total * 100, 1) if total else 0
    avg_age_h = round(sum(ages_hours) / len(ages_hours), 1) if ages_hours else 0

    # Per-jurisdiction summary
    jurisdiction_summaries = {}
    for jur, reps in jurisdiction_map.items():
        j_total = len(reps)
        j_finished = sum(1 for r in reps if r.get("status") == "Finished")
        j_red = sum(1 for r in reps if r.get("priority_color") == "Red")
        j_overdue = sum(
            1 for r in reps if r.get("status") == "Reported" and _age_hours(r, now) > 24
        )
        j_ages = [_age_hours(r, now) for r in reps if r.get("status") != "Finished"]
        j_avg_response = round(sum(j_ages) / len(j_ages), 1) if j_ages else 0
        jurisdiction_summaries[jur] = {
            "total": j_total,
            "finished": j_finished,
            "red": j_red,
            "overdue": j_overdue,
            "resolution_rate": round(j_finished / j_total * 100, 1) if j_total else 0,
            "avg_open_hours": j_avg_response,
        }

    # Daily volume (last 14 days)
    daily_reported: dict[str, int] = defaultdict(int)
    daily_finished: dict[str, int] = defaultdict(int)
    for r in reports:
        try:
            ts = datetime.fromisoformat(r["timestamp"])
            day_str = ts.strftime("%Y-%m-%d")
            daily_reported[day_str] += 1
            if r.get("status") == "Finished":
                daily_finished[day_str] += 1
        except Exception:
            pass

    return {
        "total_reports": total,
        "priority": dict(priority_counts),
        "status": dict(status_counts),
        "size": dict(size_counts),
        "resolution_rate": resolution_rate,
        "avg_age_hours": avg_age_h,
        "overdue_count": len(overdue_ids),
        "overdue_ids": overdue_ids[:20],
        "jurisdiction_count": len(jurisdiction_map),
        "jurisdictions": jurisdiction_summaries,
        "daily_reported": dict(daily_reported),
        "daily_finished": dict(daily_finished),
    }


def _age_hours(report: dict, now: datetime) -> float:
    try:
        ts = datetime.fromisoformat(report["timestamp"])
        return (now - ts).total_seconds() / 3600
    except Exception:
        return 0


def _call_gemini(prompt: str, max_retries: int = 3) -> str:
    """Send a text prompt to Gemini with retry on rate-limit errors."""
    model = genai.GenerativeModel("gemini-2.5-flash")
    for attempt in range(max_retries):
        try:
            response = model.generate_content(prompt)
            return response.text or ""
        except Exception as e:
            err_str = str(e).lower()
            is_rate_limit = (
                "429" in err_str
                or "resource_exhausted" in err_str
                or "quota" in err_str
            )
            if is_rate_limit and attempt < max_retries - 1:
                wait = (attempt + 1) * 15  # 15s, 30s, 45s
                time.sleep(wait)
                continue
            raise


def _parse_json_response(raw: str) -> dict:
    """Strip markdown fences and parse JSON from Gemini's reply."""
    cleaned = raw.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = cleaned.strip()
    try:
        return json.loads(cleaned)
    except (json.JSONDecodeError, TypeError):
        return {"raw_text": cleaned}


# ── Public API ───────────────────────────────────────────────────────────────


def generate_summary(reports: list[dict]) -> dict:
    """Executive summary: natural-language weekly report."""
    cached = _get_cached("summary")
    if cached:
        return cached

    summary = _build_data_summary(reports)
    prompt = f"""You are PotSoft AI, an infrastructure analytics assistant for Malaysian road maintenance.

Given this pothole report data summary, write an executive briefing in JSON format.

DATA:
{json.dumps(summary, indent=2)}

Respond with ONLY valid JSON (no markdown, no code fences):
{{
  "title": "Weekly Infrastructure Report",
  "date_range": "description of the data period",
  "overview": "2-3 sentence natural-language summary of the overall situation",
  "key_stats": [
    {{"label": "Total Reports", "value": "{summary["total_reports"]}", "trend": "up|down|stable"}},
    {{"label": "Resolution Rate", "value": "{summary["resolution_rate"]}%", "trend": "up|down|stable"}},
    {{"label": "Overdue", "value": "{summary["overdue_count"]}", "trend": "up|down|stable"}},
    {{"label": "Avg Age", "value": "{summary["avg_age_hours"]}h", "trend": "up|down|stable"}}
  ],
  "highlights": ["highlight 1", "highlight 2", "highlight 3"],
  "recommendations": ["recommendation 1", "recommendation 2", "recommendation 3"]
}}
"""
    raw = _call_gemini(prompt)
    result = _parse_json_response(raw)
    _set_cached("summary", result)
    return result


def generate_trends(reports: list[dict]) -> dict:
    """Trend analysis: emerging hotspots, worsening areas, time-based patterns."""
    cached = _get_cached("trends")
    if cached:
        return cached

    summary = _build_data_summary(reports)
    prompt = f"""You are PotSoft AI, an infrastructure analytics assistant.

Analyse these pothole report statistics and identify trends.

DATA:
{json.dumps(summary, indent=2)}

Respond with ONLY valid JSON (no markdown, no code fences):
{{
  "emerging_hotspots": [
    {{"jurisdiction": "name", "reason": "why this is emerging", "severity": "high|medium|low", "report_count": <int>}}
  ],
  "worsening_areas": [
    {{"jurisdiction": "name", "issue": "description of deterioration", "metric": "specific stat"}}
  ],
  "positive_trends": [
    {{"description": "something improving", "metric": "specific stat"}}
  ],
  "daily_pattern": "one sentence about report timing patterns",
  "overall_direction": "improving|stable|declining",
  "summary": "2-3 sentence natural-language trend summary"
}}
"""
    raw = _call_gemini(prompt)
    result = _parse_json_response(raw)
    _set_cached("trends", result)
    return result


def generate_recommendations(reports: list[dict]) -> dict:
    """Priority recommendations: ranked list of what to fix first."""
    cached = _get_cached("recommendations")
    if cached:
        return cached

    # Build a prioritised shortlist of actionable reports
    now = datetime.now(timezone.utc)
    actionable = [r for r in reports if r.get("status") in ("Reported", "Analyzed")]
    # Sort by priority (Red first), then age (oldest first)
    prio_order = {"Red": 0, "Yellow": 1, "Green": 2}
    actionable.sort(
        key=lambda r: (
            prio_order.get(r.get("priority_color", "Green"), 3),
            r.get("timestamp", ""),
        )
    )

    top_20 = []
    for r in actionable[:20]:
        age = _age_hours(r, now)
        top_20.append(
            {
                "id": r["id"],
                "jurisdiction": r.get("jurisdiction", "Unknown"),
                "priority": r.get("priority_color", "Green"),
                "size": r.get("size_category", "Small"),
                "status": r.get("status", "Reported"),
                "age_hours": round(age, 1),
                "lat": r.get("user_lat"),
                "lng": r.get("user_long"),
            }
        )

    summary = _build_data_summary(reports)
    prompt = f"""You are PotSoft AI, a road maintenance prioritisation expert.

Given these actionable pothole reports and overall statistics, rank the top 10 reports
that should be fixed first. Consider severity, age, clustering (nearby reports), and
jurisdiction workload.

ACTIONABLE REPORTS:
{json.dumps(top_20, indent=2)}

OVERALL STATS:
{json.dumps(summary, indent=2)}

Respond with ONLY valid JSON (no markdown, no code fences):
{{
  "priority_queue": [
    {{
      "rank": 1,
      "report_id": "id",
      "jurisdiction": "name",
      "priority": "Red|Yellow|Green",
      "age_hours": 48.2,
      "size": "Small|Medium|Large",
      "reason": "why fix this first",
      "urgency": "critical|high|medium",
      "estimated_impact": "description of impact if not fixed"
    }}
  ],
  "clustering_insights": "description of geographic clusters that could be batched for efficiency",
  "resource_suggestion": "recommendation on how to allocate repair crews"
}}
"""
    raw = _call_gemini(prompt)
    result = _parse_json_response(raw)
    _set_cached("recommendations", result)
    return result


def generate_jurisdiction_scores(reports: list[dict]) -> dict:
    """Jurisdiction scorecards: performance ratings per local authority."""
    cached = _get_cached("jurisdictions")
    if cached:
        return cached

    summary = _build_data_summary(reports)
    prompt = f"""You are PotSoft AI, a municipal performance evaluator.

Rate each jurisdiction's road-maintenance performance based on:
- Resolution rate (% finished)
- Average response time (hours open)
- Number of overdue reports
- Proportion of high-priority (Red) reports

JURISDICTION DATA:
{json.dumps(summary["jurisdictions"], indent=2)}

Respond with ONLY valid JSON (no markdown, no code fences):
{{
  "scorecards": [
    {{
      "jurisdiction": "name",
      "grade": "A|B|C|D|F",
      "resolution_rate": <float>,
      "avg_response_hours": <float>,
      "overdue": <int>,
      "red_count": <int>,
      "total": <int>,
      "summary": "one sentence assessment",
      "suggestion": "one sentence improvement suggestion"
    }}
  ],
  "best_performer": "jurisdiction name",
  "needs_attention": "jurisdiction name",
  "overall_assessment": "2-3 sentence overall assessment of municipal performance"
}}
"""
    raw = _call_gemini(prompt)
    result = _parse_json_response(raw)
    _set_cached("jurisdictions", result)
    return result
