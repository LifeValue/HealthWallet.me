import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/session/session_bottom_bar.dart';

class SessionMonitoringView extends StatefulWidget {
  final ShareRecordsState state;

  const SessionMonitoringView({super.key, required this.state});

  @override
  State<SessionMonitoringView> createState() => _SessionMonitoringViewState();
}

class _SessionMonitoringViewState extends State<SessionMonitoringView> {
  bool _isScrolled = false;
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;

  void _measureHeader() {
    final renderBox =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final height = renderBox.size.height;
      if (height != _headerHeight && height > 0) {
        setState(() => _headerHeight = height);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());

    return Stack(
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: _headerHeight,
              color: Colors.transparent,
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final scrolled = notification.metrics.pixels > 0;
                  if (scrolled != _isScrolled) {
                    setState(() => _isScrolled = scrolled);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.large,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: Insets.extraLarge),
                        SvgPicture.asset(
                          'assets/images/viewing-records.svg',
                          height: 160,
                        ),
                        const SizedBox(height: Insets.large),
                        Text(
                          'Receiver is viewing records',
                          style: AppTextStyle.titleMedium.copyWith(
                            color: context.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Insets.small),
                        Text(
                          'Session will auto-expire when timer reaches zero',
                          style: AppTextStyle.bodyMedium.copyWith(
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SessionBottomBar(
              state: widget.state,
              peerRole: 'receiver',
              endSessionEvent:
                  const ShareRecordsEvent.killSessionRequested(),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            key: _headerKey,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: _isScrolled
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    )
                  : BorderRadius.zero,
              boxShadow: _isScrolled
                  ? [
                      BoxShadow(
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(Insets.normal),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.normal,
                vertical: Insets.smallNormal,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Insets.small),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: Insets.small),
                  Expanded(
                    child: Text(
                      'Records delivered successfully',
                      style: AppTextStyle.bodyMedium.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
