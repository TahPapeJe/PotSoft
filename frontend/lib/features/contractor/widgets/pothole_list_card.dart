import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/pothole_report.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_toast.dart';
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
    final pc = AppColors.priorityColor(report.priorityColor);
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
                    padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
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
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(report.status),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Subtitle: jurisdiction · timestamp
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 13,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                report.jurisdiction,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '|',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.access_time,
                              size: 13,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo(report.timestamp),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        if (isOverdue) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 13,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Action buttons — real buttons
                        if (!isFinished) ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 10),
                          // "Finish Job" as prominent full-width button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                context.read<ReportProvider>().updateStatus(
                                  report.id,
                                  'Finished',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  AppToast.status(
                                    '${report.id} → Finished ✓',
                                    AppColors.statusFinished,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                              ),
                              label: const Text(
                                'FINISH JOB',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          if (report.status != 'In Progress') ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.read<ReportProvider>().updateStatus(
                                    report.id,
                                    'In Progress',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    AppToast.status(
                                      '${report.id} → In Progress 🚧',
                                      AppColors.statusInProgress,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.construction,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                label: const Text(
                                  'In Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
