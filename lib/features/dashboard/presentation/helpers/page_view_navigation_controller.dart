import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class PageViewNavigationController {
  final PageController _pageController;
  final ValueNotifier<int> _currentPageNotifier;
  int? _targetPage;

  PageViewNavigationController()
      : _pageController = PageController(initialPage: 0),
        _currentPageNotifier = ValueNotifier<int>(0) {
    _pageController.addListener(_onPageChanged);
  }

  PageController get pageController => _pageController;

  ValueNotifier<int> get currentPageNotifier => _currentPageNotifier;

  int get currentPage => _currentPageNotifier.value;

  int? get targetPage => _targetPage;

  bool isSettledOnPage(int pageIndex) {
    if (!_pageController.hasClients) return false;

    final page = _pageController.page;
    if (page == null) return false;

    final isSettled = (page - pageIndex).abs() < 0.01;
    return isSettled && _targetPage == null;
  }

  void _onPageChanged() {
    if (_pageController.hasClients) {
      final page = _pageController.page;
      if (page != null) {
        final roundedPage = page.round();
        final isSettled = (page - roundedPage).abs() < 0.01;

        if (_currentPageNotifier.value != roundedPage) {
          _currentPageNotifier.value = roundedPage;
        }

        if (isSettled && _targetPage != null) {
          _targetPage = null;
        }
      }
    }
  }

  Future<void> navigateToPage(
    int pageIndex, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) {
    _targetPage = pageIndex;

    if (_currentPageNotifier.value != pageIndex) {
      _currentPageNotifier.value = pageIndex;
    }

    return _pageController.animateToPage(
      pageIndex,
      duration: duration,
      curve: curve,
    );
  }

  void jumpToPage(int pageIndex) {
    _targetPage = null;

    if (_currentPageNotifier.value != pageIndex) {
      _currentPageNotifier.value = pageIndex;
    }

    _pageController.jumpToPage(pageIndex);
  }

  bool isOnPage(int pageIndex) {
    return _currentPageNotifier.value == pageIndex;
  }

  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _currentPageNotifier.dispose();
  }
}
