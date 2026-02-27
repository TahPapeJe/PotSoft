# Backend Integration Guide — PotSoft

This document describes all REST API endpoints, data contracts, and integration steps required to connect the PotSoft Flutter Web frontend to a real backend.

---

## Architecture Overview

```
Citizen (mobile/web)          Contractor (web dashboard)
       │                                │
       │  POST /api/reports             │  GET /api/reports
       │  (image + GPS)                 │  PATCH /api/reports/:id/status
       ▼                                ▼
  ┌─────────────────────────────────────────────┐
  │                  REST API                    │
  │         (FastAPI / Express / etc.)           │
  └────────────────┬────────────────────────────┘
                   │
         ┌─────────┴──────────┐
         │                    │
    Gemini Vision API      Database
    (analysis & scoring)   (reports store)
```

---

## Data Model

The frontend's `PotholeReport` model maps directly to this JSON schema.

### `PotholeReport` Object

| JSON Field           | Dart Field          | Type     | Description                                                     |
| -------------------- | ------------------- | -------- | --------------------------------------------------------------- |
| `id`                 | `id`                | `string` | Unique report ID                                                |
| `user_lat`           | `userLat`           | `float`  | GPS latitude                                                    |
| `user_long`          | `userLong`          | `float`  | GPS longitude                                                   |
| `image_file`         | `imageFile`         | `string` | URL or base64 data URI of the photo                             |
| `timestamp`          | `timestamp`         | `string` | ISO 8601 datetime (e.g. `2026-02-27T14:30:00Z`)                 |
| `is_pothole`         | `isPothole`         | `bool`   | `true` if Gemini confirms it is a pothole                       |
| `size_category`      | `sizeCategory`      | `string` | `"Small"` \| `"Medium"` \| `"Large"`                            |
| `priority_color`     | `priorityColor`     | `string` | `"Green"` \| `"Yellow"` \| `"Red"`                              |
| `jurisdiction`       | `jurisdiction`      | `string` | Local authority name (e.g. `"MBPP George Town"`)                |
| `estimated_duration` | `estimatedDuration` | `string` | Human-readable fix time (e.g. `"3 days"`, `"4 hours"`)          |
| `status`             | `status`            | `string` | `"Reported"` \| `"Analyzed"` \| `"In Progress"` \| `"Finished"` |

#### Enum Values (validated by the frontend)

| Field            | Allowed Values                                    |
| ---------------- | ------------------------------------------------- |
| `status`         | `Reported`, `Analyzed`, `In Progress`, `Finished` |
| `priority_color` | `Red`, `Yellow`, `Green`                          |
| `size_category`  | `Small`, `Medium`, `Large`                        |

---

## API Endpoints

### Base URL

Configure this in `ReportProvider` when replacing mock data:

```dart
const String _baseUrl = 'https://api.yourdomain.com';
```

---

### `GET /api/reports`

Fetch all pothole reports to populate the map and sidebar list.

**Response `200 OK`:**

```json
[
  {
    "id": "pg01",
    "user_lat": 5.4141,
    "user_long": 100.3288,
    "image_file": "https://storage.example.com/images/pg01.jpg",
    "timestamp": "2026-02-27T12:00:00Z",
    "is_pothole": true,
    "size_category": "Large",
    "priority_color": "Red",
    "jurisdiction": "MBPP George Town",
    "estimated_duration": "2 days",
    "status": "Reported"
  }
]
```

**Frontend integration point:** Replace `_reports` list in `ReportProvider` with an HTTP `GET` call in `initState` or `loadReports()`.

---

### `POST /api/reports`

Submit a new pothole report from the Citizen screen. This endpoint should:

1. Accept the photo and GPS coordinates
2. Pass the image to **Gemini Vision API** to determine `is_pothole`, `size_category`, `priority_color`, and `estimated_duration`
3. Resolve `jurisdiction` from the GPS coordinates (reverse geocoding)
4. Persist the report and return the fully populated object

**Request** — `multipart/form-data`:

| Field   | Type  | Description                   |
| ------- | ----- | ----------------------------- |
| `lat`   | float | GPS latitude                  |
| `long`  | float | GPS longitude                 |
| `image` | file  | Photo captured by the citizen |

> If sending base64 instead of multipart, use `application/json` with `image_base64: "data:image/jpeg;base64,..."`.

**Response `201 Created`:**

```json
{
  "id": "abc-123",
  "user_lat": 5.4141,
  "user_long": 100.3288,
  "image_file": "https://storage.example.com/images/abc-123.jpg",
  "timestamp": "2026-02-27T14:30:00Z",
  "is_pothole": true,
  "size_category": "Large",
  "priority_color": "Red",
  "jurisdiction": "MBPP George Town",
  "estimated_duration": "2 days",
  "status": "Analyzed"
}
```

> **Note:** The frontend's `submitReport()` sets status directly to `"Analyzed"` after the AI step. If `is_pothole` is `false`, the report should still be stored but the frontend will receive `is_pothole: false` and may suppress it from the map.

**Frontend integration point:** `ReportProvider.submitReport()` — replace the `Future.delayed` simulation with a real HTTP `POST`.

---

### `PATCH /api/reports/:id/status`

Update the status of a report. Called from the Contractor dashboard when a field officer marks a report as **In Progress** or **Finished**.

**Request** — `application/json`:

```json
{
  "status": "In Progress"
}
```

| `status` value | Triggered by                           |
| -------------- | -------------------------------------- |
| `In Progress`  | Contractor taps **IN PROGRESS** button |
| `Finished`     | Contractor taps **FINISH JOB** button  |

**Response `200 OK`:**

```json
{
  "id": "pg01",
  "status": "In Progress"
}
```

**Frontend integration point:** `ReportProvider.updateStatus()` — add an HTTP `PATCH` call before calling `notifyListeners()`.

---

## Gemini Vision API Integration

The backend should call Gemini Vision to analyse the submitted image. The recommended prompt:

```
Analyse this road image and respond with ONLY a JSON object:
{
  "is_pothole": true or false,
  "size_category": "Small" | "Medium" | "Large",
  "priority_color": "Green" | "Yellow" | "Red",
  "estimated_duration": "4 hours" | "1 day" | "3 days"
}

Rules:
- is_pothole: true only if a pothole is clearly visible
- size_category: Small (<20cm), Medium (20–50cm), Large (>50cm)
- priority_color: Green = Small, Yellow = Medium, Red = Large
- estimated_duration: "4 hours" for Small, "1 day" for Medium, "3 days" for Large
```

---

## CORS Configuration

The Flutter Web frontend runs on a browser and requires CORS headers from the backend:

```
Access-Control-Allow-Origin: https://yourdomain.com
Access-Control-Allow-Methods: GET, POST, PATCH, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

For local development, allow `http://localhost:*`.

---

## Authentication

The Contractor dashboard is currently protected by a hardcoded passcode gate in the frontend (`SecureGateWidget`). For production:

- Issue a **JWT** or **API key** on passcode/login verification
- The frontend should attach it as `Authorization: Bearer <token>` on all contractor-facing requests (`GET /api/reports`, `PATCH /api/reports/:id/status`)
- The backend must validate the token on those routes

---

## Frontend Integration Checklist

Replace these sections in `lib/core/providers/report_provider.dart`:

| Step | Location                       | Change                                                                     |
| ---- | ------------------------------ | -------------------------------------------------------------------------- |
| 1    | `_reports` list (lines 6–1279) | Remove all hardcoded seed data; call `GET /api/reports` on init            |
| 2    | `submitReport()`               | Replace `Future.delayed` + random logic with `POST /api/reports` multipart |
| 3    | `updateStatus()`               | Add `PATCH /api/reports/:id/status` call before `notifyListeners()`        |
| 4    | Error handling                 | Add `try/catch` with user-facing snackbars for network failures            |
| 5    | Auth header                    | Inject JWT from secure storage into every outgoing request                 |

### Minimal `ReportProvider` structure after integration

```dart
class ReportProvider extends ChangeNotifier {
  final String _base = 'https://api.yourdomain.com';
  List<PotholeReport> _reports = [];
  List<PotholeReport> get reports => _reports;

  Future<void> loadReports() async {
    final res = await http.get(Uri.parse('$_base/api/reports'));
    _reports = (jsonDecode(res.body) as List)
        .map((j) => PotholeReport.fromJson(j))
        .toList();
    notifyListeners();
  }

  Future<void> submitReport(double lat, double long, String imagePath) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/api/reports'))
      ..fields['lat'] = '$lat'
      ..fields['long'] = '$long'
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    _reports.add(PotholeReport.fromJson(jsonDecode(body)));
    notifyListeners();
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await http.patch(
      Uri.parse('$_base/api/reports/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': newStatus}),
    );
    final index = _reports.indexWhere((r) => r.id == id);
    if (index != -1) {
      _reports[index] = _reports[index].copyWith(status: newStatus);
      notifyListeners();
    }
  }
}
```

Add `http: ^1.2.0` to `pubspec.yaml` dependencies.

---

## Environment Summary

| Item             | Current (mock)            | Production target                   |
| ---------------- | ------------------------- | ----------------------------------- |
| Report data      | 94 hardcoded Dart objects | `GET /api/reports`                  |
| Pothole analysis | `Random()` size/priority  | Gemini Vision API                   |
| Status updates   | In-memory only            | `PATCH /api/reports/:id/status`     |
| Jurisdiction     | Hardcoded string          | Reverse-geocode from GPS            |
| Auth             | Hardcoded passcode        | JWT issued by backend               |
| Image storage    | Placeholder URLs          | Cloud bucket URL returned by `POST` |
