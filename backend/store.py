"""
In-memory report store for prototype.
Will be replaced by Firebase in production.
"""

import uuid
from datetime import datetime, timedelta, timezone


def next_id() -> str:
    return str(uuid.uuid4())[:8]


# ── Seed data ────────────────────────────────────────────────────────────────
# A handful of reports spread across Malaysia so the map isn't empty on load.

_now = datetime.now(timezone.utc)

reports: list[dict] = [
    # ── PENANG ──
    {
        "id": "pg01",
        "user_lat": 5.4141,
        "user_long": 100.3288,
        "image_file": "https://dummyimage.com/600x400/8b0000/fff&text=PG01",
        "timestamp": (_now - timedelta(hours=4)).isoformat(),
        "is_pothole": True,
        "size_category": "Large",
        "priority_color": "Red",
        "jurisdiction": "MBPP George Town",
        "estimated_duration": "3 days",
        "status": "Reported",
    },
    {
        "id": "pg02",
        "user_lat": 5.3553,
        "user_long": 100.3088,
        "image_file": "https://dummyimage.com/600x400/b8860b/fff&text=PG02",
        "timestamp": (_now - timedelta(days=1)).isoformat(),
        "is_pothole": True,
        "size_category": "Medium",
        "priority_color": "Yellow",
        "jurisdiction": "MBPP George Town",
        "estimated_duration": "1 day",
        "status": "Analyzed",
    },
    {
        "id": "pg03",
        "user_lat": 5.2835,
        "user_long": 100.4587,
        "image_file": "https://dummyimage.com/600x400/228b22/fff&text=PG03",
        "timestamp": (_now - timedelta(days=3)).isoformat(),
        "is_pothole": True,
        "size_category": "Small",
        "priority_color": "Green",
        "jurisdiction": "MPSP Seberang Perai",
        "estimated_duration": "4 hours",
        "status": "In Progress",
    },
    # ── KUALA LUMPUR ──
    {
        "id": "kl01",
        "user_lat": 3.1390,
        "user_long": 101.6869,
        "image_file": "https://dummyimage.com/600x400/8b0000/fff&text=KL01",
        "timestamp": (_now - timedelta(hours=6)).isoformat(),
        "is_pothole": True,
        "size_category": "Large",
        "priority_color": "Red",
        "jurisdiction": "DBKL Kuala Lumpur",
        "estimated_duration": "3 days",
        "status": "Reported",
    },
    {
        "id": "kl02",
        "user_lat": 3.1570,
        "user_long": 101.7116,
        "image_file": "https://dummyimage.com/600x400/b8860b/fff&text=KL02",
        "timestamp": (_now - timedelta(days=2)).isoformat(),
        "is_pothole": True,
        "size_category": "Medium",
        "priority_color": "Yellow",
        "jurisdiction": "DBKL Kuala Lumpur",
        "estimated_duration": "1 day",
        "status": "Analyzed",
    },
    {
        "id": "kl03",
        "user_lat": 3.1200,
        "user_long": 101.6530,
        "image_file": "https://dummyimage.com/600x400/228b22/fff&text=KL03",
        "timestamp": (_now - timedelta(days=5)).isoformat(),
        "is_pothole": True,
        "size_category": "Small",
        "priority_color": "Green",
        "jurisdiction": "DBKL Kuala Lumpur",
        "estimated_duration": "4 hours",
        "status": "Finished",
    },
    # ── JOHOR BAHRU ──
    {
        "id": "jh01",
        "user_lat": 1.4927,
        "user_long": 103.7414,
        "image_file": "https://dummyimage.com/600x400/8b0000/fff&text=JH01",
        "timestamp": (_now - timedelta(hours=2)).isoformat(),
        "is_pothole": True,
        "size_category": "Large",
        "priority_color": "Red",
        "jurisdiction": "MBJB Johor Bahru",
        "estimated_duration": "3 days",
        "status": "Reported",
    },
    {
        "id": "jh02",
        "user_lat": 1.4800,
        "user_long": 103.7600,
        "image_file": "https://dummyimage.com/600x400/b8860b/fff&text=JH02",
        "timestamp": (_now - timedelta(days=1, hours=12)).isoformat(),
        "is_pothole": True,
        "size_category": "Medium",
        "priority_color": "Yellow",
        "jurisdiction": "MBJB Johor Bahru",
        "estimated_duration": "1 day",
        "status": "In Progress",
    },
    # ── PERLIS ──
    {
        "id": "n01",
        "user_lat": 6.4414,
        "user_long": 100.1986,
        "image_file": "https://dummyimage.com/600x400/8b0000/fff&text=N01",
        "timestamp": (_now - timedelta(hours=8)).isoformat(),
        "is_pothole": True,
        "size_category": "Large",
        "priority_color": "Red",
        "jurisdiction": "JKR Perlis",
        "estimated_duration": "3 days",
        "status": "Reported",
    },
    {
        "id": "n02",
        "user_lat": 6.4550,
        "user_long": 100.2120,
        "image_file": "https://dummyimage.com/600x400/228b22/fff&text=N02",
        "timestamp": (_now - timedelta(days=4)).isoformat(),
        "is_pothole": True,
        "size_category": "Small",
        "priority_color": "Green",
        "jurisdiction": "JKR Perlis",
        "estimated_duration": "4 hours",
        "status": "Finished",
    },
]
