import 'package:flutter/material.dart';

/// ─── PotSoft Design Tokens ─────────────────────────────────────────────────
///
/// Centralised color palette, surface helpers, and the shared dark‑mode map
/// style. Every widget should reference these tokens instead of raw literals.
///
/// Usage:
///   color: AppColors.priorityRed
///   decoration: AppDecorations.darkPanel()

// ─── Colors ─────────────────────────────────────────────────────────────────

abstract final class AppColors {
  // Brand
  static const Color accent = Colors.tealAccent;

  // Surfaces
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color surfaceDarker = Color(0xFF121212);
  static const Color surfaceCard = Color(0xFF1A1A1A);
  static const Color surfaceOverlay = Color(0xF0222222);
  static const Color surfaceToast = Color(0xF01E1E1E);

  // Priority (marker fill + legend)
  static const Color priorityRed = Colors.redAccent;
  static const Color priorityYellow = Colors.amberAccent;
  static const Color priorityGreen = Colors.greenAccent;

  // Status
  static const Color statusPending = Colors.white54;
  static const Color statusAnalyzed = Colors.tealAccent;
  static const Color statusInProgress = Colors.orange;
  static const Color statusFinished = Colors.cyan;

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textDim = Colors.white38;
  static const Color textSubtle = Colors.white24;

  // Borders
  static const Color border = Colors.white24;
  static const Color borderSubtle = Colors.white12;
  static const Color borderFaint = Colors.white10;

  /// Returns the [Color] associated with a priority string from the API.
  static Color priorityColor(String priority) {
    switch (priority) {
      case 'Red':
        return priorityRed;
      case 'Yellow':
        return priorityYellow;
      case 'Green':
        return priorityGreen;
      default:
        return statusPending;
    }
  }

  /// Returns the [Color] associated with a status string from the API.
  static Color statusColor(String status) {
    switch (status) {
      case 'In Progress':
        return statusInProgress;
      case 'Finished':
        return statusFinished;
      case 'Analyzed':
        return statusAnalyzed;
      default:
        return statusPending;
    }
  }
}

// ─── Shared Dark Map Style ──────────────────────────────────────────────────

/// The single canonical dark‑mode map style JSON for Google Maps.
const String kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';

// ─── Common Camera Position ─────────────────────────────────────────────────

/// Default camera position centred on Malaysia.
const kMalaysiaCenter = (lat: 4.2, lng: 109.5);
const double kDefaultZoom = 5.0;

// ─── Shared Decorations ─────────────────────────────────────────────────────

abstract final class AppDecorations {
  /// The standard dark overlay panel used by map controls, legends, tooltips.
  static BoxDecoration darkPanel({double radius = 12, Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
