# PotSoft Frontend

Flutter web application with two portals: a citizen-facing map for reporting potholes and a contractor dashboard for triaging and managing repairs.

---

## Prerequisites

- Flutter SDK 3.11 or later
- Chrome (for web development)
- The PotSoft backend running at `http://localhost:8000` (see `backend/README.md`)

## Setup

```bash
cd frontend
flutter pub get
```

## Running

```bash
flutter run -d chrome
```

To point at a different backend URL:

```bash
flutter run -d chrome --dart-define=API_URL=https://your-api.run.app
```

## Routes

| Path         | Screen               | Description                                  |
| ------------ | -------------------- | -------------------------------------------- |
| `/`          | Citizen Portal       | Map view, report FAB, status panel           |
| `/dashboard` | Contractor Dashboard | Split-panel with sidebar, analytics, and map |

## Features

### Citizen Portal (`/`)

- Full-screen dark-mode Google Map centred on the user's location (geolocation API).
- Floating "Report a Pothole" button opens a modal with camera/gallery image picker and a draggable location pin.
- Status panel showing pending, in-progress, and finished counts.
- Priority-coded markers with status badges and automatic clustering at low zoom levels.

### Contractor Dashboard (`/dashboard`)

- Password-gated access (prototype passcode: `admin123`).
- Left sidebar with two views:
  - **Reports** -- searchable, filterable list of all reports. Priority and sort controls. Quick-action buttons to mark reports as In Progress or Finished.
  - **Analytics** -- response time KPIs, priority distribution donut chart, status and size bar charts, jurisdiction breakdown, recent activity feed.
- Right panel is an interactive map with custom dual-colour markers (priority fill + status badge), dark tooltips on tap, and a detail dialog with full report info and action buttons.
- App bar shows live stats and a refresh button.

## Architecture

```
lib/
  main.dart                          App entry point, Provider setup
  routing/
    app_router.dart                  GoRouter with / and /dashboard routes
  core/
    models/
      pothole_report.dart            PotholeReport data class
    providers/
      report_provider.dart           ChangeNotifier managing report state
    services/
      api_service.dart               HTTP client for the backend API
      marker_service.dart            Shared Google Maps marker and clustering service
    theme/
      app_theme.dart                 Material theme configuration
      design_tokens.dart             Centralised colours, map style, decorations
    widgets/
      app_toast.dart                 Unified dark floating toast/snackbar
  features/
    citizen/
      screens/
        citizen_screen.dart          Citizen portal main screen
      widgets/
        report_pothole_dialog.dart   Report submission dialog
    contractor/
      screens/
        contractor_screen.dart       Contractor dashboard main screen
      widgets/
        contractor_sidebar.dart      Reports list + analytics panel
        contractor_helpers.dart      Time formatting, image helpers, section header
        pothole_list_card.dart       Individual report list card
        secure_gate_widget.dart      Full-screen auth overlay
```

## Key Dependencies

| Package               | Purpose                              |
| --------------------- | ------------------------------------ |
| `provider`            | State management                     |
| `go_router`           | Declarative routing                  |
| `google_maps_flutter` | Interactive maps with custom markers |
| `geolocator`          | GPS location for citizen portal      |
| `image_picker`        | Camera and gallery image selection   |
| `http`                | REST API communication               |

## Design System

All colours, surfaces, and shared styles are defined in `lib/core/theme/design_tokens.dart`:

- `AppColors` -- brand accent, surface variants, priority colours (Red/Yellow/Green), status colours, text hierarchy, border hierarchy.
- `kDarkMapStyle` -- single dark-mode Google Maps style JSON used across all screens.
- `AppDecorations` -- reusable panel decoration factory.

The marker system (`MarkerService`) renders priority-coloured circles with optional status badges, pre-built at init time for smooth map performance. Cluster icons use the same teal accent as the brand.

Toasts (`AppToast`) use a compact dark floating style with coloured borders for success, error, info, and status-update variants.

## Notes

- The backend URL defaults to `http://localhost:8000`. Override it with the `API_URL` dart-define at build time.
- Google Maps requires an API key configured in `web/index.html`.
- The contractor passcode is hardcoded for the prototype. Replace with proper auth for production.
