import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// ─── Unified Toast / SnackBar ──────────────────────────────────────────────
///
/// Compact, dark‑themed floating toast matching the Citizen Portal style.
/// Use everywhere instead of the old bright‑background `buildSnackBar`.
///
/// Usage:
///   ScaffoldMessenger.of(context).showSnackBar(
///     AppToast.success('Report submitted!'),
///   );

abstract final class AppToast {
  /// A success toast with a teal accent border and check icon.
  static SnackBar success(String message) => _build(
    message: message,
    icon: Icons.check_circle,
    iconColor: AppColors.textPrimary,
    borderColor: AppColors.accent.withValues(alpha: 0.3),
  );

  /// An error toast with a red accent border and error icon.
  static SnackBar error(String message) => _build(
    message: message,
    icon: Icons.error_outline,
    iconColor: AppColors.priorityRed,
    borderColor: AppColors.priorityRed,
  );

  /// An informational toast with a custom [color] accent.
  static SnackBar info(String message, {Color color = AppColors.accent}) =>
      _build(
        message: message,
        icon: Icons.info_outline,
        iconColor: color,
        borderColor: color.withValues(alpha: 0.4),
      );

  /// A generic status‑update toast (used for "In Progress", "Finished" etc.).
  static SnackBar status(String message, Color color) => _build(
    message: message,
    icon: Icons.check_circle,
    iconColor: color,
    borderColor: color.withValues(alpha: 0.4),
  );

  // ── Private builder ───────────────────────────────────────────────────────

  static SnackBar _build({
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
  }) {
    return SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.surfaceToast,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      width: 380,
      elevation: 8,
      duration: const Duration(seconds: 4),
    );
  }
}
