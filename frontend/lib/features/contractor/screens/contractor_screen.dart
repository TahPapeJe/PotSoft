import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/services/marker_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_toast.dart';
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
  final MarkerService _markers = MarkerService();
  bool _showActiveOnly = false;
  double _sidebarWidth = 420.0;
  double _currentZoom = kDefaultZoom;

  // Custom tooltip state
  PotholeReport? _tooltipReport;
  Offset? _tooltipOffset;

  static final _initialPosition = CameraPosition(
    target: LatLng(kMalaysiaCenter.lat, kMalaysiaCenter.lng),
    zoom: kDefaultZoom,
  );

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _markers.init().then((_) {
      if (mounted) setState(() {});
    });
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

  // ─── Navigation helpers ───────────────────────────────────────────────────

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
      barrierColor: Colors.transparent,
      builder: (ctx) => Consumer<ReportProvider>(
        builder: (ctx, provider, _) {
          final fresh = provider.reports.firstWhere(
            (r) => r.id == report.id,
            orElse: () => report,
          );
          final pc = AppColors.priorityColor(fresh.priorityColor);
          final sc = AppColors.statusColor(fresh.status);

          return Stack(
            children: [
              // Glassmorphic backdrop
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              // Floating card
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: pc.withValues(alpha: 0.15),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDetailHeader(fresh, pc, sc),
                        ClipRRect(
                          child: reportImage(fresh.imageFile, height: 150),
                        ),
                        _buildDetailGrid(fresh),
                        _buildDetailActions(ctx, provider, fresh),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailHeader(PotholeReport report, Color pc, Color sc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pc.withValues(alpha: 0.12), pc.withValues(alpha: 0.04)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: pc, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.jurisdiction,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sc.withValues(alpha: 0.5)),
                ),
                child: Text(
                  report.status,
                  style: TextStyle(
                    color: sc,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: pc, shape: BoxShape.circle),
              ),
              Text(
                '${report.priorityColor} Priority',
                style: TextStyle(
                  color: pc,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '\u2022',
                style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                '${report.sizeCategory} Pothole',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${report.id.length > 6 ? report.id.substring(0, 6) : report.id}',
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGrid(PotholeReport report) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _detailRow(
                  Icons.straighten,
                  'Size',
                  report.sizeCategory,
                ),
              ),
              Expanded(
                child: _detailRow(
                  Icons.timer_outlined,
                  'Duration',
                  report.estimatedDuration,
                ),
              ),
            ],
          ),
          _detailRow(
            Icons.my_location_outlined,
            'Coords',
            '${report.userLat.toStringAsFixed(5)}, ${report.userLong.toStringAsFixed(5)}',
          ),
          _detailRow(
            Icons.access_time_outlined,
            'Reported',
            timeAgo(report.timestamp),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailActions(
    BuildContext ctx,
    ReportProvider provider,
    PotholeReport report,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              icon: Icons.construction,
              label: 'IN PROGRESS',
              color: AppColors.statusInProgress,
              enabled:
                  report.status != 'In Progress' && report.status != 'Finished',
              onPressed: () {
                provider.updateStatus(report.id, 'In Progress');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  AppToast.status(
                    'Report marked as In Progress',
                    AppColors.statusInProgress,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              icon: Icons.check_circle_outline,
              label: 'FINISH JOB',
              color: AppColors.statusFinished,
              enabled: report.status != 'Finished',
              onPressed: () {
                provider.updateStatus(report.id, 'Finished');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  AppToast.status(
                    'Report marked as Finished',
                    AppColors.statusFinished,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, color: AppColors.textDim, size: 20),
            tooltip: 'Close',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textDim),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textDim, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
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
      backgroundColor: AppColors.surfaceDarker,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Row(
            children: [
              // Left Panel
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                width: _sidebarWidth,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDark,
                  border: Border(
                    right: BorderSide(color: AppColors.borderFaint),
                  ),
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
              // Right Panel – Map
              Expanded(child: _buildMapPanel()),
            ],
          ),
          // Auth Gate
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

  // ─── App Bar ──────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 72,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.borderFaint),
      ),
      title: const Row(
        children: [
          Icon(Icons.construction, color: AppColors.accent, size: 22),
          SizedBox(width: 10),
          Text(
            'PotSoft',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 20,
              color: AppColors.accent,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Contractor Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
      actions: [_buildAppBarStats()],
    );
  }

  Widget _buildAppBarStats() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final reports = provider.reports;
        final total = reports.length;
        final red = reports.where((r) => r.priorityColor == 'Red').length;
        final yellow = reports.where((r) => r.priorityColor == 'Yellow').length;
        final green = reports.where((r) => r.priorityColor == 'Green').length;
        final inProgress = reports
            .where((r) => r.status == 'In Progress')
            .length;
        final finished = reports.where((r) => r.status == 'Finished').length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statChip('$total', 'Total', Colors.white60),
            _statChip('$red', 'Red', AppColors.priorityRed),
            _statChip('$yellow', 'Yellow', AppColors.priorityYellow),
            _statChip('$green', 'Green', AppColors.priorityGreen),
            _statChip('$inProgress', 'Active', AppColors.statusInProgress),
            _statChip('$finished', 'Done', AppColors.statusFinished),
            const SizedBox(width: 6),
            IconButton(
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      color: AppColors.accent,
                      size: 22,
                    ),
              tooltip: 'Refresh reports',
              onPressed: provider.isLoading
                  ? null
                  : () => provider.loadReports(),
            ),
            const SizedBox(width: 10),
          ],
        );
      },
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Map Panel ────────────────────────────────────────────────────────────
  Widget _buildMapPanel() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final visibleReports = _showActiveOnly
            ? provider.reports.where((r) => r.status != 'Finished').toList()
            : provider.reports;

        final mapMarkers = _markers.buildClusteredMarkers(
          reports: visibleReports,
          currentZoom: _currentZoom,
          onSingleTap: (report) async {
            final screenCoord = await _mapController?.getScreenCoordinate(
              LatLng(report.userLat, report.userLong),
            );
            setState(() {
              if (_tooltipReport?.id == report.id) {
                _tooltipReport = null;
                _tooltipOffset = null;
              } else {
                _tooltipReport = report;
                _tooltipOffset = screenCoord != null
                    ? Offset(screenCoord.x.toDouble(), screenCoord.y.toDouble())
                    : null;
              }
            });
          },
          onClusterTap: (lat, lng, targetZoom) {
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: LatLng(lat, lng), zoom: targetZoom),
              ),
            );
          },
        );

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialPosition,
              style: kDarkMapStyle,
              onMapCreated: (ctrl) => _mapController = ctrl,
              markers: mapMarkers,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              onTap: (_) => setState(() {
                _tooltipReport = null;
                _tooltipOffset = null;
              }),
              onCameraMove: (pos) {
                final zoomChanged = (_currentZoom - pos.zoom).abs() > 0.5;
                _currentZoom = pos.zoom;
                if (_tooltipReport != null || zoomChanged) {
                  setState(() {
                    _tooltipReport = null;
                    _tooltipOffset = null;
                  });
                }
              },
            ),
            if (_tooltipReport != null && _tooltipOffset != null)
              _buildDarkTooltip(provider),
            Positioned(top: 12, left: 12, child: _buildMapControls()),
            Positioned(bottom: 24, right: 16, child: _buildMapLegend()),
          ],
        );
      },
    );
  }

  // ─── Dark Tooltip ─────────────────────────────────────────────────────────
  Widget _buildDarkTooltip(ReportProvider provider) {
    final report = _tooltipReport!;
    final fresh = provider.reports.firstWhere(
      (r) => r.id == report.id,
      orElse: () => report,
    );
    final pc = AppColors.priorityColor(fresh.priorityColor);
    final sc = AppColors.statusColor(fresh.status);

    return Positioned(
      left: (_tooltipOffset!.dx - 130).clamp(8, double.infinity),
      top: (_tooltipOffset!.dy - 110).clamp(8, double.infinity),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tooltipReport = null;
            _tooltipOffset = null;
          });
          _showReportDetails(context, fresh);
        },
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceToast,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pc.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: pc,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fresh.jurisdiction,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fresh.status,
                      style: TextStyle(
                        color: sc,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${fresh.sizeCategory} Pothole  \u2022  ${fresh.priorityColor} Priority',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    timeAgo(fresh.timestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    'Tap for details \u203A',
                    style: TextStyle(
                      color: AppColors.accent.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Map Controls ─────────────────────────────────────────────────────────
  Widget _buildMapControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppDecorations.darkPanel(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapControlButton(
            icon: _showActiveOnly ? Icons.visibility : Icons.visibility_off,
            label: _showActiveOnly ? 'Active Only' : 'All Reports',
            color: _showActiveOnly ? AppColors.accent : AppColors.textSecondary,
            onTap: () => setState(() => _showActiveOnly = !_showActiveOnly),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 22, color: AppColors.border),
          const SizedBox(width: 10),
          _mapControlButton(
            icon: Icons.zoom_out_map,
            label: 'Fit All',
            color: AppColors.textSecondary,
            onTap: () => _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(_initialPosition),
            ),
          ),
        ],
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
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Map Legend ────────────────────────────────────────────────────────────
  Widget _buildMapLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppDecorations.darkPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'MAP LEGEND',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Priority',
            style: TextStyle(color: AppColors.textDim, fontSize: 11),
          ),
          const SizedBox(height: 6),
          _legendItem(AppColors.priorityRed, 'High Priority'),
          _legendItem(AppColors.priorityYellow, 'Medium Priority'),
          _legendItem(AppColors.priorityGreen, 'Low Priority'),
          const SizedBox(height: 8),
          const Text(
            'Status',
            style: TextStyle(color: AppColors.textDim, fontSize: 11),
          ),
          const SizedBox(height: 6),
          _legendStatusItem(
            Icons.construction,
            AppColors.statusInProgress,
            'In Progress',
          ),
          _legendStatusItem(
            Icons.check_circle,
            AppColors.statusFinished,
            'Finished',
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
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
        ],
      ),
    );
  }

  Widget _legendStatusItem(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 10, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
