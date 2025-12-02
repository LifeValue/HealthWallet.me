import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/core/widgets/dialogs/confirmation_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNavigation extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final int totalPages;

  const OnboardingNavigation({
    super.key,
    required this.pageController,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isLastPage = currentPage == totalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
      child: SizedBox(
        height: isLastPage
            ? (isSmallScreen ? 140 : 160)
            : (isSmallScreen ? 120 : 140),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (isLastPage)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.small),
                child: BlocBuilder<UserBloc, UserState>(
                  builder: (context, userState) {
                    return TextButton(
                      onPressed: () {
                        final isEnabled = userState.isBiometricAuthEnabled;
                        if (isEnabled) {
                          ConfirmationDialog.show(
                            context: context,
                            title: context.l10n.confirmDisableBiometric,
                            confirmText: context.l10n.disable,
                            cancelText: context.l10n.cancel,
                            onConfirm: () {
                              context
                                  .read<UserBloc>()
                                  .add(UserBiometricAuthToggled(false));
                            },
                          );
                        } else {
                          context
                              .read<UserBloc>()
                              .add(UserBiometricAuthToggled(true));
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: context.colorScheme.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        userState.isBiometricAuthEnabled
                            ? context.l10n.disableBiometricAuth
                            : context.l10n.enableBiometricAuth,
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                if (isLastPage) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hasSeenOnboarding', true);
                  context.appRouter.replace(DashboardRoute());
                } else {
                  context
                      .read<OnboardingBloc>()
                      .add(const OnboardingNextPage());
                  pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.isDarkMode
                    ? Colors.white
                    : context.colorScheme.onPrimary,
                padding: EdgeInsets.all(isSmallScreen ? 10 : Insets.small),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    !isLastPage
                        ? context.l10n.continueButton
                        : context.l10n.getStarted,
                    style: AppTextStyle.buttonMedium,
                  ),
                  const SizedBox(width: 8),
                  if (!isLastPage) const Icon(Icons.arrow_forward),
                ],
              ),
            ),
            if (isLastPage)
              Padding(
                padding: EdgeInsets.only(
                    bottom: isSmallScreen ? 16 : Insets.small,
                    top: Insets.small),
                child: GestureDetector(
                  onTap: () {
                    context.appRouter.push(const PrivacyPolicyRoute());
                  },
                  child: Text(
                    context.l10n.privacyPolicy,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.7),
                      decoration: TextDecoration.underline,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalPages,
                (index) => _buildDot(index, context, currentPage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index, BuildContext context, int currentPage) {
    return GestureDetector(
      onTap: () => pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      ),
      child: Container(
        height: 12,
        width: currentPage == index ? 24 : 12,
        margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: currentPage == index
              ? context.colorScheme.primary
                  .withOpacity(context.isDarkMode ? 0.9 : 1.0)
              : context.colorScheme.onSurface.withOpacity(0.3),
          border: Border.all(
            color: context.colorScheme.onSurface.withOpacity(0.15),
            width: currentPage == index ? 0 : 1,
          ),
        ),
      ),
    );
  }
}
