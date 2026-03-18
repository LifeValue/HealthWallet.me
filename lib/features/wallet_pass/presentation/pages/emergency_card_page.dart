import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class EmergencyCardPage extends StatelessWidget {
  final EmergencyCardData cardData;

  const EmergencyCardPage({super.key, required this.cardData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Medical ID',
          style: AppTextStyle.titleMedium,
        ),
        centerTitle: false,
        backgroundColor: context.colorScheme.surface,
        leading: IconButton(
          onPressed: () => context.router.maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientHeader(context),
            const SizedBox(height: Insets.normal),
            if (cardData.patientPhone != null)
              _buildPhoneRow(
                context,
                icon: Icons.phone,
                label: 'Phone',
                phone: cardData.patientPhone!,
              ),
            if (cardData.emergencyContactName != null)
              _buildEmergencyContact(context),
            if (cardData.allergies.isNotEmpty)
              _buildListSection(
                context,
                icon: Icons.warning_amber_rounded,
                label: 'Allergies',
                items: cardData.allergies,
                badgeColor: AppColors.error,
              ),
            if (cardData.conditions.isNotEmpty)
              _buildListSection(
                context,
                icon: Icons.monitor_heart_outlined,
                label: 'Medical Conditions',
                items: cardData.conditions,
                badgeColor: AppColors.secondary,
              ),
            if (cardData.medications.isNotEmpty)
              _buildListSection(
                context,
                icon: Icons.medication_outlined,
                label: 'Medications',
                items: cardData.medications,
                badgeColor: AppColors.info,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeader(BuildContext context) {
    final gender = cardData.gender != null
        ? cardData.gender![0].toUpperCase() + cardData.gender!.substring(1)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.normal),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency, color: Colors.white, size: 28),
              const SizedBox(width: Insets.small),
              Expanded(
                child: Text(
                  cardData.patientName,
                  style: AppTextStyle.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.smallNormal),
          Row(
            children: [
              if (cardData.bloodType != null)
                _buildBadge(cardData.bloodType!, Colors.white, AppColors.error),
              if (cardData.bloodType != null)
                const SizedBox(width: Insets.small),
              if (gender != null) ...[
                _buildBadge(gender, Colors.white.withValues(alpha: 0.2),
                    Colors.white),
                const SizedBox(width: Insets.small),
              ],
              if (cardData.dateOfBirth != null)
                _buildBadge(
                  DateFormat('MMM d, yyyy').format(cardData.dateOfBirth!),
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.small,
        vertical: Insets.extraSmall,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyle.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildPhoneRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String phone,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.smallNormal),
      child: GestureDetector(
        onTap: () => _callPhone(phone),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.smallNormal),
          decoration: BoxDecoration(
            border: Border.all(color: context.theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: Insets.smallNormal),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.smallNormal),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.smallNormal),
        decoration: BoxDecoration(
          border: Border.all(color: context.theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: Insets.smallNormal),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyle.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.smallNormal),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.smallNormal),
        decoration: BoxDecoration(
          border: Border.all(color: context.theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.contact_phone_outlined,
              size: 20,
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: Insets.smallNormal),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Phone Contact',
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cardData.emergencyContactName!,
                    style: AppTextStyle.bodyMedium,
                  ),
                  if (cardData.emergencyContactPhone != null) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _callPhone(cardData.emergencyContactPhone!),
                      child: Text(
                        cardData.emergencyContactPhone!,
                        style: AppTextStyle.labelLarge.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> items,
    required Color badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.smallNormal),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.smallNormal),
        decoration: BoxDecoration(
          border: Border.all(color: context.theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: badgeColor),
                const SizedBox(width: Insets.small),
                Text(
                  label,
                  style: AppTextStyle.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.small),
            Wrap(
              spacing: Insets.small,
              runSpacing: Insets.small,
              children: items
                  .map((item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.smallNormal,
                          vertical: Insets.smaller,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item,
                          style: AppTextStyle.labelMedium.copyWith(
                            color: badgeColor,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
