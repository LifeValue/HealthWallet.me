import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/presentation/widgets/debug_log_sheet.dart';

/// The terminal icon that opens the scan debug log. The log holds patient
/// data, so the icon exists only while [ProcessingLogBuffer] is enabled: in
/// debug and profile builds, never in release builds.
class DebugLogButton extends StatelessWidget {
  const DebugLogButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ProcessingLogBuffer.instance.isEnabled) return const SizedBox.shrink();
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Icons.terminal,
        size: 18,
        color: context.colorScheme.onSurface,
      ),
      onPressed: () => DebugLogSheet.show(context),
    );
  }
}
