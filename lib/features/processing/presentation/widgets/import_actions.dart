import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ImportActions extends StatelessWidget {
  final VoidCallback? onImportDocument;
  final VoidCallback? onPickImage;
  final VoidCallback? onScanDocument;

  const ImportActions({
    super.key,
    this.onImportDocument,
    this.onPickImage,
    this.onScanDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: context.l10n.importDocument,
          icon: Assets.icons.document.svg(),
          variant: AppButtonVariant.primary,
          onPressed: onImportDocument,
        ),
        const SizedBox(height: Insets.small),
        AppButton(
          label: context.l10n.pickImageFromGallery,
          icon: Assets.icons.image.svg(),
          variant: AppButtonVariant.secondary,
          onPressed: onPickImage,
        ),
        const SizedBox(height: Insets.small),
        AppButton(
          label: context.l10n.scanDocument,
          icon: Assets.icons.scan.svg(),
          variant: AppButtonVariant.transparent,
          onPressed: onScanDocument,
        ),
      ],
    );
  }
}

