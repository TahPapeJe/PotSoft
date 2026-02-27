import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...chipFilters.map((entry) {
                final val = entry.$1;
                final lbl = entry.$2;
                final selected = _selectedPriority == val;
                final color = priorityColor(val);
                return ChoiceChip(
                  label: Text(lbl),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedPriority = val),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.black : Colors.white70,
                  ),
                  selectedColor: color,
                  backgroundColor: const Color(0xFF2A2A2A),
                  side: BorderSide.none,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              }),
              ChoiceChip(
                avatar: Icon(
                  _sortMode == 'priority'
                      ? Icons.priority_high
                      : Icons.access_time,
                  size: 14,
                  color: Colors.white60,
                ),
                label: Text(
                  _sortMode == 'priority' ? 'By Priority' : 'By Time',
                ),
                selected: false,
                onSelected: (_) => setState(
                  () =>
                      _sortMode = _sortMode == 'priority' ? 'time' : 'priority',
                ),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                backgroundColor: const Color(0xFF2A2A2A),
                side: BorderSide.none,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                avatar: Icon(
                  _showActiveOnly ? Icons.visibility : Icons.visibility_off,
                  size: 14,
                  color: _showActiveOnly ? Colors.tealAccent : Colors.white60,
                ),
                label: const Text('Active Only'),
                selected: _showActiveOnly,
                onSelected: (v) {
                  setState(() => _showActiveOnly = v);
                  widget.onShowActiveOnlyChanged(v);
                },
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _showActiveOnly ? Colors.tealAccent : Colors.white70,
                  fontWeight: _showActiveOnly
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                selectedColor: Colors.tealAccent.withValues(alpha: 0.18),
                backgroundColor: const Color(0xFF2A2A2A),
                side: _showActiveOnly
                    ? BorderSide(
                        color: Colors.tealAccent.withValues(alpha: 0.5),
                      )
                    : BorderSide.none,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
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
    final int total =
        ((stats['total'] ?? 0) as num).clamp(1, 999999).toInt();
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

        // Two-column: Priority + Status
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('PRIORITY BREAKDOWN'),
                  const SizedBox(height: 12),
                  _buildBarRow(
                    'Red (High)',
                    stats['Red'] ?? 0,
                    total,
                    Colors.redAccent,
                  ),
                  _buildBarRow(
                    'Yellow (Med)',
                    stats['Yellow'] ?? 0,
                    total,
                    Colors.amberAccent,
                  ),
                  _buildBarRow(
                    'Green (Low)',
                    stats['Green'] ?? 0,
                    total,
                    Colors.greenAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
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
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // Two-column: Size + Funnel
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
            const SizedBox(width: 24),
            Expanded(
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
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),

        // Jurisdiction breakdown — two columns
        const _SectionHeader('JURISDICTION BREAKDOWN'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: jMap.entries
                    .take((jMap.length / 2).ceil())
                    .map(
                      (e) => _buildBarRow(
                        e.key,
                        e.value,
                        total,
                        Colors.tealAccent,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: jMap.entries
                    .skip((jMap.length / 2).ceil())
                    .map(
                      (e) => _buildBarRow(
                        e.key,
                        e.value,
                        total,
                        Colors.tealAccent,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
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
        ? (toCount / fromCount).clamp(0.0, 1.0).toDouble()
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

  Widget _recentActivityRow(PotholeReport r) {
    final pc = priorityColor(r.priorityColor);
    final sc = statusColor(r.status);
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
                  '${r.priorityColor} priority  \u2022  ${timeAgo(r.timestamp)}',
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
