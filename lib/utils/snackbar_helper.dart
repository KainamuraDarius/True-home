import 'package:flutter/material.dart';

/// A utility class for showing professional, consistent SnackBars across the app.
class SnackbarHelper {
  static void showError(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context,
      message: message,
      backgroundColor: Colors.red.shade600,
      icon: Icons.error_outline,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showSuccess(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context,
      message: message,
      backgroundColor: Colors.green.shade600,
      icon: Icons.check_circle_outline,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context,
      message: message,
      backgroundColor: Colors.blue.shade600,
      icon: Icons.info_outline,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context,
      message: message,
      backgroundColor: Colors.orange.shade700,
      icon: Icons.warning_amber_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: Colors.white,
              )
            : null,
      ),
    );
  }
}
