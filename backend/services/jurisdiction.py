"""
Simple coordinate-to-jurisdiction resolver for Malaysian local authorities.
Maps GPS coordinates to the nearest known jurisdiction using state-level regions.
Prototype only — replace with a proper reverse-geocoding API for production.
"""

import math

# Each entry: (lat, long, jurisdiction_name)
# Centroid-based approximations for Malaysian states / major cities.
_JURISDICTIONS = [
    # ── Peninsular Malaysia ──
    (6.4414, 100.1986, "JKR Perlis"),
    (6.1184, 100.3685, "JKR Kedah"),
    (6.4500, 100.5000, "JKR Kedah"),  # Kedah north
    (5.4141, 100.3288, "MBPP George Town"),  # Penang island
    (5.3553, 100.4687, "MPSP Seberang Perai"),  # Penang mainland
    (4.5970, 101.0901, "MBI Ipoh"),  # Perak / Ipoh
    (4.2000, 100.8500, "JKR Perak"),  # Perak south
    (4.7500, 100.9500, "JKR Perak"),  # Perak central
    (4.3630, 100.9825, "JKR Perak"),  # Perak – Tapah area
    (3.1390, 101.6869, "DBKL Kuala Lumpur"),  # KL
    (3.0738, 101.5183, "MBPJ Petaling Jaya"),  # PJ
    (3.1579, 101.7116, "MBSA Shah Alam"),  # Shah Alam
    (3.0000, 101.4500, "MPS Subang Jaya"),  # Subang Jaya
    (2.9264, 101.6964, "MPKj Kajang"),  # Kajang
    (3.3200, 101.5500, "MPS Selayang"),  # Selayang/Gombak
    (2.9353, 101.9572, "JKR Selangor"),  # Selangor general
    (2.9264, 102.2515, "MBNS Seremban"),  # Negeri Sembilan
    (2.1896, 102.2501, "MBMB Melaka"),  # Melaka
    (1.4927, 103.7414, "MBJB Johor Bahru"),  # JB
    (1.8548, 103.0913, "JKR Johor"),  # Johor central
    (2.0150, 102.5600, "MPM Muar"),  # Muar
    (3.8077, 103.3260, "MPK Kuantan"),  # Pahang / Kuantan
    (3.5200, 102.4500, "JKR Pahang"),  # Pahang central
    (4.2250, 101.9500, "JKR Pahang"),  # Cameron Highlands area
    (5.3117, 103.1324, "MBKT Kuala Terengganu"),  # Terengganu
    (6.1254, 102.2381, "MPKB Kota Bharu"),  # Kelantan
    (2.0174, 103.4000, "JKR Johor"),  # Johor east
    (1.5400, 103.8000, "MBJB Johor Bahru"),  # JB east
    (2.9480, 101.7900, "DBKL Kuala Lumpur"),  # KL south extent
    (3.1700, 101.7100, "DBKL Kuala Lumpur"),  # KL east
    # ── Putrajaya & Cyberjaya ──
    (2.9264, 101.6964, "PPj Putrajaya"),
    (2.9190, 101.6500, "PPj Putrajaya"),
    # ── Sabah & Sarawak ──
    (5.9804, 116.0735, "DBKK Kota Kinabalu"),  # Sabah
    (6.0500, 116.0500, "JKR Sabah"),
    (5.3000, 115.5000, "JKR Sabah"),  # Sabah south
    (1.5535, 110.3593, "DBKU Kuching"),  # Sarawak
    (2.3000, 111.8500, "JKR Sarawak"),  # Sarawak central
    (2.2800, 111.8300, "MBS Sibu"),  # Sibu
    (4.0300, 114.0000, "JKR Sarawak"),  # Sarawak north
    # ── Labuan ──
    (5.2831, 115.2308, "PLB Labuan"),
]


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance between two points in km."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def resolve_jurisdiction(lat: float, lng: float) -> str:
    """
    Return the name of the nearest Malaysian local authority
    for the given GPS coordinates.
    Falls back to a generic label if nothing is within 100 km.
    """
    best_name = "JKR Malaysia"
    best_dist = float("inf")

    for jlat, jlng, name in _JURISDICTIONS:
        d = _haversine_km(lat, lng, jlat, jlng)
        if d < best_dist:
            best_dist = d
            best_name = name

    # If the nearest known point is > 100 km away, the coords are probably
    # outside our coverage — return a generic fallback.
    if best_dist > 100:
        return "JKR Malaysia"

    return best_name
