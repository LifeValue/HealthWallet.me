import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/services/url_launcher.dart';

@RoutePage()
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.privacyPolicy),
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.l10n.effectiveDate}: September 1, 2025',
              style: AppTextStyle.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.normal),

            // Introduction
            RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(text: '${context.l10n.privacyIntro} '),
                  TextSpan(
                    text: 'HealthWallet.me',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: ' ${context.l10n.privacyDescription}'),
                ],
              ),
            ),
            const SizedBox(height: Insets.large),

            // Core Principle Section
            _buildSectionTitle(context.l10n.corePrinciple),
            const SizedBox(height: Insets.small),
            RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                      text:
                          'The most important thing to know is that we, the developers of '),
                  TextSpan(
                    text: 'HealthWallet.me',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                      text:
                          ', do not collect, store, or have access to any of your personal or health information. Our app operates entirely on your device.'),
                ],
              ),
            ),
            const SizedBox(height: Insets.medium),
            _buildBulletPoint(
                '✅ No Cloud Processing: All calculations, data organization, and other functions happen locally on your phone or tablet.'),
            _buildBulletPoint(
                '✅ No Developer Access: We cannot see, access, or export your data. It is never sent to our servers.'),
            _buildBulletPoint(
                '✅ You Are in Control: Your information is stored securely within the app\'s private storage on your device, which only you can access.'),
            const SizedBox(height: Insets.large),

            // What Information is Handled Section
            _buildSectionTitle(context.l10n.whatInformationHandled),
            const SizedBox(height: Insets.medium),

            // Information We Do Not Collect
            _buildSubsectionTitle(context.l10n.informationWeDoNotCollect),
            const SizedBox(height: Insets.small),
            RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                      text:
                          'To be perfectly clear, our app is intentionally built to avoid accessing your personal data. We '),
                  TextSpan(
                    text: 'do not',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                      text:
                          ' collect, store, link, or process any information that can be tied to you.'),
                ],
              ),
            ),
            const SizedBox(height: Insets.medium),
            _buildBulletPoint(
                'Personal Identifiers: We do not access or store your name, email address, phone number, contacts, or any other personal account information from your device.'),
            _buildBulletPoint(
                'Health Information: Any health records, medical conditions, medications, or other data you import remain yours alone. We cannot access them.'),
            _buildBulletPointWithBold(
                context,
                'No Cross-Referencing: The app operates in isolation. It ',
                'does not',
                ' scan, index, or cross-reference your health data with any other personal information on your phone (like your contacts list, name, or phone number). Its only job is to organize the records you provide to it.'),
            _buildBulletPoint(
                'Usage Analytics: We do not track how you use the app, which buttons you tap, or how long you spend on certain screens.'),
            const SizedBox(height: Insets.large),

            // Information You Manage
            _buildSubsectionTitle(context.l10n.informationYouManage),
            const SizedBox(height: Insets.small),
            RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                      text:
                          'The only data processed by the app is the health information '),
                  TextSpan(
                    text: 'you choose to import',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                      text:
                          ' into it. This can be done in the following ways:'),
                ],
              ),
            ),
            const SizedBox(height: Insets.medium),

            // Importing Documents
            _buildSubsectionTitle('1. ${context.l10n.importingDocuments}'),
            const SizedBox(height: Insets.small),
            Text(
              'You can add health documents (such as PDFs of lab results or clinic summaries) directly into the app using standard mobile operating system features:',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: Insets.small),
            _buildBulletPoint(
                'Scanning: Using your device\'s camera to scan a physical document from within the app.'),
            _buildBulletPointWithBold(
                context,
                'Share Action Sheet: Selecting a file from another app (like your email, photos, or file manager) and "sharing" it directly to ',
                'HealthWallet.me',
                '.'),
            const SizedBox(height: Insets.small),
            RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                      text:
                          'Once a document is imported, the app processes it locally on your device in the background. It structures the information according to the '),
                  TextSpan(
                    text:
                        'HL7 FHIR (Fast Healthcare Interoperability Resources)',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                      text:
                          ' standard to make it useful and organized. This entire process happens on your device; the document and the structured data never leave it.'),
                ],
              ),
            ),
            const SizedBox(height: Insets.large),

            // Connecting to FastenHealth
            _buildSubsectionTitle('2. ${context.l10n.connectingFastenHealth}'),
            const SizedBox(height: Insets.small),
            RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                      text:
                          'Our app allows you to consolidate your health records by connecting to '),
                  TextSpan(
                    text: 'FastenHealth OnPrem',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                      text: ', a transparent, open-source platform.'),
                ],
              ),
            ),
            const SizedBox(height: Insets.small),
            _buildBulletPoint(
                'Open-Source and On-Premises: FastenHealth OnPrem is open-source software that you or a trusted entity controls. This provides an exceptional level of privacy.'),
            _buildBulletPointWithBold(
                context,
                'Direct-to-Device Download: When you authorize the connection, your health records are downloaded ',
                'directly from your FastenHealth OnPrem instance to your device',
                '. Our app is only a conduit; your data never passes through our servers.'),
            const SizedBox(height: Insets.large),

            // How Your Information is Used
            _buildSectionTitle(context.l10n.howInformationUsed),
            const SizedBox(height: Insets.small),
            Text(
              'Since all your data resides on your device, it is only "used" by the app to help you organize and view your records. This includes:',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: Insets.small),
            _buildBulletPoint(
                'Processing and structuring imported or scanned documents.'),
            _buildBulletPoint(
                'Displaying your health records, lab results, and medication history to you.'),
            const SizedBox(height: Insets.small),
            Text(
              'We do not use your information for advertising, research, or any other purpose.',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: Insets.large),

            // Data Storage, Security, and Sharing
            _buildSectionTitle(context.l10n.dataStorageSecurity),
            const SizedBox(height: Insets.small),
            _buildBulletPoint(
                'Storage: All your data is stored in the app\'s secure, sandboxed storage on your device. It is as secure as your device itself. We strongly recommend you protect your device with a passcode, Face ID, or other biometric security.'),
            _buildBulletPoint(
                'Sharing: We do not and cannot share your data with anyone because we don\'t have it. If you choose to export or share your data from the app, you are in complete control of where it goes.'),
            _buildBulletPoint(
                'Deletion: You can delete your information at any time from within the app. Deleting the app from your device will also permanently delete all data it has stored.'),
            const SizedBox(height: Insets.large),

            // Children's Privacy
            _buildSectionTitle(context.l10n.childrensPrivacy),
            const SizedBox(height: Insets.small),
            Text(
              'Our service is not directed to individuals under the age of 16, in accordance with the General Data Protection Regulation (GDPR) as applicable in Romania and across the EU. We do not knowingly collect personal information from children. If you become aware that a child has provided us with personal information, please contact us.',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: Insets.large),

            // Changes to This Privacy Policy
            _buildSectionTitle(context.l10n.changesToPolicy),
            const SizedBox(height: Insets.small),
            Text(
              'We may update this policy from time to time. If we make any material changes, we will notify you through the app or by other means so you can review the changes before they take effect.',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: Insets.large),

            // Contact Us
            _buildSectionTitle(context.l10n.contactUs),
            const SizedBox(height: Insets.small),
            Text(
              'If you have any questions or concerns about this Privacy Policy, please contact us at:',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: Insets.medium),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    UrlLauncherService.launchEmail('mailto:hello@healthwallet.me');
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
                    UrlLauncherService.launchURL('https://healthwallet.me/');
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
                  context.l10n.builtWithLove,
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 20,
              child: const Text('• ', style: TextStyle(fontSize: 16)),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyle.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPointWithBold(BuildContext context, String beforeText,
      String boldText, String afterText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 20,
              child: const Text('• ', style: TextStyle(fontSize: 16)),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(text: beforeText),
                  TextSpan(
                    text: boldText,
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: afterText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
