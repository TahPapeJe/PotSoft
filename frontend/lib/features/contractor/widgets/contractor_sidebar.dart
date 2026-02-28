import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/theme/design_tokens.dart';
import 'analytics_tab.dart';
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
                  : AnalyticsTab(
                      reports: allReports,
                      onReportTap: widget.onReportTap,
                    ),
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
}
