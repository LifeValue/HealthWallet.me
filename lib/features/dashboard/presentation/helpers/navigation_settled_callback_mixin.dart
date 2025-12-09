import 'package:flutter/material.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';

mixin NavigationSettledCallbackMixin<T extends StatefulWidget> on State<T> {
  PageViewNavigationController? get navigationController;

  int? _targetPageIndex;
  bool _hasTriggered = false;
  bool _isCheckingForSettle = false;

  void onPageSettled() {}

  void onPageLeft() {}

  void resetTriggerFlag() {
    if (_hasTriggered) {
      setState(() {
        _hasTriggered = false;
        _isCheckingForSettle = false;
      });
    }
  }

  void _onPageChanged() {
    final controller = navigationController;
    if (controller == null || _targetPageIndex == null) return;

    final currentPage = controller.currentPage;
    final targetPage = controller.targetPage;
    final isSettled = controller.isSettledOnPage(_targetPageIndex!);

    if (currentPage != _targetPageIndex && _hasTriggered) {
      onPageLeft();
      setState(() {
        _hasTriggered = false;
        _isCheckingForSettle = false;
      });
    }

    if (currentPage == _targetPageIndex && !_hasTriggered) {
      if (isSettled) {
        _isCheckingForSettle = false;
        _hasTriggered = true;
        onPageSettled();
      } else if (targetPage == null && !_isCheckingForSettle) {
        _isCheckingForSettle = true;
        _checkForSettleWithRetry(controller, maxAttempts: 30);
      }
    }
  }

  void _checkForSettleWithRetry(
    PageViewNavigationController controller, {
    int attempt = 0,
    int maxAttempts = 30,
  }) {
    if (!mounted || _hasTriggered || _targetPageIndex == null) {
      _isCheckingForSettle = false;
      return;
    }

    if (controller.currentPage != _targetPageIndex) {
      _isCheckingForSettle = false;
      return;
    }

    final isSettled = controller.isSettledOnPage(_targetPageIndex!);

    if (isSettled) {
      _isCheckingForSettle = false;
      _hasTriggered = true;
      onPageSettled();
    } else if (attempt < maxAttempts - 1) {
      if (attempt == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasTriggered) {
            _checkForSettleWithRetry(controller,
                attempt: attempt + 1, maxAttempts: maxAttempts);
          } else {
            _isCheckingForSettle = false;
          }
        });
      } else {
        Future.microtask(() {
          if (mounted && !_hasTriggered) {
            _checkForSettleWithRetry(controller,
                attempt: attempt + 1, maxAttempts: maxAttempts);
          } else {
            _isCheckingForSettle = false;
          }
        });
      }
    } else {
      _isCheckingForSettle = false;
      if (controller.currentPage == _targetPageIndex && !_hasTriggered) {
        _hasTriggered = true;
        onPageSettled();
      }
    }
  }

  void initializeNavigationSettledListener(int targetPageIndex) {
    _targetPageIndex = targetPageIndex;
    navigationController?.currentPageNotifier.addListener(_onPageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = navigationController;
      if (controller != null &&
          controller.currentPage == targetPageIndex &&
          !_hasTriggered) {
        final isSettled = controller.isSettledOnPage(targetPageIndex);
        final isDirectNavigation = controller.targetPage == null;

        if (isSettled || isDirectNavigation) {
          _hasTriggered = true;
          onPageSettled();
        }
      }
    });
  }

  void disposeNavigationSettledListener() {
    navigationController?.currentPageNotifier.removeListener(_onPageChanged);
  }
}
