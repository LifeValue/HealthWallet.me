import 'package:flutter/material.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/highlight_overlay.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_step.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/tooltip_position.dart';

/// Controller for showing a multi-highlight overlay using an Overlay entry.
class MultiHighlightOverlayController {
  OverlayEntry? _overlayEntry;

  /// Shows the multi-highlight overlay.
  void show({
    required BuildContext context,
    required List<GlobalKey> targetKeys,
    required String message,
    String? subtitle,
    required VoidCallback onDismiss,
  }) {
    // Remove existing overlay if any
    hide();

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => MultiHighlightOverlay(
        targetKeys: targetKeys,
        message: message,
        subtitle: subtitle,
        onDismiss: () {
          hide();
          onDismiss();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hides the overlay.
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Whether the overlay is currently visible.
  bool get isVisible => _overlayEntry != null;
}

/// Controller for displaying step-by-step overlay tutorials.
/// Shows one overlay at a time and automatically advances to the next step on dismiss.
class StepByStepOverlayController {
  OverlayEntry? _overlayEntry;
  List<OverlayStep> _steps = [];
  int _currentStepIndex = 0;
  BuildContext? _context;
  VoidCallback? _onComplete;
  VoidCallback? _onStepChanged;

  /// Whether the overlay sequence is currently active.
  bool get isActive => _overlayEntry != null;

  /// Current step index (0-based).
  int get currentStepIndex => _currentStepIndex;

  /// Total number of steps.
  int get totalSteps => _steps.length;

  /// Shows a sequence of overlay steps.
  ///
  /// [context] - BuildContext for showing the overlay.
  /// [steps] - List of steps to show sequentially.
  /// [onComplete] - Called when all steps are completed.
  /// [onStepChanged] - Called when advancing to a new step.
  void showSequence({
    required BuildContext context,
    required List<OverlayStep> steps,
    VoidCallback? onComplete,
    VoidCallback? onStepChanged,
  }) {
    if (steps.isEmpty) {
      onComplete?.call();
      return;
    }

    _steps = steps;
    _currentStepIndex = 0;
    _context = context;
    _onComplete = onComplete;
    _onStepChanged = onStepChanged;

    _showCurrentStep();
  }

  /// Advances to the next step or completes if on the last step.
  void nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _onStepChanged?.call();
      _showCurrentStep();
    } else {
      _completeSequence();
    }
  }

  /// Skips all remaining steps and completes the sequence.
  void skipAll() {
    _completeSequence();
  }

  /// Hides the current overlay.
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showCurrentStep() {
    if (_context == null || !_context!.mounted) {
      _completeSequence();
      return;
    }

    // Remove existing overlay
    hide();

    final step = _steps[_currentStepIndex];

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => MultiHighlightOverlay(
        targetKeys: [step.targetKey],
        message: step.message,
        subtitle: step.subtitle ?? 'Tap to continue',
        tooltipPosition: TooltipPosition.top,
        onDismiss: () {
          hide();
          nextStep();
        },
      ),
    );

    Overlay.of(_context!).insert(_overlayEntry!);
  }

  void _completeSequence() {
    hide();
    _steps = [];
    _currentStepIndex = 0;
    _context = null;
    final onComplete = _onComplete;
    _onComplete = null;
    _onStepChanged = null;
    onComplete?.call();
  }
}
