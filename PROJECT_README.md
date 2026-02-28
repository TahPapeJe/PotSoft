# PotSoft — AI-Powered Pothole Detection & Reporting Platform for Malaysia

# Part 1: Project Description

## Brief Summary

PotSoft is an AI-powered civic infrastructure platform that transforms how Malaysians report and how local authorities repair potholes. Citizens photograph road damage with their phone, and the system instantly analyzes the image using Google Gemini Vision, classifies the severity, identifies the responsible local authority, and routes the report to a contractor dashboard where AI-generated priority recommendations tell maintenance crews exactly which pothole to fix first and why.

## Purpose & Problem Statement

Malaysia's road maintenance system is broken at every stage of the reporting-to-repair pipeline.

**Citizens face three barriers when reporting potholes:**

- They do not know which authority is responsible for their stretch of road. Malaysia has 149 local authorities — PBTs, MPPs, MBs, DBKL, and state-level JKR offices — each managing overlapping road networks. A citizen standing on Jalan Bota between Seri Iskandar and Batu Gajah has no way of knowing whether to call MPBG Batu Gajah, MBI Ipoh, or JKR Perak.
- Existing complaint channels are fragmented and unstructured. Citizens report through SISPAA (the government portal), council Facebook pages, WhatsApp groups, phone calls, and Twitter — each channel operating independently with no unified tracking. The same pothole gets reported five times by five different people through five different channels.
- There is no feedback loop. A citizen who reports a pothole has no way to know whether anyone received the report, whether it was prioritized, or whether repair is scheduled. Most simply give up after one attempt.

**Local authorities face three operational failures:**

- Incoming complaints arrive with no standardized severity assessment. A phone call saying "there is a big hole on Jalan Gombak" provides no actionable data — how big, how deep, how dangerous, where exactly.
- There is no prioritization system. Complaints are processed in the order they arrive, not by urgency. A small cosmetic crack reported on Monday gets attention before a dangerous axle-breaking pothole reported on Tuesday.
- There is no performance accountability. No authority tracks its own average response time, resolution rate, or overdue report count. Without data, there is no basis for improvement.

**The human cost is real.** In 2024, approximately 6,606 accident cases involved motorcyclists hitting or swerving to avoid potholes on Malaysian roads. During user testing, one of our UTP student participants had sustained road rash injuries from a motorcycle fall caused by a pothole near Kampung Bota. Another had spent RM650 on suspension repairs after hitting an invisible pothole at night on the Seri Iskandar-Ipoh road.

**How PotSoft solves this:**

- **For citizens:** Take a photo, tap submit. That is the entire workflow. No form fields, no department selection, no account creation. AI handles classification. GPS handles jurisdiction routing.
- **For contractors:** A real-time dashboard with filterable report lists, an interactive priority map, six KPI cards with trend indicators, five analytics charts, and Gemini AI-generated insights that produce a ranked priority queue, trend analysis, executive summary, and jurisdiction performance scorecards — all from live data, regenerated on demand.

## Alignment with AI and SDGs

### SDG 11 — Sustainable Cities and Communities

PotSoft directly addresses SDG Target 1 (safe, affordable, accessible transport systems) and Target 11.7 (universal access to safe, inclusive public spaces). Potholes are not just an inconvenience — they are a safety hazard that disproportionately affects vulnerable road users. Motorcyclists, who make up 48% of Malaysian road users, are the most at risk because a pothole that a car absorbs can throw a motorcycle rider off their vehicle. By enabling instant AI-powered reporting and priority-based repair scheduling, PotSoft directly reduces the time citizens are exposed to dangerous road conditions.

### SDG 9 — Industry, Innovation, and Infrastructure

PotSoft applies AI innovation to infrastructure maintenance — a domain that in Malaysia still operates on manual inspection, phone-call complaints, and spreadsheet tracking. The platform introduces three capabilities that did not previously exist in Malaysian road maintenance: automated severity classification from photographs, GPS-based jurisdiction routing that eliminates citizen confusion, and AI-generated priority recommendations that optimize repair crew deployment for maximum safety impact per ringgit spent.

### AI as the Core Enabler

AI is not a feature added to PotSoft — it is the reason PotSoft exists. Without Gemini Vision, a submitted photo is just a photo with no actionable metadata. Without Gemini's analytical capabilities, the contractor dashboard is a chronological complaint list with no intelligence. Every differentiating capability — instant severity classification, priority ranking, jurisdiction scoring, trend detection, hotspot identification — is powered by Google Gemini.

---

# Part 2: Project Documentation

## Technical Implementation — Overview of Technologies Used

### Technology Stack

| Layer                | Technology                         | Purpose                                                                                           |
| -------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Frontend**         | Flutter (Web)                      | Dual-portal UI — citizen reporting portal and contractor management dashboard                     |
| **Backend**          | FastAPI (Python)                   | REST API server handling report lifecycle, jurisdiction resolution, and Gemini API orchestration  |
| **AI — Vision**      | Google Gemini 2.5 Flash            | Real-time pothole image analysis, severity classification, priority assignment, repair estimation |
| **AI — Analytics**   | Google Gemini 2.5 Flash Lite       | Executive summaries, trend analysis, priority recommendations, jurisdiction scorecards            |
| **AI — Development** | Google AI Studio                   | Prompt engineering, iteration, and testing across 20+ prompt variations                           |
| **Maps**             | Google Maps Platform (Flutter SDK) | Interactive dark-mode maps with color-coded priority markers in both portals                      |
| **Typography**       | Google Fonts (Inter)               | Consistent, readable typography optimized for data-dense dashboard screens                        |
| **Data Store**       | In-memory (Python)                 | Prototype-stage report storage with service-layer abstraction for future Firestore migration      |

### Google Technologies — Why Each Was Chosen

**Google Gemini 2.5 Flash** was chosen over OpenAI GPT-4o and Google Cloud Vision API because it is the only model that combines multimodal vision analysis with structured JSON output in under 3 seconds. Cloud Vision can label an image as "road" or "crack" but cannot assess pothole depth, estimate repair duration, or assign priority. GPT-4o has comparable vision capabilities but lacks Gemini's free-tier quota and introduces a non-Google dependency.

**Google Gemini 2.5 Flash Lite** was chosen for analytics over using Flash for everything because the analytics endpoints process structured text, not images — Flash Lite handles this with equivalent quality at higher free-tier quota limits. Splitting workload across two models prevents citizen photo submissions from consuming quota needed for contractor analytics.

**Google Maps Platform** was chosen over Mapbox and OpenStreetMap because it has the most comprehensive road data for Malaysia — including kampung roads, newly built highways, and rural routes that other providers often lack. The Flutter SDK provides native performance with dark-mode styling.

**Flutter** was chosen over React or Angular because it compiles to web, Android, and iOS from a single codebase. The citizen portal is designed to become a mobile app — Flutter makes that a build flag change, not a rewrite.

**Google AI Studio** was used during development to test approximately 20 prompt variations against real pothole images. AI Studio's playground compressed days of prompt iteration into hours.

---

## Technical Architecture

PotSoft follows a three-tier architecture with a clear separation between the citizen-facing frontend, the contractor-facing frontend, and the AI-powered backend.

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (Flutter Web)                │
│                                                         │
│  ┌──────────────────┐      ┌──────────────────────────┐ │
│  │  CITIZEN PORTAL   │      │  CONTRACTOR DASHBOARD    │ │
│  │                   │      │                          │ │
│  │  • Google Map     │      │  • Google Map (filtered) │ │
│  │  • Photo capture  │      │  • Report list + cards   │ │
│  │  • Report dialog  │      │  • Analytics tab         │ │
│  │  • Status legend  │      │    - 6 KPI cards         │ │
│  │  • Report count   │      │    - 5 charts            │ │
│  │                   │      │    - Gemini AI Insights   │ │
│  └────────┬─────────┘      └────────────┬─────────────┘ │
│           │         HTTP REST            │               │
│           └──────────────┬───────────────┘               │
└──────────────────────────┼───────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│                 BACKEND (FastAPI + Python)                │
│                                                          │
│  ┌─────────────────┐  ┌───────────────────────────────┐  │
│  │  Report Engine   │  │  AI Service Layer             │  │
│  │                  │  │                               │  │
│  │  POST /report    │  │  Gemini 2.5 Flash (Vision)   │  │
│  │  GET /reports    │  │  → Image analysis             │  │
│  │  PATCH /report   │  │  → Severity classification    │  │
│  │  GET /report/:id │  │  → Priority assignment        │  │
│  │                  │  │  → Repair time estimation     │  │
│  └────────┬─────────┘  │                               │  │
│           │            │  Gemini 2.5 Flash Lite        │  │
│           ▼            │  → Executive summary          │  │
│  ┌─────────────────┐   │  → Trend analysis             │  │
│  │  Jurisdiction    │  │  → Priority recommendations   │  │
│  │  Resolver        │  │  → Jurisdiction scorecards    │  │
│  │                  │  │                               │  │
│  │  40+ Malaysian   │  └───────────────────────────────┘  │
│  │  local authority │                                     │
│  │  GPS boundaries  │  ┌───────────────────────────────┐  │
│  │  Haversine dist. │  │  In-Memory Data Store         │  │
│  │  50km radius     │  │                               │  │
│  └─────────────────┘  │  • Reports list               │  │
│                        │  • Status history timestamps  │  │
│                        │  • AI classification cache    │  │
│                        └───────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│              EXTERNAL SERVICES (Google Cloud)             │
│                                                          │
│  ┌──────────────────┐  ┌───────────────────────────────┐ │
│  │  Google Gemini    │  │  Google Maps Platform        │ │
│  │  API              │  │                              │ │
│  │  • 2.5 Flash      │  │  • Maps Flutter SDK         │ │
│  │  • 2.5 Flash Lite │  │  • Dark mode tile styling   │ │
│  │                   │  │  • Marker rendering          │ │
│  └──────────────────┘  └───────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### How the Components Connect

**The citizen reporting flow:** A citizen opens the portal and sees a full-screen Google Map with existing pothole markers color-coded by priority. Tapping the floating action button opens a report dialog with image capture and location pinning. On submission, Flutter sends a `POST /report` to the FastAPI backend. The backend's Jurisdiction Resolver calculates haversine distance from the GPS coordinates to 40+ Malaysian local authority reference points, selecting the nearest. The AI Service Layer sends the image to Gemini 2.5 Flash, which returns structured JSON with severity classification, priority assignment, and repair estimates in under 3 seconds. The complete report is stored and the citizen sees a success confirmation.

**The contractor workflow:** Contractors access a dashboard with filterable report lists, an interactive map, and an analytics tab. Clicking "In Progress" or "Finish Job" on a report card sends a `PATCH /report/{id}` that timestamps the status transition. The analytics tab computes KPI cards and charts client-side from report data, and the Gemini AI Insights panel fires four parallel calls to Flash Lite for executive summary, trend analysis, priority recommendations, and jurisdiction scorecards — rendered progressively as each completes.

**Why this structure:** The frontend and backend are decoupled because AI processing must happen server-side (API keys cannot be exposed client-side), both portals need shared data access through the same API, and the REST interface is client-agnostic — it serves the web app today and can serve a mobile app or government integration tomorrow without backend changes.

---

## Implementation Details

### AI Pipeline — From Photo to Actionable Report

The core innovation is a multi-stage AI pipeline that converts a single citizen photograph into a complete infrastructure report:

1. **Image intake:** Citizen captures or uploads a photo. Flutter converts it to base64 and sends it with GPS coordinates to the backend.
2. **Jurisdiction resolution:** The backend calculates haversine distance to all 40+ Malaysian local authorities and assigns the nearest one. Citizens never need to know which department manages their road.
3. **Gemini Vision analysis:** The image is sent to Gemini 2.5 Flash with a structured prompt requesting a specific JSON schema — `is_pothole`, `size_category` (Small/Medium/Large), `priority_color` (Red/Yellow/Green), `estimated_dimensions`, `repair_recommendation`, and `estimated_duration`.
4. **Defensive parsing:** The response passes through a three-layer parsing pipeline — markdown stripping (regex removes ` ```json ``` ` wrappers), field normalization (title-case enforcement, value validation), and fallback structure (if parsing fails entirely, a conservative default classification is generated rather than returning an error).
5. **Report creation:** The parsed classification is combined with citizen input and jurisdiction data into a complete report with timestamped status history.

### Analytics Intelligence — Four Parallel AI Insight Streams

The contractor analytics tab features a Gemini AI Insights panel that generates four distinct analytical outputs from live report data:

- **Executive Summary:** Total reports, resolution rate, overdue count, average report age, highlights, and actionable recommendations.
- **Trend Analysis:** Overall direction assessment (Improving/Stable/Worsening), emerging hotspot detection with jurisdiction-level severity ratings, and positive trends.
- **Priority Recommendations:** A ranked table of the top 10 potholes to fix, with columns for rank, report ID, jurisdiction, priority, and urgency. Each row is expandable to show AI reasoning and estimated impact.
- **Jurisdiction Scorecards:** Letter grades (A through F) for each local authority based on resolution rate, response time, and overdue count — with specific improvement suggestions.

All four sections load progressively with animated shimmer skeletons and a live progress counter (1/4, 2/4, 3/4, 4/4), delivering content within seconds rather than making the user wait for a single monolithic response.

---

## Innovation — What Makes PotSoft Unique

**Zero-knowledge reporting.** Citizens need to know nothing — not which department, not how big the pothole is, not what form to fill. One photo, one tap. No existing Malaysian solution offers this.

**Dual-portal architecture.** PotSoft serves both sides of the repair pipeline from one platform. SISPAA takes complaints but provides no contractor prioritization. Waze flags hazards but has no connection to repair authorities. PotSoft bridges both.

**AI-native prioritization.** The system tells contractors which pothole to fix first and why — considering severity, age, clustering, jurisdiction workload, and estimated impact. Every existing system processes complaints chronologically.

**Jurisdiction accountability.** No existing Malaysian platform grades local authority performance. PotSoft's AI scorecards create transparent, data-driven accountability with specific improvement suggestions.

**Progressive AI streaming.** Four parallel Gemini calls render results as each completes rather than making the user wait for all four — a modern AI UX pattern applied to infrastructure analytics.

---

## Challenges Faced

### Gemini Response Parsing Reliability

The most significant technical challenge was getting Gemini 2.5 Flash to reliably return parseable JSON. Three failure modes caused problems: markdown wrapping (40% of responses wrapped in ` ```json ``` `), inconsistent field values ("small" vs "Small" vs "SMALL"), and non-pothole images returning prose instead of JSON. We solved this through prompt engineering in AI Studio (20+ variations tested), combined with a three-layer backend defense — markdown regex stripping, field normalization, and a fallback classification structure. Parsing success went from approximately 60% to 100% across 50+ test images.

### Free-Tier Quota Management

During development, the Gemini free-tier rate limit was hit repeatedly. A single "Generate AI Report" click fires four parallel calls. If a citizen submits a photo simultaneously, that is five calls in under 2 seconds. We solved this by splitting workload across two models — Flash for vision, Flash Lite for analytics — effectively doubling available quota. This architectural decision was driven by a real constraint encountered during testing, not theoretical optimization.

### Desktop vs Mobile UI Expectations

User testing revealed that the citizen portal felt like "a phone app stretched to desktop." The edge-to-edge bottom button and floating status pills lacked the spatial hierarchy desktop users expected. We redesigned with a pill-shaped floating action button, structured dark panels with consistent padding, and anchored layout components — validated in a second round of testing where layout complaints disappeared entirely.

---

## Future Roadmap

### Phase 1: Production Foundation (Months 1–12)

- Migrate to Firebase Firestore for persistent data storage and real-time synchronization.
- Add Firebase Authentication for contractor accounts while keeping citizen reporting anonymous.
- Integrate Firebase Cloud Messaging for citizen push notifications on report status changes.
- Deploy Flutter mobile app to Android and iOS from the existing codebase.
- Pilot with 2–3 local councils in Perak and Kuala Lumpur, targeting 500+ reports in 6 months.

### Phase 2: National Scale with Government Integration (Months 13–36)

- Integrate with SISPAA government portal as an AI triage layer for road complaints.
- Build multi-channel intake connectors for Facebook, WhatsApp, phone, and existing council platforms.
- Add AI-powered duplicate detection using GPS proximity and image similarity.
- Partner with highway concessionaires (PLUS, ANIH, Gamuda) for toll road maintenance.
- Introduce predictive maintenance using historical data and weather patterns to anticipate pothole formation before it occurs.
- Infrastructure Diversification: Evolves from a niche pothole solution into a general-purpose municipal platform (addressing streetlights, drainage, signage, etc.).
- National Standardization: Aims to become the official AI backbone for all 149 local authorities across Malaysia, creating a unified standard for infrastructure management.

### Technical Scaling Path

The current architecture scales with minimal changes. Flutter compiles to mobile from the existing codebase. FastAPI containerizes to Google Cloud Run for auto-scaling. The in-memory store migrates to Firestore through a single service-layer file replacement. Gemini quota scales through billing configuration. The jurisdiction resolver expands by adding data entries, not code changes. Every component was designed to be independently upgradable.
