import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/models/pothole_report.dart';
import '../widgets/report_pothole_dialog.dart';

class CitizenScreen extends StatefulWidget {
  const CitizenScreen({super.key});

  @override
  State<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends State<CitizenScreen> {
  // ─── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerIcons = {};

  double _lat = 4.2;
  double _long = 109.5;

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
    _fetchLocation();
  }

  // ─── Location ─────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) {
          setState(() {
            _lat = position.latitude;
            _long = position.longitude;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(_lat, _long), 14),
          );
        }
      }
    } catch (_) {}
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

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(top: 0, left: 0, right: 0, child: _buildAppBar()),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel()),
        ],
      ),
    );
  }

  // ─── Map ──────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final markers = provider.reports.map((report) {
          return Marker(
            markerId: MarkerId(report.id),
            position: LatLng(report.userLat, report.userLong),
            icon: _getMarkerIcon(report),
            infoWindow: InfoWindow(
              title: '${report.sizeCategory} Pothole',
              snippet: 'Status: ${report.status}  •  ${report.jurisdiction}',
            ),
          );
        }).toSet();

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_lat, _long),
            zoom: 5,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          style: _mapStyle,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        );
      },
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 14,
            left: 20,
            right: 20,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.tealAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PotSoft',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Citizen Portal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Consumer<ReportProvider>(
                builder: (context, provider, _) {
                  final total = provider.reports.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          size: 14,
                          color: Colors.white60,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$total on map',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom panel ─────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<ReportProvider>(
                builder: (context, provider, _) {
                  final reports = provider.reports;
                  final pending = reports
                      .where(
                        (r) =>
                            r.status != 'In Progress' && r.status != 'Finished',
                      )
                      .length;
                  final inProgress = reports
                      .where((r) => r.status == 'In Progress')
                      .length;
                  final finished = reports
                      .where((r) => r.status == 'Finished')
                      .length;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _legendChip('Pending', '$pending', Colors.redAccent),
                        _legendChip(
                          'In Progress',
                          '$inProgress',
                          Colors.orange,
                        ),
                        _legendChip('Finished', '$finished', Colors.cyan),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ReportPotholeDialog(
                        initialLat: _lat,
                        initialLong: _long,
                      ),
                    );
                  },
                  icon: const Icon(Icons.warning_amber_rounded, size: 22),
                  label: const Text(
                    'REPORT A POTHOLE',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
