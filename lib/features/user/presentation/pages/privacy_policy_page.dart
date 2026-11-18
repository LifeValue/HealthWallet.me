import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/bold_markup.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/user/presentation/services/url_launcher.dart';

@RoutePage()
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  /// The date the current policy took effect; shown in the user's language.
  static final _effectiveDate = DateTime(2025, 9, 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicy),
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.normal),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.privacyEffectiveDate(_effectiveDate),
                  style: AppTextStyle.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Insets.normal),

                // Introduction
                _buildParagraph(
                  context,
                  '${l10n.privacyIntro} **HealthWallet.me** '
                  '${l10n.privacyDescription}',
                ),
                const SizedBox(height: Insets.large),

                // Core Principle Section
                _buildSectionTitle(l10n.corePrinciple),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyCorePrincipleBody),
                const SizedBox(height: Insets.medium),
                _buildBulletPoint(context, l10n.privacyNoCloudProcessing),
                _buildBulletPoint(context, l10n.privacyNoDeveloperAccess),
                _buildBulletPoint(context, l10n.privacyYouAreInControl),
                const SizedBox(height: Insets.large),

                // What Information is Handled Section
                _buildSectionTitle(l10n.whatInformationHandled),
                const SizedBox(height: Insets.medium),

                // Information We Do Not Collect
                _buildSubsectionTitle(l10n.informationWeDoNotCollect),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyDoNotCollectIntro),
                const SizedBox(height: Insets.medium),
                _buildBulletPoint(context, l10n.privacyPersonalIdentifiers),
                _buildBulletPoint(context, l10n.privacyHealthInformation),
                _buildBulletPoint(context, l10n.privacyNoCrossReferencing),
                _buildBulletPoint(context, l10n.privacyUsageAnalytics),
                const SizedBox(height: Insets.large),

                // Information You Manage
                _buildSubsectionTitle(l10n.informationYouManage),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyYouManageIntro),
                const SizedBox(height: Insets.medium),

                // Importing Documents
                _buildSubsectionTitle('1. ${l10n.importingDocuments}'),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyImportingIntro),
                const SizedBox(height: Insets.small),
                _buildBulletPoint(context, l10n.privacyScanning),
                _buildBulletPoint(context, l10n.privacyShareActionSheet),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyLocalProcessing),
                const SizedBox(height: Insets.large),

                // Connecting to FastenHealth
                _buildSubsectionTitle('2. ${l10n.connectingFastenHealth}'),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyFastenIntro),
                const SizedBox(height: Insets.small),
                _buildBulletPoint(context, l10n.privacyFastenOpenSource),
                _buildBulletPoint(context, l10n.privacyFastenDirectDownload),
                const SizedBox(height: Insets.large),

                // How Your Information is Used
                _buildSectionTitle(l10n.howInformationUsed),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyUsageIntro),
                const SizedBox(height: Insets.small),
                _buildBulletPoint(context, l10n.privacyUsageProcessing),
                _buildBulletPoint(context, l10n.privacyUsageDisplaying),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyNoOtherUse),
                const SizedBox(height: Insets.large),

                // Data Storage, Security, and Sharing
                _buildSectionTitle(l10n.dataStorageSecurity),
                const SizedBox(height: Insets.small),
                _buildBulletPoint(context, l10n.privacyStorage),
                _buildBulletPoint(context, l10n.privacySharing),
                _buildBulletPoint(context, l10n.privacyDeletion),
                const SizedBox(height: Insets.large),

                // Children's Privacy
                _buildSectionTitle(l10n.childrensPrivacy),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyChildrenBody),
                const SizedBox(height: Insets.large),

                // Changes to This Privacy Policy
                _buildSectionTitle(l10n.changesToPolicy),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyChangesBody),
                const SizedBox(height: Insets.large),

                // Contact Us
                _buildSectionTitle(l10n.contactUs),
                const SizedBox(height: Insets.small),
                _buildParagraph(context, l10n.privacyContactBody),
                const SizedBox(height: Insets.medium),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        UrlLauncherService.launchEmail(
                          'mailto:hello@healthwallet.me',
                        );
                      },
                      child: Text(
                        'hello@healthwallet.me',
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        UrlLauncherService.launchURL(
                          'https://healthwallet.me/',
                        );
                      },
                      child: Text(
                        'healthwallet.me',
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.medium),
                    Text(
                      l10n.builtWithLove,
                      style: AppTextStyle.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.large),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyle.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyle.bodyLarge.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// A paragraph whose `**`-wrapped parts are bold.
  Widget _buildParagraph(BuildContext context, String text) {
    final style = AppTextStyle.bodyMedium.copyWith(
      color: context.colorScheme.onSurface,
    );
    return RichText(
      text: TextSpan(
        style: style,
        children: boldMarkupSpans(
          text,
          boldStyle: style.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 20,
              child: Text('• ', style: TextStyle(fontSize: 16)),
            ),
          ),
          Expanded(child: _buildParagraph(context, text)),
        ],
      ),
    );
  }
}
