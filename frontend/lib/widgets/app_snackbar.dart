import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final color = isError
      ? AppColors.danger
      : isSuccess
      ? AppColors.success
      : AppColors.textPrimary;
  final icon = isError
      ? Icons.error_outline_rounded
      : isSuccess
      ? Icons.check_circle_outline_rounded
      : Icons.info_outline_rounded;

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: color,
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
