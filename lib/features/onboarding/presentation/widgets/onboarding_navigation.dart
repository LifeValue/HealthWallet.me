import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: isSmallScreen ? Insets.extraSmall : Insets.smaller),
          ElevatedButton(
            onPressed: () async {
              if (isLastPage) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('hasSeenOnboarding', true);
                context.appRouter.replace(DashboardRoute());
              } else {
                context.read<OnboardingBloc>().add(const OnboardingNextPage());
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
          SizedBox(
            height: isSmallScreen ? 32 : 40,
            child: Center(
              child: _buildMiddleContent(context, isLastPage),
            ),
          ),
          SizedBox(height: isSmallScreen ? Insets.extraSmall : Insets.small),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalPages,
              (index) => _buildDot(index, context, currentPage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleContent(BuildContext context, bool isLastPage) {
    if (currentPage == 0) {
      return GestureDetector(
        onTap: () {
          context.read<OnboardingBloc>().add(
                const OnboardingLaunchUrl(
                  'https://healthwallet.me/#contact',
                ),
              );
        },
        child: Text(
          context.l10n.onboardingRequestIntegration,
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.7),
            decoration: TextDecoration.underline,
            letterSpacing: -0.2,
          ),
        ),
      );
    }

    if (currentPage == 2) {
      return _LoadModelButton(pageController: pageController);
    }

    if (isLastPage) {
      return GestureDetector(
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
      );
    }

    return const SizedBox.shrink();
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
        margin: const EdgeInsets.only(right: 12),
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

class _LoadModelButton extends StatefulWidget {
  final PageController pageController;

  const _LoadModelButton({
    required this.pageController,
  });

  @override
  State<_LoadModelButton> createState() => _LoadModelButtonState();
}

class _LoadModelButtonState extends State<_LoadModelButton> {
  late final LoadModelBloc _bloc;
  bool _initialized = false;
  bool _hasNavigatedToNextPage = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt.get<LoadModelBloc>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        _bloc.add(const LoadModelInitialized());
      }
    });
  }

  void _navigateToNextPage(BuildContext context) {
    if (_hasNavigatedToNextPage) return;
    _hasNavigatedToNextPage = true;
    context.read<OnboardingBloc>().add(const OnboardingNextPage());
    widget.pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<LoadModelBloc, LoadModelState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == LoadModelStatus.modelLoaded) {
            _navigateToNextPage(context);
          }
        },
        child: BlocBuilder<LoadModelBloc, LoadModelState>(
          builder: (context, loadModelState) {
            if (loadModelState.status == LoadModelStatus.modelLoaded) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.aiModelReady,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              );
            }

            if (loadModelState.status == LoadModelStatus.loading &&
                loadModelState.downloadProgress == null) {
              return SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colorScheme.primary,
                ),
              );
            }

            if (loadModelState.status == LoadModelStatus.loading &&
                loadModelState.downloadProgress != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: loadModelState.downloadProgress! / 100,
                        minHeight: 6,
                        backgroundColor:
                            context.colorScheme.primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Downloading... ${loadModelState.downloadProgress!.toStringAsFixed(0)}%',
                      style: AppTextStyle.labelSmall.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            return TextButton(
              onPressed: () {
                _bloc.add(const LoadModelDownloadInitiated());
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.memory,
                    size: 20,
                    color: context.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.aiModelEnableDownload,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
