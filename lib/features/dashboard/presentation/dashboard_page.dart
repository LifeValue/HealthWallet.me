import 'dart:developer';

import 'package:another_flushbar/flushbar.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/domain/entities/wallet_notification.dart';
import 'package:health_wallet/features/home/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/scan_page.dart';
import 'package:health_wallet/features/scan/presentation/pages/import_page.dart';
import 'package:health_wallet/features/home/presentation/home_page.dart';
import 'package:health_wallet/features/records/presentation/pages/records_page.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';

@RoutePage()
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final PageViewNavigationController _navigationController;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _navigationController = getIt<PageViewNavigationController>();
    _navigationController.currentPageNotifier.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _navigationController.currentPageNotifier.removeListener(_onPageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    if (_isKeyboardVisible != isKeyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isKeyboardVisible = isKeyboardVisible;
        });
      });
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<SyncBloc, SyncState>(
          listenWhen: (previous, current) {
            return current.shouldShowTutorial && !previous.shouldShowTutorial;
          },
          listener: (context, syncState) async {
            if (syncState.shouldShowTutorial) {
              _navigationController.navigateToPage(0);
            }
          },
        ),
        BlocListener<ScanBloc, ScanState>(
          listenWhen: (previous, current) =>
              current.notification != null &&
              previous.notification != current.notification,
          listener: (context, state) {
            final notification = state.notification;
            if (notification == null) return;

            final isMapperRoute =
                context.router.current.name == notification.route.routeName;

            context.read<NotificationBloc>().add(
                  NotificationAdded(
                      notification: notification.copyWith(read: isMapperRoute)),
                );

            if (!isMapperRoute) {
              Flushbar(
                title: "Processing done",
                message: notification.text,
                duration: const Duration(seconds: 3),
                flushbarPosition: FlushbarPosition.TOP,
                titleColor: Colors.white,
                messageColor: Colors.white,
                backgroundColor: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(20),
                onTap: (_) => context.router.push(notification.route),
              ).show(context);
            }

            context.read<ScanBloc>().add(const ScanNotificationAcknowledged());
          },
        ),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            PageView.builder(
              controller: _navigationController.pageController,
              onPageChanged: (index) {
                FocusScope.of(context).unfocus();
              },
              itemCount: 4,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return HomePage(
                      pageController: _navigationController.pageController,
                    );
                  case 1:
                    return RecordsPage(
                      pageController: _navigationController.pageController,
                    );
                  case 2:
                    // Keep your ScanPage API that expects navigationController
                    return const ScanPage();
                  case 3:
                    return const ImportPage();
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
            BlocBuilder<SyncBloc, SyncState>(
              builder: (context, syncState) {
                if (!_isKeyboardVisible) {
                  return Positioned(
                    left: 8,
                    right: 8,
                    bottom: 24,
                    child: SizedBox(
                      height: 60,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.isDarkMode
                                      ? Colors.white.withOpacity(0.03)
                                      : Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: context.isDarkMode
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.white.withOpacity(0.2),
                                    width: 1.0,
                                  ),
                                  boxShadow: context.isDarkMode
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(Insets.extraSmall),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _buildNavItem(
                                    context: context,
                                    icon: Assets.icons.dashboard.svg(
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        _navigationController.currentPage == 0
                                            ? (context.isDarkMode
                                                ? Colors.white
                                                : context.colorScheme.surface)
                                            : context.colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    label: context.l10n.dashboardTitle,
                                    isSelected:
                                        _navigationController.currentPage == 0,
                                    pageIndex: 0,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    context: context,
                                    icon: Assets.icons.timeline.svg(
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        _navigationController.currentPage == 1
                                            ? (context.isDarkMode
                                                ? Colors.white
                                                : context.colorScheme.surface)
                                            : context.colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    label: context.l10n.recordsTitle,
                                    isSelected:
                                        _navigationController.currentPage == 1,
                                    pageIndex: 1,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    context: context,
                                    icon: Assets.icons.scan.svg(
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        _navigationController.currentPage == 2
                                            ? (context.isDarkMode
                                                ? Colors.white
                                                : context.colorScheme.surface)
                                            : context.colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    label: context.l10n.documentScanTitle,
                                    isSelected:
                                        _navigationController.currentPage == 2,
                                    pageIndex: 2,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    context: context,
                                    icon: Assets.icons.cloudDownload.svg(
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        _navigationController.currentPage == 3
                                            ? (context.isDarkMode
                                                ? Colors.white
                                                : context.colorScheme.surface)
                                            : context.colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    label: 'Import',
                                    isSelected:
                                        _navigationController.currentPage == 3,
                                    pageIndex: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required Widget icon,
    required String label,
    required bool isSelected,
    required int pageIndex,
  }) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _navigationController.jumpToPage(pageIndex);
      },
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? context.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: Insets.extraSmall),
              Text(
                label,
                style: AppTextStyle.labelSmall.copyWith(
                  color: isSelected
                      ? (context.isDarkMode
                          ? Colors.white
                          : context.colorScheme.surface)
                      : context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
