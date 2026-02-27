import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/theme/design_tokens.dart';
import 'contractor_helpers.dart';
import 'pothole_list_card.dart';

/// Width constants used by both the sidebar and parent screen.
const double kReportsWidth = 420.0;
const double kAnalyticsWidth = 840.0;
const double kNavRailWidth = 64.0;

/// The left panel of the Contractor Dashboard.
///
/// Renders a 64px vertical nav rail + a content pane. Fires [onWidthChanged]
/// when the user switches between Reports (420px) and Analytics (840px).
class ContractorSidebar extends StatefulWidget {
  final ValueChanged<bool> onShowActiveOnlyChanged;
  final void Function(PotholeReport report) onReportTap;
  final ValueChanged<double> onWidthChanged;

  const ContractorSidebar({
    super.key,
    required this.onShowActiveOnlyChanged,
    required this.onReportTap,
    required this.onWidthChanged,
  });

  @override
  State<ContractorSidebar> createState() => _ContractorSidebarState();
}

class _ContractorSidebarState extends State<ContractorSidebar> {
  // Nav state
  int _selectedNav = 0; // 0 = Reports, 1 = Analytics

  // Filter / Sort state
  String _selectedPriority = 'All';
  String _sortMode = 'priority';
  String _searchQuery = '';
  bool _showActiveOnly = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _switchNav(int index) {
    if (_selectedNav == index) return;
    setState(() => _selectedNav = index);
    widget.onWidthChanged(index == 0 ? kReportsWidth : kAnalyticsWidth);
  }

  // Filtering + sorting
  List<PotholeReport> _applyFilters(List<PotholeReport> all) {
    List<PotholeReport> filtered = all.where((r) {
      if (_selectedPriority != 'All' && r.priorityColor != _selectedPriority) {
        return false;
      }
      if (_showActiveOnly && r.status == 'Finished') return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return r.jurisdiction.toLowerCase().contains(q) ||
            r.sizeCategory.toLowerCase().contains(q) ||
            r.priorityColor.toLowerCase().contains(q) ||
            r.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    if (_sortMode == 'priority') {
      const order = {'Red': 0, 'Yellow': 1, 'Green': 2};
      filtered.sort(
        (a, b) => (order[a.priorityColor] ?? 3).compareTo(
          order[b.priorityColor] ?? 3,
        ),
      );
    } else {
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return filtered;
  }

  // Analytics helpers
  Map<String, int> _computeStats(List<PotholeReport> reports) {
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

  Map<String, int> _jurisdictionBreakdown(List<PotholeReport> reports) {
    final Map<String, int> counts = {};
    for (final r in reports) {
      counts[r.jurisdiction] = (counts[r.jurisdiction] ?? 0) + 1;
    }
    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  // Build
  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final allReports = provider.reports;
        final filtered = _applyFilters(allReports);

        return Row(
          children: [
            _buildNavRail(),
            const VerticalDivider(width: 1, color: Colors.white10),
            Expanded(
              child: _selectedNav == 0
                  ? _buildReportsPane(filtered)
                  : _buildAnalyticsPane(allReports),
            ),
          ],
        );
      },
    );
  }

  // Nav rail
  Widget _buildNavRail() {
    return Container(
      width: kNavRailWidth,
      color: const Color(0xFF0F0F0F),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _navItem(0, Icons.list_alt_rounded, 'Reports'),
          const SizedBox(height: 8),
          _navItem(1, Icons.bar_chart_rounded, 'Analytics'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _selectedNav == index;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: () => _switchNav(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.tealAccent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? Colors.tealAccent : Colors.white38,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: active ? Colors.tealAccent : Colors.white38,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: active ? 20 : 0,
                decoration: BoxDecoration(
                  color: Colors.tealAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reports pane
  Widget _buildReportsPane(List<PotholeReport> filtered) {
    return Column(
      children: [
        _buildFilterSortBar(),
        Expanded(child: _buildReportList(filtered)),
      ],
    );
  }

  // Filter + Sort bar
  Widget _buildFilterSortBar() {
    const chipFilters = [
      ('All', 'All'),
      ('Red', 'Red'),
      ('Yellow', 'Yellow'),
      ('Green', 'Green'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search reports...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Colors.tealAccent,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Priority segmented filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: chipFilters.map((entry) {
                final val = entry.$1;
                final lbl = entry.$2;
                final selected = _selectedPriority == val;
                final color = AppColors.priorityColor(val);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: color.withValues(alpha: 0.5))
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Center(
                        child: Text(
                          lbl,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: selected ? color : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Sort + Active Only row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: _filterToggleButton(
                  icon: _sortMode == 'priority'
                      ? Icons.priority_high
                      : Icons.access_time,
                  label: _sortMode == 'priority' ? 'By Priority' : 'By Time',
                  active: false,
                  activeColor: Colors.white70,
                  onTap: () => setState(
                    () => _sortMode = _sortMode == 'priority'
                        ? 'time'
                        : 'priority',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterToggleButton(
                  icon: _showActiveOnly
                      ? Icons.visibility
                      : Icons.visibility_off,
                  label: 'Active Only',
                  active: _showActiveOnly,
                  activeColor: Colors.tealAccent,
                  onTap: () {
                    setState(() => _showActiveOnly = !_showActiveOnly);
                    widget.onShowActiveOnlyChanged(_showActiveOnly);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _filterToggleButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active
          ? activeColor.withValues(alpha: 0.12)
          : const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.4)
                  : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? activeColor : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? activeColor : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Report list
  Widget _buildReportList(List<PotholeReport> reports) {
    if (reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: Colors.white24, size: 40),
            SizedBox(height: 8),
            Text(
              'No reports match this filter.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      itemCount: reports.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PotholeListCard(
          report: reports[index],
          onTap: () => widget.onReportTap(reports[index]),
        ),
      ),
    );
  }

  // Analytics pane
  Widget _buildAnalyticsPane(List<PotholeReport> reports) {
    final jMap = _jurisdictionBreakdown(reports);
    final stats = _computeStats(reports);
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

    final recent = [...reports]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentSix = recent.take(6).toList();

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

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Alert banners
        if (overdueReports.isNotEmpty)
          _alertBanner(
            icon: Icons.warning_amber_rounded,
            color: Colors.amber,
            title:
                '${overdueReports.length} Report${overdueReports.length > 1 ? 's' : ''} Overdue',
            subtitle:
                'Unactioned for more than 24 hours — immediate action required.',
          ),
        if (topRedEntry != null)
          _alertBanner(
            icon: Icons.location_on,
            color: Colors.redAccent,
            title: 'Red Alert Hotspot: ${topRedEntry.key}',
            subtitle:
                '${topRedEntry.value} high-priority reports — attention recommended.',
          ),
        const SizedBox(height: 4),

        // KPI Grid
        const _SectionHeader('KEY PERFORMANCE INDICATORS'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard(
              '$resolutionRate%',
              'Resolution Rate',
              Icons.check_circle_outline,
              Colors.cyan,
            ),
            _kpiCard(
              '$activeRate%',
              'Work In Progress',
              Icons.construction,
              Colors.orange,
            ),
            _kpiCard(
              '${avgHoursOpen.toStringAsFixed(1)}h',
              'Avg. Response Time',
              Icons.timer_outlined,
              Colors.blueAccent,
            ),
            _kpiCard(
              '$red',
              'High Priority',
              Icons.priority_high,
              Colors.redAccent,
            ),
            _kpiCard(
              '${overdueReports.length}',
              'Overdue Reports',
              Icons.hourglass_bottom,
              Colors.amber,
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

        // Two-column: Priority Donut + Status bars in cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _analyticsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('PRIORITY BREAKDOWN'),
                    const SizedBox(height: 14),
                    Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            segments: [
                              _DonutSegment(
                                value: (stats['Red'] ?? 0).toDouble(),
                                color: Colors.redAccent,
                              ),
                              _DonutSegment(
                                value: (stats['Yellow'] ?? 0).toDouble(),
                                color: Colors.amberAccent,
                              ),
                              _DonutSegment(
                                value: (stats['Green'] ?? 0).toDouble(),
                                color: Colors.greenAccent,
                              ),
                            ],
                            total: total.toDouble(),
                          ),
                          child: Center(
                            child: Text(
                              '$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _donutLegendRow(
                      Colors.redAccent,
                      'Red (High)',
                      stats['Red'] ?? 0,
                      total,
                    ),
                    _donutLegendRow(
                      Colors.amberAccent,
                      'Yellow (Med)',
                      stats['Yellow'] ?? 0,
                      total,
                    ),
                    _donutLegendRow(
                      Colors.greenAccent,
                      'Green (Low)',
                      stats['Green'] ?? 0,
                      total,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _analyticsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('STATUS BREAKDOWN'),
                    const SizedBox(height: 12),
                    _buildBarRow(
                      'Reported',
                      stats['reported'] ?? 0,
                      total,
                      Colors.white54,
                    ),
                    _buildBarRow(
                      'Analyzed',
                      stats['analyzed'] ?? 0,
                      total,
                      Colors.blueAccent,
                    ),
                    _buildBarRow(
                      'In Progress',
                      stats['inProgress'] ?? 0,
                      total,
                      Colors.orange,
                    ),
                    _buildBarRow(
                      'Finished',
                      stats['finished'] ?? 0,
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

        // Two-column: Size + Funnel in cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _analyticsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('SIZE DISTRIBUTION'),
                    const SizedBox(height: 12),
                    _buildBarRow(
                      'Large',
                      stats['large'] ?? 0,
                      total,
                      Colors.redAccent,
                    ),
                    _buildBarRow(
                      'Medium',
                      stats['medium'] ?? 0,
                      total,
                      Colors.amberAccent,
                    ),
                    _buildBarRow(
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
              child: _analyticsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('STATUS FUNNEL'),
                    const SizedBox(height: 12),
                    _buildFunnelRow(
                      'Reported \u2192 Analyzed',
                      stats['reported'] ?? 0,
                      stats['analyzed'] ?? 0,
                      Colors.blueAccent,
                    ),
                    _buildFunnelRow(
                      'Analyzed \u2192 In Progress',
                      stats['analyzed'] ?? 0,
                      stats['inProgress'] ?? 0,
                      Colors.orange,
                    ),
                    _buildFunnelRow(
                      'In Progress \u2192 Finished',
                      stats['inProgress'] ?? 0,
                      stats['finished'] ?? 0,
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

        // Jurisdiction breakdown — vertical bar chart
        _analyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('JURISDICTION BREAKDOWN'),
              const SizedBox(height: 14),
              SizedBox(height: 180, child: _buildVerticalBarChart(jMap, total)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // Recent activity
        const _SectionHeader('RECENT ACTIVITY'),
        const SizedBox(height: 12),
        ...recentSix.map((r) => _recentActivityRow(r)),
        const SizedBox(height: 16),
      ],
    );
  }

  // Analytics widgets

  Widget _alertBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
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
        ],
      ),
    );
  }

  Widget _kpiCard(String value, String label, IconData icon, Color color) {
    return Container(
      width: 162,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, int count, int total, Color color) {
    final fraction = count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count  ${(fraction * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelRow(
    String label,
    int fromCount,
    int toCount,
    Color color,
  ) {
    final rate = fromCount > 0
        ? (toCount / fromCount * 100).toStringAsFixed(0)
        : '-';
    final fraction = fromCount > 0
        ? (toCount / fromCount).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$toCount/$fromCount ($rate%)',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }

  // Analytics card wrapper
  Widget _analyticsCard({required Widget child}) {
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

  // Donut legend row
  Widget _donutLegendRow(Color color, String label, int count, int total) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(
            '$count ($pct%)',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Vertical bar chart for jurisdictions
  Widget _buildVerticalBarChart(Map<String, int> data, int total) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white38)),
      );
    }
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    final entries = data.entries.take(8).toList(); // Limit to 8 bars

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = ((constraints.maxWidth - 16) / entries.length).clamp(
          20.0,
          60.0,
        );
        final spacing = entries.length > 1
            ? ((constraints.maxWidth - barWidth * entries.length) /
                      (entries.length - 1))
                  .clamp(4.0, 16.0)
            : 0.0;

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: entries.asMap().entries.map((mapEntry) {
                  final i = mapEntry.key;
                  final e = mapEntry.value;
                  final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < entries.length - 1 ? spacing : 0,
                    ),
                    child: SizedBox(
                      width: barWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${e.value}',
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            height: (fraction * 100).clamp(4.0, 100.0),
                            width: barWidth * 0.7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.tealAccent.withValues(alpha: 0.8),
                                  Colors.tealAccent.withValues(alpha: 0.3),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            // X-axis labels
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: entries.asMap().entries.map((mapEntry) {
                final i = mapEntry.key;
                final e = mapEntry.value;
                final shortLabel = e.key.length > 8
                    ? '${e.key.substring(0, 7)}\u2026'
                    : e.key;
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < entries.length - 1 ? spacing : 0,
                  ),
                  child: SizedBox(
                    width: barWidth,
                    child: Text(
                      shortLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 8),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _recentActivityRow(PotholeReport r) {
    final pc = AppColors.priorityColor(r.priorityColor);
    final sc = AppColors.statusColor(r.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: pc, width: 3)),
      ),
      child: Row(
        children: [
          // Priority color dot instead of text
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
    );
  }
}

// Section header helper widget
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ─── Donut Chart painter ────────────────────────────────────────────────────

class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment({required this.value, required this.color});
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;

  _DonutChartPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 16.0;
    const gapAngle = 0.04; // Small gap between segments

    if (total <= 0) {
      // Empty state: draw a grey ring
      canvas.drawCircle(
        center,
        radius - strokeWidth / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = Colors.white10,
      );
      return;
    }

    double startAngle = -math.pi / 2; // Start from top

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweepAngle = (seg.value / total) * 2 * math.pi - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = seg.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.segments != segments;
  }
}
