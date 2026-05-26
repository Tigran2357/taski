import 'package:flutter/material.dart';

/// Shows a yes/cancel confirmation dialog. Returns true if confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  String title = 'Are you sure?',
  String? message,
  String confirmLabel = 'Yes',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
