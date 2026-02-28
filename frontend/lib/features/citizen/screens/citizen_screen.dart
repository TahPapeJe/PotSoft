import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/services/marker_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../widgets/report_pothole_dialog.dart';

class CitizenScreen extends StatefulWidget {
  const CitizenScreen({super.key});

  @override
  State<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends State<CitizenScreen> {
  // ─── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final MarkerService _markers = MarkerService();
  double _currentZoom = kDefaultZoom;

  double _lat = kMalaysiaCenter.lat;
  double _long = kMalaysiaCenter.lng;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _markers.init().then((_) {
      if (mounted) setState(() {});
    });
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

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(top: 0, left: 0, right: 0, child: _buildAppBar()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            right: 24,
            child: _buildStatusPanel(),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 28,
            left: 0,
            right: 0,
            child: Center(child: _buildReportFab()),
          ),
        ],
      ),
    );
  }

  // ─── Map ──────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final markers = _markers.buildClusteredMarkers(
          reports: provider.reports,
          currentZoom: _currentZoom,
          onSingleTap: (report) {
            // Citizen uses native info window — no custom tooltip
          },
          onClusterTap: (lat, lng, targetZoom) {
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: LatLng(lat, lng), zoom: targetZoom),
              ),
            );
          },
        );

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_lat, _long),
            zoom: kDefaultZoom,
          ),
          onMapCreated: (controller) => _mapController = controller,
          style: kDarkMapStyle,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onCameraMove: (pos) {
            final zoomChanged = (_currentZoom - pos.zoom).abs() > 0.5;
            _currentZoom = pos.zoom;
            if (zoomChanged) setState(() {});
          },
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
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.accent,
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
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Citizen Portal',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Status panel (anchored top-right) ────────────────────────────────────
  Widget _buildStatusPanel() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final reports = provider.reports;
        final total = reports.length;
        final pending = reports
            .where((r) => r.status != 'In Progress' && r.status != 'Finished')
            .length;
        final inProgress = reports
            .where((r) => r.status == 'In Progress')
            .length;
        final finished = reports.where((r) => r.status == 'Finished').length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppDecorations.darkPanel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 14,
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$total reports on map',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.borderSubtle),
              ),
              const Text(
                'STATUS',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              _legendRow(AppColors.statusPending, 'Pending', pending),
              _legendRow(AppColors.statusInProgress, 'In Progress', inProgress),
              _legendRow(AppColors.statusFinished, 'Finished', finished),
            ],
          ),
        );
      },
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pill FAB (bottom-center) ─────────────────────────────────────────────
  Widget _buildReportFab() {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(28),
      elevation: 8,
      shadowColor: AppColors.accent.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) =>
                ReportPotholeDialog(initialLat: _lat, initialLong: _long),
          );
        },
        borderRadius: BorderRadius.circular(28),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 22, color: Colors.black),
              SizedBox(width: 10),
              Text(
                'Report a Pothole',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
