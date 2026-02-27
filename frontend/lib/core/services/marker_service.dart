import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pothole_report.dart';
import '../theme/design_tokens.dart';

/// ─── Marker & Clustering Service ───────────────────────────────────────────
///
/// Builds all [BitmapDescriptor] icons used on the Google Map — individually
/// and as cluster bubbles — and implements the simple distance‑based
/// clustering algorithm shared between both portals.
///
/// **Marker system** (from the Contractor side):
///   The marker fill uses the report's *priority* colour (Red / Yellow / Green).
///   If the report's status is "In Progress" or "Finished", a small badge is
///   drawn in the bottom‑right corner showing the corresponding status icon.
///
/// Create once per screen via [init], then reference [getMarkerIcon] /
/// [buildClusteredMarkers].

class MarkerService {
  // Built icons keyed by "<priority>_<statusKey>"
  final Map<String, BitmapDescriptor> _markerIcons = {};

  // Built cluster icons keyed by count (2..20)
  final Map<int, BitmapDescriptor> _clusterIcons = {};

  /// Whether [init] has completed.
  bool get isReady => _markerIcons.isNotEmpty;

  // ─── Initialisation ─────────────────────────────────────────────────────

  /// Pre‑renders all 9 priority×status marker combos + cluster icons 2–20.
  Future<void> init() async {
    await Future.wait([_buildMarkerIcons(), _buildCommonClusterIcons()]);
  }

  Future<void> _buildMarkerIcons() async {
    const priorities = ['Red', 'Yellow', 'Green'];
    const statuses = ['default', 'InProgress', 'Finished'];

    for (final p in priorities) {
      for (final s in statuses) {
        final key = '${p}_$s';
        final pColor = AppColors.priorityColor(p);
        final statusIcon = s == 'InProgress'
            ? Icons.construction
            : s == 'Finished'
            ? Icons.check_circle
            : null;
        final statusClr = s == 'InProgress'
            ? AppColors.statusInProgress
            : s == 'Finished'
            ? AppColors.statusFinished
            : null;
        _markerIcons[key] = await _paintMarkerIcon(
          pColor,
          statusIcon: statusIcon,
          statusColor: statusClr,
        );
      }
    }
  }

  Future<void> _buildCommonClusterIcons() async {
    for (int i = 2; i <= 20; i++) {
      _clusterIcons[i] = await _paintClusterIcon(i);
    }
  }

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Returns the pre‑built marker icon for the given [report].
  BitmapDescriptor getMarkerIcon(PotholeReport report) {
    final p = report.priorityColor; // Red, Yellow, Green
    final s = report.status == 'Finished'
        ? 'Finished'
        : report.status == 'In Progress'
        ? 'InProgress'
        : 'default';
    final key = '${p}_$s';
    return _markerIcons[key] ?? BitmapDescriptor.defaultMarker;
  }

  /// Produces a set of [Marker]s, clustering when [currentZoom] is below
  /// [clusterZoomThreshold]. Single‑report markers fire [onSingleTap];
  /// cluster markers animate the camera to zoom in.
  Set<Marker> buildClusteredMarkers({
    required List<PotholeReport> reports,
    required double currentZoom,
    double clusterZoomThreshold = 10.0,
    required void Function(PotholeReport report) onSingleTap,
    required void Function(double lat, double lng, double targetZoom)
    onClusterTap,
  }) {
    final clusters = _computeClusters(
      reports,
      currentZoom,
      clusterZoomThreshold,
    );
    final Set<Marker> markers = {};

    for (final cluster in clusters) {
      if (cluster.reports.length == 1) {
        final report = cluster.reports.first;
        markers.add(
          Marker(
            markerId: MarkerId(report.id),
            position: LatLng(report.userLat, report.userLong),
            icon: getMarkerIcon(report),
            onTap: () => onSingleTap(report),
          ),
        );
      } else {
        final count = cluster.reports.length.clamp(2, 20);
        final icon = _clusterIcons[count] ?? BitmapDescriptor.defaultMarker;
        markers.add(
          Marker(
            markerId: MarkerId('cluster_${cluster.lat}_${cluster.lng}'),
            position: LatLng(cluster.lat, cluster.lng),
            icon: icon,
            onTap: () =>
                onClusterTap(cluster.lat, cluster.lng, currentZoom + 3),
          ),
        );
      }
    }
    return markers;
  }

  // ─── Painting ───────────────────────────────────────────────────────────

  Future<BitmapDescriptor> _paintMarkerIcon(
    Color color, {
    IconData? statusIcon,
    Color? statusColor,
  }) async {
    const double size = 64;
    const double r = size * 0.38;
    const Offset center = Offset(size / 2, size * 0.42);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // Drop shadow
    canvas.drawCircle(
      center.translate(1.5, 1.5),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    // White border
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    // Priority colour fill
    canvas.drawCircle(center, r - 3, Paint()..color = color);

    if (statusIcon != null && statusColor != null) {
      const badgeR = 9.0;
      final badgeCenter = Offset(center.dx + r * 0.60, center.dy + r * 0.60);
      canvas.drawCircle(
        badgeCenter,
        badgeR + 2,
        Paint()..color = const Color(0xFF121212),
      );
      canvas.drawCircle(badgeCenter, badgeR, Paint()..color = statusColor);

      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(statusIcon.codePoint),
          style: TextStyle(
            fontFamily: statusIcon.fontFamily,
            package: statusIcon.fontPackage,
            fontSize: 11,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(
          badgeCenter.dx - iconPainter.width / 2,
          badgeCenter.dy - iconPainter.height / 2,
        ),
      );
    } else {
      canvas.drawCircle(
        center,
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _paintClusterIcon(int count) async {
    const double size = 72;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    const center = Offset(size / 2, size / 2);
    const radius = size * 0.42;

    // Outer glow
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Dark fill
    canvas.drawCircle(center, radius, Paint()..color = AppColors.surfaceCard);
    // Teal border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.accent,
    );
    // Count text
    final tp = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // ─── Clustering Algorithm ───────────────────────────────────────────────

  List<Cluster> _computeClusters(
    List<PotholeReport> reports,
    double currentZoom,
    double threshold,
  ) {
    if (currentZoom >= threshold || reports.length <= 2) {
      return reports
          .map((r) => Cluster(reports: [r], lat: r.userLat, lng: r.userLong))
          .toList();
    }

    final distThreshold = 2.0 / (currentZoom + 1);
    final List<Cluster> clusters = [];
    final used = <int>{};

    for (int i = 0; i < reports.length; i++) {
      if (used.contains(i)) continue;
      final group = <PotholeReport>[reports[i]];
      used.add(i);

      for (int j = i + 1; j < reports.length; j++) {
        if (used.contains(j)) continue;
        final dx = reports[i].userLat - reports[j].userLat;
        final dy = reports[i].userLong - reports[j].userLong;
        if ((dx * dx + dy * dy) < distThreshold * distThreshold) {
          group.add(reports[j]);
          used.add(j);
        }
      }

      double avgLat = 0, avgLng = 0;
      for (final r in group) {
        avgLat += r.userLat;
        avgLng += r.userLong;
      }
      clusters.add(
        Cluster(
          reports: group,
          lat: avgLat / group.length,
          lng: avgLng / group.length,
        ),
      );
    }
    return clusters;
  }
}

// ─── Cluster model ──────────────────────────────────────────────────────────

class Cluster {
  final List<PotholeReport> reports;
  final double lat;
  final double lng;
  const Cluster({required this.reports, required this.lat, required this.lng});
}
