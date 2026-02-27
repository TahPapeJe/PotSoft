import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import 'contractor_helpers.dart';

/// A single report list card showing thumbnail, priority bar,
/// status badge, and quick action buttons.
class PotholeListCard extends StatelessWidget {
  final PotholeReport report;

  /// Called when the card body is tapped — parent should fly the map
  /// to the report coordinates and open the details dialog.
  final VoidCallback onTap;

  const PotholeListCard({super.key, required this.report, required this.onTap});

  // ── Task 2: Soft Badge ─────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    final Color color;
    switch (status) {
      case 'Analyzed':
        color = Colors.blueAccent;
        break;
      case 'In Progress':
        color = Colors.orange;
        break;
      case 'Finished':
        color = Colors.teal;
        break;
      default: // 'Reported' and anything else
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Task 1: Bulletproof thumbnail ─────────────────────────────────────────
  Widget _buildThumbnail(String? imageUrl) {
    const fallback = SizedBox(
      width: 64,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    final bytes = tryBase64Bytes(imageUrl);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 64,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF2A2A2A),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = priorityColor(report.priorityColor);
    final isFinished = report.status == 'Finished';
    final isOverdue =
        report.status == 'Reported' &&
        DateTime.now().difference(report.timestamp).inHours > 24;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Priority color bar ──────────────────────────────────────
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: pc,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),

                // ── Thumbnail ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildThumbnail(report.imageFile),
                ),

                // ── Main content ────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    // Task 4: wider gap on left (thumbnail gap is now 12+12=24),
                    // slight right/top/bottom padding.
                    padding: const EdgeInsets.fromLTRB(0, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title + soft badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${report.sizeCategory} Pothole',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(report.status),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Task 4: subtitle with CrossAxisAlignment.center
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '${report.jurisdiction}  •  ${timeAgo(report.timestamp)}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        if (isOverdue) ...[
                          const SizedBox(height: 4),
                          const Text(
                            '⚠ OVERDUE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],

                        // Task 3: divider + buttons only when not Finished
                        if (!isFinished) ...[
                          const Divider(color: Colors.white12, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (report.status != 'In Progress')
                                TextButton.icon(
                                  onPressed: () {
                                    context.read<ReportProvider>().updateStatus(
                                      report.id,
                                      'In Progress',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      buildSnackBar(
                                        '${report.id} → In Progress 🚧',
                                        Colors.orange,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.construction,
                                    size: 15,
                                    color: Colors.orange,
                                  ),
                                  label: const Text(
                                    'In Progress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: () {
                                  context.read<ReportProvider>().updateStatus(
                                    report.id,
                                    'Finished',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    buildSnackBar(
                                      '${report.id} → Finished ✓',
                                      Colors.cyan,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 15,
                                  color: Colors.cyan,
                                ),
                                label: const Text(
                                  'Finish Job',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.cyan,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
