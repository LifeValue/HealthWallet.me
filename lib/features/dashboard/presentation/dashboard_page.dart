import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/notifications/utils/notification_utils.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/scan_page.dart';
import 'package:health_wallet/features/capture/import/presentation/pages/import_page.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/handover_bloc.dart';
import 'package:health_wallet/features/desktop/handover/presentation/pages/handover_page.dart';
import 'package:health_wallet/features/home/presentation/home_page.dart';
import 'package:health_wallet/features/records/presentation/pages/records_page.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
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
  final bool _isDesktop = getIt<AppPlatform>().isDesktop;
  bool _isKeyboardVisible = false;
  StreamSubscription? _handoverSub;
  bool _hasHandover = false;

  @override
  void initState() {
    super.initState();
    _navigationController = getIt<PageViewNavigationController>();
    _navigationController.currentPageNotifier.addListener(_onPageChanged);
    if (_isDesktop) _listenForHandover();
  }

  void _listenForHandover() {
    final handoverBloc = getIt<HandoverBloc>();
    final processingBloc = getIt<ProcessingBloc>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateHandoverVisibility(
        handoverBloc.state.activeSessions.isNotEmpty,
        processingBloc.state.sessions
            .any((s) => s.origin == ProcessingOrigin.handover),
      );
    });

    _handoverSub = handoverBloc.stream.listen((state) {
      _updateHandoverVisibility(
        state.activeSessions.isNotEmpty,
        processingBloc.state.sessions
            .any((s) => s.origin == ProcessingOrigin.handover),
      );
    });

    processingBloc.stream.listen((state) {
      final hasHandoverSessions =
          state.sessions.any((s) => s.origin == ProcessingOrigin.handover);
      _updateHandoverVisibility(
        handoverBloc.state.activeSessions.isNotEmpty,
        hasHandoverSessions,
      );
    });
  }

  void _updateHandoverVisibility(bool hasTransfers, bool hasProcessing) {
    final shouldShow = hasTransfers || hasProcessing;
    if (shouldShow != _hasHandover && mounted) {
      final wasHidden = !_hasHandover;
      setState(() => _hasHandover = shouldShow);
      if (shouldShow && wasHidden) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigationController.navigateToPage(3);
        });
      }
    }
  }

  void _onPageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _navigationController.currentPageNotifier.removeListener(_onPageChanged);
    _handoverSub?.cancel();
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
        BlocListener<ProcessingBloc, ProcessingState>(
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
              showProcessingDoneNotification(context, notification);
            }

            context.read<ProcessingBloc>().add(const NotificationAcknowledged());
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
              itemCount: _isDesktop ? (_hasHandover ? 4 : 3) : 4,
              itemBuilder: (context, index) {
                if (_isDesktop) {
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
                      return const ImportPage();
                    case 3:
                      return const HandoverPage();
                    default:
                      return const SizedBox.shrink();
                  }
                }
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
                  final bottomPadding =
                      MediaQuery.of(context).padding.bottom + 8;
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomPadding,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: context.isTablet ? 500 : double.infinity,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            height: 60,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: context.isDarkMode
                                        ? [
                                            Colors.white.withValues(alpha: 0.08),
                                            Colors.white.withValues(alpha: 0.04),
                                          ]
                                        : [
                                            Colors.grey.withValues(alpha: 0.08),
                                            Colors.grey.withValues(alpha: 0.03),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(100),
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
                                if (_isDesktop) ...[
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
                                      icon: Assets.icons.cloudDownload.svg(
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
                                      label: 'Import',
                                      isSelected:
                                          _navigationController.currentPage == 2,
                                      pageIndex: 2,
                                    ),
                                  ),
                                  if (_hasHandover)
                                    Expanded(
                                      child: _buildNavItem(
                                        context: context,
                                        icon: Assets.icons.shareNearby.svg(
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
                                        label: 'Handover',
                                        isSelected:
                                            _navigationController.currentPage == 3,
                                        pageIndex: 3,
                                      ),
                                    ),
                                ] else ...[
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                          ),
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
