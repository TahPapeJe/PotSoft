import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import '../widgets/contractor_helpers.dart';
import '../widgets/contractor_sidebar.dart';
import '../widgets/secure_gate_widget.dart';

class ContractorScreen extends StatefulWidget {
  const ContractorScreen({super.key});

  @override
  State<ContractorScreen> createState() => _ContractorScreenState();
}

class _ContractorScreenState extends State<ContractorScreen> {
  // ─── Auth ─────────────────────────────────────────────────────────────────
  bool _isAuthenticated = false;
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  // ─── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _showActiveOnly = false;
  double _sidebarWidth = 420.0;

  static const _initialPosition = CameraPosition(
    target: LatLng(4.2, 109.5),
    zoom: 5,
  );

  static const String _mapStyle = '''
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

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _buildMarkerIcons();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────
  void _checkPassword() {
    if (_passwordController.text == 'admin123') {
      setState(() {
        _isAuthenticated = true;
        _errorMessage = '';
      });
    } else {
      setState(() => _errorMessage = 'Incorrect passcode. Please try again.');
    }
  }

  // ─── Markers ──────────────────────────────────────────────────────────────
  Future<void> _buildMarkerIcons() async {
    final entries = {
      'Red': Colors.redAccent,
      'Yellow': Colors.amberAccent,
      'Green': Colors.greenAccent,
      'InProgress': Colors.orange,
      'Finished': Colors.cyan,
    };
    for (final e in entries.entries) {
      _markerIcons[e.key] = await _makeMarkerIcon(e.value);
    }
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _makeMarkerIcon(Color color) async {
    const double size = 56;
    const double r = size * 0.38;
    const Offset center = Offset(size / 2, size * 0.42);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    canvas.drawCircle(
      center.translate(1.5, 1.5),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - 3, Paint()..color = color);
    canvas.drawCircle(
      center,
      5,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  BitmapDescriptor _getMarkerIcon(PotholeReport report) {
    if (report.status == 'Finished') {
      return _markerIcons['Finished'] ?? BitmapDescriptor.defaultMarker;
    }
    if (report.status == 'In Progress') {
      return _markerIcons['InProgress'] ?? BitmapDescriptor.defaultMarker;
    }
    return _markerIcons[report.priorityColor] ?? BitmapDescriptor.defaultMarker;
  }

  String _markerSnippet(PotholeReport report) {
    switch (report.status) {
      case 'In Progress':
        return 'In Progress - ${report.sizeCategory}';
      case 'Finished':
        return 'Fixed - ${report.sizeCategory}';
      default:
        return '${report.priorityColor} priority - ${report.sizeCategory}';
    }
  }

  void _flyToReport(PotholeReport report) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(report.userLat, report.userLong),
          zoom: 16,
        ),
      ),
    );
  }

  // ─── Report Details Dialog ────────────────────────────────────────────────
  void _showReportDetails(BuildContext context, PotholeReport report) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ReportProvider>(
        builder: (ctx, provider, _) {
          final fresh = provider.reports.firstWhere(
            (r) => r.id == report.id,
            orElse: () => report,
          );
          final pc = priorityColor(fresh.priorityColor);
          final sc = statusColor(fresh.status);

          return Dialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: pc.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border(
                        bottom: BorderSide(color: pc.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: pc,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: pc.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${fresh.priorityColor.toUpperCase()} - ${fresh.sizeCategory} Pothole',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sc.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sc.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            fresh.status,
                            style: TextStyle(
                              color: sc,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Image
                  ClipRRect(child: reportImage(fresh.imageFile, height: 180)),
                  // Details
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(
                          Icons.straighten,
                          'Size',
                          fresh.sizeCategory,
                        ),
                        _detailRow(
                          Icons.location_on_outlined,
                          'Location',
                          '${fresh.userLat.toStringAsFixed(5)}, ${fresh.userLong.toStringAsFixed(5)}',
                        ),
                        _detailRow(
                          Icons.business_outlined,
                          'Jurisdiction',
                          fresh.jurisdiction,
                        ),
                        _detailRow(
                          Icons.timer_outlined,
                          'Est. Duration',
                          fresh.estimatedDuration,
                        ),
                        _detailRow(
                          Icons.access_time_outlined,
                          'Reported',
                          timeAgo(fresh.timestamp),
                        ),
                        _detailRow(Icons.tag, 'Report ID', fresh.id),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 12),
                        const Text(
                          'UPDATE STATUS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                icon: Icons.construction,
                                label: 'IN PROGRESS',
                                color: Colors.orange,
                                enabled:
                                    fresh.status != 'In Progress' &&
                                    fresh.status != 'Finished',
                                onPressed: () {
                                  provider.updateStatus(
                                    fresh.id,
                                    'In Progress',
                                  );
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    buildSnackBar(
                                      'Report ${fresh.id} marked as In Progress',
                                      Colors.orange,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                icon: Icons.check_circle_outline,
                                label: 'FINISH JOB',
                                color: Colors.cyan,
                                enabled: fresh.status != 'Finished',
                                onPressed: () {
                                  provider.updateStatus(fresh.id, 'Finished');
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    buildSnackBar(
                                      'Report ${fresh.id} marked as Finished',
                                      Colors.cyan,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 8),
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    if (!enabled) {
      return FilledButton.tonal(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, letterSpacing: 0.8),
            ),
          ],
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, letterSpacing: 0.8),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color.computeLuminance() > 0.4
            ? Colors.black
            : Colors.white,
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white10),
        ),
        title: Row(
          children: const [
            Icon(Icons.construction, color: Colors.tealAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'PotSoft',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.tealAccent,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Contractor Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<ReportProvider>(
            builder: (context, provider, _) {
              final reports = provider.reports;
              final total = reports.length;
              final red = reports.where((r) => r.priorityColor == 'Red').length;
              final yellow = reports
                  .where((r) => r.priorityColor == 'Yellow')
                  .length;
              final green = reports
                  .where((r) => r.priorityColor == 'Green')
                  .length;
              final inProgress = reports
                  .where((r) => r.status == 'In Progress')
                  .length;
              final finished = reports
                  .where((r) => r.status == 'Finished')
                  .length;

              Widget chip(String count, String label, Color color) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        count,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.70),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  chip('$total', 'Total', Colors.white60),
                  chip('$red', 'Red', Colors.redAccent),
                  chip('$yellow', 'Yellow', Colors.amberAccent),
                  chip('$green', 'Green', Colors.greenAccent),
                  chip('$inProgress', 'In Progress', Colors.orange),
                  chip('$finished', 'Finished', Colors.cyan),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // ── Left Panel ────────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                width: _sidebarWidth,
                decoration: const BoxDecoration(
                  color: Color(0xFF141414),
                  border: Border(right: BorderSide(color: Colors.white10)),
                ),
                child: ContractorSidebar(
                  onShowActiveOnlyChanged: (v) =>
                      setState(() => _showActiveOnly = v),
                  onWidthChanged: (w) => setState(() => _sidebarWidth = w),
                  onReportTap: (report) {
                    _flyToReport(report);
                    _showReportDetails(context, report);
                  },
                ),
              ),
              // ── Right Panel – Map ─────────────────────────────────────────
              Expanded(
                child: Consumer<ReportProvider>(
                  builder: (context, provider, _) {
                    final markers = provider.reports
                        .map(
                          (report) => Marker(
                            markerId: MarkerId(report.id),
                            position: LatLng(report.userLat, report.userLong),
                            icon: _getMarkerIcon(report),
                            infoWindow: InfoWindow(
                              title:
                                  '${report.sizeCategory} - ${report.jurisdiction}',
                              snippet: _markerSnippet(report),
                            ),
                            onTap: () => _showReportDetails(context, report),
                          ),
                        )
                        .toSet();

                    final mapMarkers = _showActiveOnly
                        ? markers.where((m) {
                            final r = provider.reports.firstWhere(
                              (r) => r.id == m.markerId.value,
                              orElse: () => provider.reports.first,
                            );
                            return r.status != 'Finished';
                          }).toSet()
                        : markers;

                    return Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: _initialPosition,
                          style: _mapStyle,
                          onMapCreated: (ctrl) {
                            _mapController = ctrl;
                          },
                          markers: mapMarkers,
                          zoomControlsEnabled: true,
                          myLocationButtonEnabled: false,
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _buildMapControls(),
                        ),
                        Positioned(
                          bottom: 24,
                          right: 16,
                          child: _buildMapLegend(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // ── Auth Gate ─────────────────────────────────────────────────────
          if (!_isAuthenticated)
            SecureGateWidget(
              passwordController: _passwordController,
              errorMessage: _errorMessage,
              onSubmit: _checkPassword,
            ),
        ],
      ),
    );
  }

  // ─── Map Controls ─────────────────────────────────────────────────────────
  Widget _buildMapControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mapControlButton(
                icon: _showActiveOnly ? Icons.visibility : Icons.visibility_off,
                label: _showActiveOnly ? 'Active Only' : 'All Reports',
                color: _showActiveOnly ? Colors.tealAccent : Colors.white54,
                onTap: () => setState(() => _showActiveOnly = !_showActiveOnly),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: Colors.white12),
              const SizedBox(width: 8),
              _mapControlButton(
                icon: Icons.zoom_out_map,
                label: 'Fit All',
                color: Colors.white54,
                onTap: () => _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(_initialPosition),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Map Legend ───────────────────────────────────────────────────────────
  Widget _buildMapLegend() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SectionHeader('MAP LEGEND'),
              const SizedBox(height: 8),
              _legendItem(Colors.redAccent, 'Red / High Priority'),
              _legendItem(Colors.amberAccent, 'Yellow / Medium'),
              _legendItem(Colors.greenAccent, 'Green / Low'),
              _legendItem(Colors.orange, 'In Progress 🚧'),
              _legendItem(Colors.cyan, 'Finished / Fixed ✓'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
