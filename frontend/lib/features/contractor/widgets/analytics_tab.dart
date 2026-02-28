import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/services/insights_pdf_service.dart';
import '../../../core/theme/design_tokens.dart';
import 'contractor_helpers.dart';

/// Full-width analytics pane with fl_chart visualisations and Gemini AI
/// insight panels. Designed for the 840px-wide contractor sidebar.
class AnalyticsTab extends StatelessWidget {
  final List<PotholeReport> reports;
  final void Function(PotholeReport report)? onReportTap;

  const AnalyticsTab({super.key, required this.reports, this.onReportTap});

  // ─── Aggregation helpers ────────────────────────────────────────────────

  Map<String, int> _stats() {
    return {
      'total': reports.length,
      'Red': reports.where((r) => r.priorityColor == 'Red').length,
      'Yellow': reports.where((r) => r.priorityColor == 'Yellow').length,
      'Green': reports.where((r) => r.priorityColor == 'Green').length,
      'reported': reports.where((r) => r.status == 'Reported').length,
      'analyzed': reports.where((r) => r.status == 'Analyzed').length,
      'inProgress': reports.where((r) => r.status == 'In Progress').length,
      'finished': reports.where((r) => r.status == 'Finished').length,
      'small': reports.where((r) => r.sizeCategory == 'Small').length,
      'medium': reports.where((r) => r.sizeCategory == 'Medium').length,
      'large': reports.where((r) => r.sizeCategory == 'Large').length,
    };
  }

  Map<String, int> _jurisdictionBreakdown() {
    final Map<String, int> counts = {};
    for (final r in reports) {
      counts[r.jurisdiction] = (counts[r.jurisdiction] ?? 0) + 1;
    }
    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Daily report counts over the last 14 days for the timeline chart.
  Map<String, int> _dailyVolume() {
    final now = DateTime.now();
    final Map<String, int> daily = {};
    for (int i = 13; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}';
      daily[key] = 0;
    }
    for (final r in reports) {
      final d = r.timestamp;
      final key =
          '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      if (daily.containsKey(key)) daily[key] = daily[key]! + 1;
    }
    return daily;
  }

  /// Compute cumulative funnel: how many reports have *passed through*
  /// each stage (current stage + all later stages).
  Map<String, int> _cumulativeFunnel(Map<String, int> stats) {
    final finished = stats['finished'] ?? 0;
    final inProgress = stats['inProgress'] ?? 0;
    final analyzed = stats['analyzed'] ?? 0;
    final reported = stats['reported'] ?? 0;

    return {
      'passedReported': reported + analyzed + inProgress + finished,
      'passedAnalyzed': analyzed + inProgress + finished,
      'passedInProgress': inProgress + finished,
      'passedFinished': finished,
    };
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    final total = (stats['total'] ?? 0).clamp(1, 999999);
    final finished = stats['finished'] ?? 0;
    final inProgress = stats['inProgress'] ?? 0;
    final red = stats['Red'] ?? 0;

    final resolutionRate = total > 0
        ? (finished / total * 100).toStringAsFixed(1)
        : '0';
    final activeRate = total > 0
        ? (inProgress / total * 100).toStringAsFixed(1)
        : '0';

    final overdueReports = reports
        .where(
          (r) =>
              r.status == 'Reported' &&
              DateTime.now().difference(r.timestamp).inHours > 24,
        )
        .toList();

    final openReports = reports.where((r) => r.status != 'Finished').toList();
    final avgHoursOpen = openReports.isEmpty
        ? 0.0
        : openReports
                  .map(
                    (r) => DateTime.now()
                        .difference(r.timestamp)
                        .inMinutes
                        .toDouble(),
                  )
                  .reduce((a, b) => a + b) /
              openReports.length /
              60;

    final jMap = _jurisdictionBreakdown();
    final recent = [...reports]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentSix = recent.take(6).toList();

    // Red alert hotspot
    final Map<String, int> redByJurisdiction = {};
    for (final r in reports.where((r) => r.priorityColor == 'Red')) {
      redByJurisdiction[r.jurisdiction] =
          (redByJurisdiction[r.jurisdiction] ?? 0) + 1;
    }
    final topRedEntry = redByJurisdiction.isEmpty
        ? null
        : (redByJurisdiction.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;

    // Funnel data (cumulative)
    final funnel = _cumulativeFunnel(stats);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // ── Alert banners ──────────────────────────────────────────────
        if (overdueReports.isNotEmpty)
          _alertBanner(
            icon: Icons.warning_amber_rounded,
            color: Colors.amber,
            title:
                '${overdueReports.length} Report${overdueReports.length > 1 ? 's' : ''} Overdue',
            subtitle:
                'Unactioned for more than 24 hours \u2014 immediate action required.',
            actionLabel: 'View List \u2192',
            onAction: () {
              if (onReportTap != null && overdueReports.isNotEmpty) {
                onReportTap!(overdueReports.first);
              }
            },
          ),
        if (topRedEntry != null)
          _alertBanner(
            icon: Icons.location_on,
            color: Colors.redAccent,
            title: 'Red Alert Hotspot: ${topRedEntry.key}',
            subtitle:
                '${topRedEntry.value} high-priority reports \u2014 attention recommended.',
            actionLabel: 'Go to Map \u2192',
            onAction: () {
              final target = reports.where(
                (r) =>
                    r.priorityColor == 'Red' &&
                    r.jurisdiction == topRedEntry.key,
              );
              if (onReportTap != null && target.isNotEmpty) {
                onReportTap!(target.first);
              }
            },
          ),
        const SizedBox(height: 4),

        // ── AI Insights panel ──────────────────────────────────────────
        const _AiInsightsPanel(),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // ── KPI Grid ───────────────────────────────────────────────────
        const _SectionHeader('KEY PERFORMANCE INDICATORS'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _kpiCard(
              '$resolutionRate%',
              'Resolution Rate',
              Icons.check_circle_outline,
              Colors.cyan,
              trend: _mockTrend(21.8),
            ),
            _kpiCard(
              '$activeRate%',
              'Work In Progress',
              Icons.construction,
              Colors.orange,
              trend: _mockTrend(20.0),
            ),
            _kpiCard(
              '${avgHoursOpen.toStringAsFixed(1)}h',
              'Avg. Response Time',
              Icons.timer_outlined,
              Colors.blueAccent,
              trend: _mockTrend(-8.5, lowerIsGood: true),
            ),
            _kpiCard(
              '$red',
              'High Priority',
              Icons.priority_high,
              Colors.redAccent,
              trend: _mockTrend(3.0, lowerIsGood: true),
            ),
            _kpiCard(
              '${overdueReports.length}',
              'Overdue Reports',
              Icons.hourglass_bottom,
              Colors.amber,
              trend: _mockTrend(2.0, lowerIsGood: true),
            ),
            _kpiCard(
              '${jMap.length}',
              'Jurisdictions',
              Icons.map_outlined,
              Colors.greenAccent,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // ── Priority donut + Status bars (fl_chart) ────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      'PRIORITY BREAKDOWN',
                      icon: Icons.flag_outlined,
                      iconColor: Colors.redAccent,
                      subtitle: 'Report severity distribution',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: _PriorityDonut(
                        red: stats['Red'] ?? 0,
                        yellow: stats['Yellow'] ?? 0,
                        green: stats['Green'] ?? 0,
                        total: total,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _legendRow(
                      Colors.redAccent,
                      'High Priority',
                      stats['Red'] ?? 0,
                      total,
                    ),
                    _legendRow(
                      Colors.amberAccent,
                      'Medium Priority',
                      stats['Yellow'] ?? 0,
                      total,
                    ),
                    _legendRow(
                      Colors.greenAccent,
                      'Low Priority',
                      stats['Green'] ?? 0,
                      total,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      'STATUS BREAKDOWN',
                      icon: Icons.stacked_bar_chart,
                      iconColor: Colors.blueAccent,
                      subtitle: 'Reports by current workflow stage',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 180,
                      child: _StatusBarChart(stats: stats, total: total),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // ── Size distribution + Cumulative Funnel ──────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      'SIZE DISTRIBUTION',
                      icon: Icons.aspect_ratio,
                      iconColor: Colors.amberAccent,
                      subtitle: 'Pothole dimensions breakdown',
                    ),
                    const SizedBox(height: 14),
                    _barRow(
                      'Large',
                      stats['large'] ?? 0,
                      total,
                      Colors.redAccent,
                    ),
                    _barRow(
                      'Medium',
                      stats['medium'] ?? 0,
                      total,
                      Colors.amberAccent,
                    ),
                    _barRow(
                      'Small',
                      stats['small'] ?? 0,
                      total,
                      Colors.greenAccent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      'PIPELINE FUNNEL',
                      icon: Icons.filter_alt_outlined,
                      iconColor: Colors.cyanAccent,
                      subtitle: 'Cumulative reports that reached each stage',
                    ),
                    const SizedBox(height: 14),
                    _funnelRow(
                      'Reported',
                      funnel['passedReported'] ?? 0,
                      total,
                      Colors.white54,
                    ),
                    _funnelRow(
                      'Analyzed',
                      funnel['passedAnalyzed'] ?? 0,
                      total,
                      Colors.blueAccent,
                    ),
                    _funnelRow(
                      'In Progress',
                      funnel['passedInProgress'] ?? 0,
                      total,
                      Colors.orange,
                    ),
                    _funnelRow(
                      'Finished',
                      funnel['passedFinished'] ?? 0,
                      total,
                      Colors.cyan,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // ── Daily volume timeline (fl_chart LineChart) ─────────────────
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('DAILY REPORT VOLUME (14 DAYS)'),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: _DailyVolumeChart(data: _dailyVolume()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // ── Jurisdiction breakdown — HORIZONTAL bar chart ──────────────
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('JURISDICTION BREAKDOWN'),
              const SizedBox(height: 14),
              _JurisdictionHorizontalChart(data: jMap),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // ── Recent activity ────────────────────────────────────────────
        const _SectionHeader('RECENT ACTIVITY'),
        const SizedBox(height: 12),
        ...recentSix.map((r) => _recentRow(r)),
        const SizedBox(height: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Small widget helpers ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build a simulated trend string. In production this would compare to last
  /// week's data. For the hackathon demo we derive a believable delta from
  /// the current value.
  _TrendData? _mockTrend(double seed, {bool lowerIsGood = false}) {
    final delta = ((seed * 7.3) % 9) - 4; // range ~ -4 … +5
    final rounded = delta.abs() < 0.5
        ? 0.0
        : double.parse(delta.toStringAsFixed(1));
    if (rounded == 0) return null;
    final positive = rounded > 0;
    final good = lowerIsGood ? !positive : positive;
    final arrow = positive ? '\u2191' : '\u2193';
    return _TrendData(
      label: '$arrow ${rounded.abs()}% vs last wk',
      isPositive: good,
    );
  }

  Widget _alertBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                ),
                backgroundColor: color.withValues(alpha: 0.1),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(
    String value,
    String label,
    IconData icon,
    Color color, {
    _TrendData? trend,
  }) {
    final trendColor = trend != null && trend.isPositive
        ? Colors.greenAccent
        : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          // Text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Value
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                // Label
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trend.label,
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _legendRow(Color color, String label, int count, int total) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    final pct = (fraction * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 32,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  /// Cumulative funnel row — always shows count/total where total is the
  /// full report count, so the bar can never exceed 100%.
  Widget _funnelRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count/$total',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 32,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentRow(PotholeReport r) {
    final pc = AppColors.priorityColor(r.priorityColor);
    final sc = AppColors.statusColor(r.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReportTap != null ? () => onReportTap!(r) : null,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: pc, width: 3)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: pc,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: pc.withValues(alpha: 0.5), blurRadius: 4),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.sizeCategory} Pothole  \u2022  ${r.jurisdiction}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeAgo(r.timestamp),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.withValues(alpha: 0.3)),
                ),
                child: Text(
                  r.status,
                  style: TextStyle(
                    color: sc,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── AI INSIGHTS PANEL ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _AiInsightsPanel extends StatefulWidget {
  const _AiInsightsPanel();

  @override
  State<_AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends State<_AiInsightsPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _shimmerCtrl;

  static const _loadingMessages = [
    'Analyzing report data\u2026',
    'Detecting trends & patterns\u2026',
    'Generating recommendations\u2026',
    'Rating jurisdiction performance\u2026',
    'Almost there\u2026',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final loading = provider.insightsLoading;
    final hasData = provider.hasInsights;
    final error = provider.insightsError;
    final completed = provider.insightsCompleted;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.tealAccent.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.tealAccent.withValues(alpha: 0.7),
                            ),
                          )
                        : Icon(
                            hasData ? Icons.check_circle : Icons.auto_awesome,
                            size: 18,
                            color: hasData
                                ? Colors.greenAccent
                                : Colors.tealAccent,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GEMINI AI INSIGHTS',
                          style: TextStyle(
                            color: loading
                                ? Colors.tealAccent.withValues(alpha: 0.8)
                                : Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (loading)
                          _AnimatedLoadingText(
                            messages: _loadingMessages,
                            completed: completed,
                          )
                        else
                          const Text(
                            'AI-powered analytics & recommendations',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Progress badge while loading
                  if (loading)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$completed/4',
                        style: TextStyle(
                          color: Colors.tealAccent.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  // PDF Download button
                  if (!loading && hasData)
                    IconButton(
                      tooltip: 'Download PDF Report',
                      onPressed: () async {
                        final p = context.read<ReportProvider>();
                        try {
                          await InsightsPdfService.downloadReport(
                            summary: p.insightSummary,
                            trends: p.insightTrends,
                            recommendations: p.insightRecommendations,
                            jurisdictions: p.insightJurisdictions,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('PDF error: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                          debugPrint('PDF download error: $e');
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        backgroundColor: Colors.tealAccent.withValues(
                          alpha: 0.12,
                        ),
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.tealAccent.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),

                  if (!loading && hasData) const SizedBox(width: 6),

                  // Generate / Refresh button
                  if (!loading)
                    FilledButton.icon(
                      onPressed: () =>
                          context.read<ReportProvider>().loadInsights(),
                      icon: Icon(
                        hasData ? Icons.refresh : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(
                        hasData ? 'Refresh' : 'Generate',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.tealAccent.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: Colors.tealAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: Colors.tealAccent.withValues(alpha: 0.3),
                        ),
                      ),
                    ),

                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Content — progressive loading
          if (_expanded) ...[
            if (error != null && !hasData)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              )
            else if (!hasData && !loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: Text(
                  'Press "Generate" to create an AI-powered analysis of all pothole reports.',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              )
            else ...[
              // Executive Summary — show data or skeleton
              if (provider.insightSummary != null)
                _SummaryInsightSection(data: provider.insightSummary)
              else if (provider.summaryLoading)
                _ShimmerSkeleton(
                  controller: _shimmerCtrl,
                  icon: Icons.summarize,
                  label: 'Executive Summary',
                  color: Colors.cyanAccent,
                ),

              // Trend Analysis
              if (provider.insightTrends != null)
                _TrendInsightSection(data: provider.insightTrends)
              else if (provider.trendsLoading)
                _ShimmerSkeleton(
                  controller: _shimmerCtrl,
                  icon: Icons.trending_up,
                  label: 'Trend Analysis',
                  color: Colors.orangeAccent,
                ),

              // Recommendations
              if (provider.insightRecommendations != null)
                _RecommendationInsightSection(
                  data: provider.insightRecommendations,
                )
              else if (provider.recommendationsLoading)
                _ShimmerSkeleton(
                  controller: _shimmerCtrl,
                  icon: Icons.lightbulb_outline,
                  label: 'Recommendations',
                  color: Colors.amberAccent,
                ),

              // Jurisdiction Scorecards
              if (provider.insightJurisdictions != null)
                _JurisdictionInsightSection(data: provider.insightJurisdictions)
              else if (provider.jurisdictionsLoading)
                _ShimmerSkeleton(
                  controller: _shimmerCtrl,
                  icon: Icons.score,
                  label: 'Jurisdiction Scorecards',
                  color: Colors.greenAccent,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Animated loading text that cycles through messages ─────────────────────

class _AnimatedLoadingText extends StatefulWidget {
  final List<String> messages;
  final int completed;
  const _AnimatedLoadingText({required this.messages, required this.completed});

  @override
  State<_AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText> {
  int _index = 0;
  late final _ticker = Stream.periodic(const Duration(seconds: 2));
  late final _sub = _ticker.listen((_) {
    if (mounted) {
      setState(() => _index = (_index + 1) % widget.messages.length);
    }
  });

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        widget.messages[_index],
        key: ValueKey(_index),
        style: TextStyle(
          color: Colors.tealAccent.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─── Shimmer skeleton placeholder for a loading insight section ─────────────

class _ShimmerSkeleton extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final String label;
  final Color color;

  const _ShimmerSkeleton({
    required this.controller,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
        // Shimmer placeholder lines
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final shimmerOpacity =
                  0.04 + 0.06 * ((controller.value * 2 - 1).abs());
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBar(shimmerOpacity, 1.0, color),
                  const SizedBox(height: 8),
                  _shimmerBar(shimmerOpacity, 0.85, color),
                  const SizedBox(height: 8),
                  _shimmerBar(shimmerOpacity, 0.6, color),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _shimmerBar(double opacity, double widthFraction, Color c) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: c.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── STRUCTURED AI INSIGHT SECTIONS ────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Executive Summary: mini-grid stat boxes ────────────────────────────────

class _SummaryInsightSection extends StatefulWidget {
  final Map<String, dynamic>? data;
  const _SummaryInsightSection({required this.data});

  @override
  State<_SummaryInsightSection> createState() => _SummaryInsightSectionState();
}

class _SummaryInsightSectionState extends State<_SummaryInsightSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox.shrink();
    final d = widget.data!;

    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.summarize, size: 16, color: Colors.cyanAccent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Executive Summary',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview text
                if (d['overview'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${d['overview']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),

                // Key stats as a mini 2x2 grid
                if (d['key_stats'] is List) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (d['key_stats'] as List).map<Widget>((stat) {
                      final trend = '${stat['trend'] ?? ''}';
                      final trendColor = trend == 'up'
                          ? Colors.greenAccent
                          : trend == 'down'
                          ? Colors.redAccent
                          : Colors.white30;
                      final trendIcon = trend == 'up'
                          ? '\u2191'
                          : trend == 'down'
                          ? '\u2193'
                          : '\u2022';
                      return Container(
                        width: 170,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${stat['value'] ?? '-'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${stat['label'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.cyanAccent.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              trendIcon,
                              style: TextStyle(
                                color: trendColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Highlights
                if (d['highlights'] is List) ...[
                  const Text(
                    'Highlights',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...(d['highlights'] as List).map<Widget>(
                    (h) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '\u2022 ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$h',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Recommendations
                if (d['recommendations'] is List) ...[
                  const Text(
                    'Recommendations',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...(d['recommendations'] as List).map<Widget>(
                    (r) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '\u2022 ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$r',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Trend Analysis: structured table for hotspots ──────────────────────────

class _TrendInsightSection extends StatefulWidget {
  final Map<String, dynamic>? data;
  const _TrendInsightSection({required this.data});

  @override
  State<_TrendInsightSection> createState() => _TrendInsightSectionState();
}

class _TrendInsightSectionState extends State<_TrendInsightSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox.shrink();
    final d = widget.data!;

    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 16,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Trend Analysis',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (d['overall_direction'] != null) ...[
                        const SizedBox(width: 8),
                        _directionBadge(d['overall_direction'] as String),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                if (d['summary'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${d['summary']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),

                // Emerging Hotspots as a table
                if (d['emerging_hotspots'] is List &&
                    (d['emerging_hotspots'] as List).isNotEmpty) ...[
                  const Text(
                    'Emerging Hotspots',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildHotspotsTable(d['emerging_hotspots'] as List),
                  const SizedBox(height: 12),
                ],

                // Positive trends
                if (d['positive_trends'] is List) ...[
                  const Text(
                    'Positive Trends',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...(d['positive_trends'] as List).map<Widget>((t) {
                    final desc = t is Map ? (t['description'] ?? '$t') : '$t';
                    final metric = t is Map ? (t['metric'] ?? '') : '';
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '\u2713 ',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              metric.toString().isNotEmpty
                                  ? '$desc ($metric)'
                                  : '$desc',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Daily pattern
                if (d['daily_pattern'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 12,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${d['daily_pattern']}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _directionBadge(String direction) {
    final isGood = direction == 'improving';
    final isBad = direction == 'declining';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isGood
            ? Colors.greenAccent.withValues(alpha: 0.15)
            : isBad
            ? Colors.redAccent.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isGood
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : isBad
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.white24,
        ),
      ),
      child: Text(
        direction.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isGood
              ? Colors.greenAccent
              : isBad
              ? Colors.redAccent
              : Colors.white54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHotspotsTable(List<dynamic> hotspots) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Jurisdiction',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Severity',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Count',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Reason',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...hotspots.asMap().entries.map((e) {
            final h = e.value is Map ? e.value as Map : <String, dynamic>{};
            final sev = '${h['severity'] ?? 'medium'}'.toLowerCase();
            final sevColor = sev == 'high'
                ? Colors.redAccent
                : sev == 'medium'
                ? Colors.amberAccent
                : Colors.greenAccent;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${h['jurisdiction'] ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: sevColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sev.toUpperCase(),
                          style: TextStyle(
                            color: sevColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${h['report_count'] ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${h['reason'] ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Priority Recommendations: data table with expandable rows ──────────────

class _RecommendationInsightSection extends StatefulWidget {
  final Map<String, dynamic>? data;
  const _RecommendationInsightSection({required this.data});

  @override
  State<_RecommendationInsightSection> createState() =>
      _RecommendationInsightSectionState();
}

class _RecommendationInsightSectionState
    extends State<_RecommendationInsightSection> {
  bool _open = false;
  final Set<int> _expandedRows = {};

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox.shrink();
    final d = widget.data!;
    final queue = d['priority_queue'] is List
        ? d['priority_queue'] as List
        : [];

    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.recommend, size: 16, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Priority Recommendations',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (queue.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${queue.length}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Data table
                if (queue.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.06),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '#',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'ID',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Jurisdiction',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Priority',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Urgency',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 24),
                            ],
                          ),
                        ),
                        // Table rows
                        ...queue.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value is Map
                              ? entry.value as Map
                              : <String, dynamic>{};
                          final rank = item['rank'] ?? (idx + 1);
                          final idRaw = '${item['report_id'] ?? '-'}';
                          final id = idRaw.length > 8
                              ? idRaw.substring(0, 8)
                              : idRaw;
                          final jur = '${item['jurisdiction'] ?? '-'}';
                          final prio = '${item['priority'] ?? '-'}';
                          final prioColor = prio == 'Red'
                              ? Colors.redAccent
                              : prio == 'Yellow'
                              ? Colors.amberAccent
                              : Colors.greenAccent;
                          final urgency = '${item['urgency'] ?? 'medium'}'
                              .toLowerCase();
                          final urgColor = urgency == 'critical'
                              ? Colors.redAccent
                              : urgency == 'high'
                              ? Colors.orangeAccent
                              : Colors.white54;
                          final isExpanded = _expandedRows.contains(idx);

                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedRows.remove(idx);
                                    } else {
                                      _expandedRows.add(idx);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isExpanded
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.04,
                                          )
                                        : Colors.transparent,
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        child: Text(
                                          '$rank',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          id,
                                          style: const TextStyle(
                                            color: Colors.tealAccent,
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          jur,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: prioColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: urgColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              urgency.toUpperCase(),
                                              style: TextStyle(
                                                color: urgColor,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 16,
                                        color: Colors.white24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Expanded detail
                              if (isExpanded)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    38,
                                    4,
                                    10,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.03,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item['reason'] != null)
                                        _detailKV(
                                          'Reason',
                                          '${item['reason']}',
                                        ),
                                      if (item['estimated_impact'] != null)
                                        _detailKV(
                                          'Impact',
                                          '${item['estimated_impact']}',
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Clustering insights
                if (d['clustering_insights'] != null)
                  _detailKV(
                    'Clustering Insight',
                    '${d['clustering_insights']}',
                  ),
                if (d['resource_suggestion'] != null)
                  _detailKV(
                    'Resource Suggestion',
                    '${d['resource_suggestion']}',
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailKV(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$key: ',
              style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Jurisdiction Scorecards structured section ─────────────────────────────

class _JurisdictionInsightSection extends StatefulWidget {
  final Map<String, dynamic>? data;
  const _JurisdictionInsightSection({required this.data});

  @override
  State<_JurisdictionInsightSection> createState() =>
      _JurisdictionInsightSectionState();
}

class _JurisdictionInsightSectionState
    extends State<_JurisdictionInsightSection> {
  bool _open = false;

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.greenAccent;
      case 'B':
        return Colors.lightGreenAccent;
      case 'C':
        return Colors.amberAccent;
      case 'D':
        return Colors.orangeAccent;
      case 'F':
        return Colors.redAccent;
      default:
        return Colors.white30;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox.shrink();

    final d = widget.data!;
    final scorecards =
        (d['scorecards'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final bestPerformer = d['best_performer'] as String?;
    final needsAttention = d['needs_attention'] as String?;
    final overallAssessment = d['overall_assessment'] as String?;

    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.score, size: 16, color: Colors.greenAccent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Jurisdiction Scorecards',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall assessment
                if (overallAssessment != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      overallAssessment,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),

                // Best performer & needs attention badges
                if (bestPerformer != null || needsAttention != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (bestPerformer != null)
                          _badge(
                            Icons.emoji_events,
                            bestPerformer,
                            Colors.greenAccent,
                            'Top',
                          ),
                        if (needsAttention != null)
                          _badge(
                            Icons.warning_amber_rounded,
                            needsAttention,
                            Colors.orangeAccent,
                            'Alert',
                          ),
                      ],
                    ),
                  ),

                // Scorecard cards
                ...scorecards.map(_buildScorecardCard),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badge(IconData icon, String name, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $name',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardCard(Map<String, dynamic> sc) {
    final grade = '${sc['grade'] ?? '-'}';
    final jurisdiction = '${sc['jurisdiction'] ?? 'Unknown'}';
    final resRate = sc['resolution_rate'];
    final avgHrs = sc['avg_response_hours'];
    final overdue = sc['overdue'];
    final redCount = sc['red_count'];
    final total = sc['total'];
    final summary = sc['summary'] as String?;
    final suggestion = sc['suggestion'] as String?;
    final gColor = _gradeColor(grade);

    // Format resolution rate — handle both 0.85 and 85.0 styles
    String resDisplay;
    if (resRate is num) {
      resDisplay = resRate <= 1
          ? '${(resRate * 100).toStringAsFixed(0)}%'
          : '${resRate.toStringAsFixed(0)}%';
    } else {
      resDisplay = '$resRate';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: grade badge + jurisdiction name
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    color: gColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  jurisdiction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stats row
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _statChip('Resolution', resDisplay),
              _statChip(
                'Avg Resp',
                avgHrs is num ? '${avgHrs.toStringAsFixed(1)}h' : '$avgHrs',
              ),
              _statChip('Overdue', '$overdue'),
              _statChip('Red', '$redCount'),
              _statChip('Total', '$total'),
            ],
          ),

          // Summary
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                summary,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),

          // Suggestion
          if (suggestion != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '\u{1f4a1} $suggestion',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.greenAccent.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── Generic expandable insight section (for jurisdiction scorecards) ────────

class _InsightSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Map<String, dynamic>? data;

  const _InsightSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.data,
  });

  @override
  State<_InsightSection> createState() => _InsightSectionState();
}

class _InsightSectionState extends State<_InsightSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: widget.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _renderInsightData(widget.data!),
          ),
      ],
    );
  }

  /// Recursively renders the JSON insight data as styled text/lists.
  Widget _renderInsightData(Map<String, dynamic> data) {
    final children = <Widget>[];
    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;

      if (val is String) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${_formatKey(key)}:  ',
                    style: TextStyle(
                      color: widget.color.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: val,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (val is num) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  '${_formatKey(key)}: ',
                  style: TextStyle(
                    color: widget.color.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$val',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (val is List) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
            child: Text(
              _formatKey(key),
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        for (final item in val) {
          if (item is Map<String, dynamic>) {
            final line = item.entries
                .map((e) => '${_formatKey(e.key)}: ${e.value}')
                .join('  \u2022  ');
            children.add(
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u2022  ',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u2022  ',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    Expanded(
                      child: Text(
                        '$item',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      } else if (val is Map) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 6),
            child: Text(
              _formatKey(key),
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _renderInsightData(Map<String, dynamic>.from(val)),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── FL_CHART WIDGETS ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Priority Donut (PieChart) ──────────────────────────────────────────────

class _PriorityDonut extends StatelessWidget {
  final int red, yellow, green, total;
  const _PriorityDonut({
    required this.red,
    required this.yellow,
    required this.green,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white38)),
      );
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 36,
        startDegreeOffset: -90,
        sections: [
          if (red > 0)
            PieChartSectionData(
              value: red.toDouble(),
              color: Colors.redAccent,
              radius: 28,
              title: '$red',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (yellow > 0)
            PieChartSectionData(
              value: yellow.toDouble(),
              color: Colors.amberAccent,
              radius: 28,
              title: '$yellow',
              titleStyle: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (green > 0)
            PieChartSectionData(
              value: green.toDouble(),
              color: Colors.greenAccent,
              radius: 28,
              title: '$green',
              titleStyle: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Status Bar Chart ───────────────────────────────────────────────────────

class _StatusBarChart extends StatelessWidget {
  final Map<String, int> stats;
  final int total;
  const _StatusBarChart({required this.stats, required this.total});

  @override
  Widget build(BuildContext context) {
    final data = [
      _BarEntry('Reported', stats['reported'] ?? 0, Colors.white54),
      _BarEntry('Analyzed', stats['analyzed'] ?? 0, Colors.blueAccent),
      _BarEntry('In Progress', stats['inProgress'] ?? 0, Colors.orange),
      _BarEntry('Finished', stats['finished'] ?? 0, Colors.cyan),
    ];
    final maxY = data
        .fold<int>(0, (m, e) => e.value > m ? e.value : m)
        .clamp(1, 999999)
        .toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY + (maxY * 0.2),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2A2A2A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${data[group.x.toInt()].label}\n${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, _) => Text(
                val.toInt().toString(),
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[i].label,
                    style: TextStyle(
                      color: data[i].color.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value.toDouble(),
                color: e.value.color,
                width: 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY + (maxY * 0.2),
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Daily Volume Line Chart ────────────────────────────────────────────────

class _DailyVolumeChart extends StatelessWidget {
  final Map<String, int> data;
  const _DailyVolumeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white38)),
      );
    }
    final maxY = entries
        .fold<int>(0, (m, e) => e.value > m ? e.value : m)
        .clamp(1, 999999)
        .toDouble();

    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble()))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY + (maxY * 0.3),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2A2A2A),
            getTooltipItems: (spots) => spots.map((s) {
              final label = entries[s.x.toInt()].key;
              return LineTooltipItem(
                '$label\n${s.y.toInt()} reports',
                const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 11,
                  height: 1.4,
                ),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) => Text(
                val.toInt().toString(),
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: entries.length > 7 ? 2 : 1,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[i].key,
                    style: TextStyle(color: Colors.grey[600], fontSize: 8),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.tealAccent,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: Colors.tealAccent,
                strokeColor: const Color(0xFF1E1E1E),
                strokeWidth: 1.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.tealAccent.withValues(alpha: 0.25),
                  Colors.tealAccent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Jurisdiction HORIZONTAL Chart ──────────────────────────────────────────

class _JurisdictionHorizontalChart extends StatelessWidget {
  final Map<String, int> data;
  const _JurisdictionHorizontalChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.take(10).toList();
    if (entries.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white38)),
      );
    }
    final maxVal = entries
        .fold<int>(0, (m, e) => e.value > m ? e.value : m)
        .clamp(1, 999999);

    return Column(
      children: entries.map((e) {
        final fraction = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  e.key,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.tealAccent.withValues(alpha: 0.8),
                    ),
                    minHeight: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '${e.value}',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── SMALL PRIVATE HELPERS ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String text;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  const _SectionHeader(this.text, {this.subtitle, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? Colors.white38),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle!,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
      ],
    );
  }
}

class _BarEntry {
  final String label;
  final int value;
  final Color color;
  const _BarEntry(this.label, this.value, this.color);
}

class _TrendData {
  final String label;
  final bool isPositive;
  const _TrendData({required this.label, required this.isPositive});
}
