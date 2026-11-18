import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/vision_prescription/vision_prescription.dart';

/// A glasses prescription as printed: one row per eye, one column per
/// value, in plain words. The Add and Prism columns are shown only when an
/// eye has one.
class VisionPrescriptionTable extends StatelessWidget {
  const VisionPrescriptionTable({required this.rows, super.key});

  /// The right eye, then the left ([VisionPrescription.eyeRows]).
  final List<VisionEyeRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final onSurface = context.colorScheme.onSurface;
    final showAdd = rows.any((r) => r.add != null);
    final showPrism = rows.any((r) => r.prism != null);

    final headers = [
      '',
      l10n.visionSphere,
      l10n.visionCylinder,
      l10n.visionAxis,
      if (showAdd) l10n.visionAdd,
      if (showPrism) l10n.visionPrism,
    ];

    Widget cell(String text, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.extraSmall,
        vertical: Insets.small,
      ),
      child: Text(
        text,
        style: (header ? AppTextStyle.labelSmall : AppTextStyle.labelLarge)
            .copyWith(
              color: header ? onSurface.withValues(alpha: 0.7) : onSurface,
              fontWeight: header ? FontWeight.w600 : null,
            ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: Insets.normal),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: context.theme.dividerColor),
        ),
        children: [
          TableRow(
            children: [for (final h in headers) cell(h, header: true)],
          ),
          for (final row in rows)
            TableRow(
              children: [
                cell(
                  row.right ? l10n.visionEyeRight : l10n.visionEyeLeft,
                  header: true,
                ),
                cell(row.sphere ?? '-'),
                cell(row.cylinder ?? '-'),
                cell(row.axis == null ? '-' : '${row.axis}°'),
                if (showAdd) cell(row.add ?? '-'),
                if (showPrism) cell(row.prism ?? '-'),
              ],
            ),
        ],
      ),
    );
  }
}
