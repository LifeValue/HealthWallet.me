import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/scan/domain/services/device_capability_service.dart';
import 'package:health_wallet/features/scan/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/scan/presentation/widgets/ai_settings/ai_settings_token_section.dart';
import 'package:health_wallet/features/scan/presentation/widgets/ai_settings/ai_settings_vision_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettingsResult {
  final int maxTokens;
  final int gpuLayers;
  final int threads;
  final int contextSize;
  final bool useVision;

  const AiSettingsResult({
    required this.maxTokens,
    required this.gpuLayers,
    required this.threads,
    required this.contextSize,
    required this.useVision,
  });
}

class AiTokenSettingsDialog extends StatefulWidget {
  final int currentTokens;
  final int currentGpuLayers;
  final int currentThreads;
  final int currentContextSize;
  final int recommendedGpuLayers;
  final int recommendedThreads;
  final int recommendedContextSize;
  final int deviceRamMB;
  final AiModelConfig activeModelConfig;
  final bool currentUseVision;

  const AiTokenSettingsDialog({
    required this.currentTokens,
    required this.currentGpuLayers,
    required this.currentThreads,
    required this.currentContextSize,
    required this.recommendedGpuLayers,
    required this.recommendedThreads,
    required this.recommendedContextSize,
    required this.deviceRamMB,
    required this.activeModelConfig,
    required this.currentUseVision,
    super.key,
  });

  static Future<AiSettingsResult?> show(
    BuildContext context, {
    required int currentTokens,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceRamMB = await _detectDeviceRamMB();
    final config = DeviceCapabilityService.computeModelConfig(
      withVision: true,
      ramMB: deviceRamMB,
    );

    final savedGpu = prefs.getInt(SharedPrefsConstants.aiGpuLayers);
    final savedThreads = prefs.getInt(SharedPrefsConstants.aiThreads);
    final savedCtx = prefs.getInt(SharedPrefsConstants.aiContextSize);
    final savedVision = prefs.getBool(SharedPrefsConstants.aiUseVision);
    final useVision = savedVision ?? false;

    if (!context.mounted) return null;

    final activeModelConfig = AiModelConfig.getActive(prefs);

    return showDialog<AiSettingsResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => AiTokenSettingsDialog(
        currentTokens: currentTokens,
        currentGpuLayers: savedGpu ?? config.gpuLayers,
        currentThreads: savedThreads ?? config.threads,
        currentContextSize: savedCtx ?? config.contextSize,
        recommendedGpuLayers: config.gpuLayers,
        recommendedThreads: config.threads,
        recommendedContextSize: config.contextSize,
        deviceRamMB: deviceRamMB,
        activeModelConfig: activeModelConfig,
        currentUseVision: useVision,
      ),
    );
  }

  static Future<int> _detectDeviceRamMB() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return DeviceCapabilityService.estimateIosRam(ios.utsname.machine);
      } else if (Platform.isAndroid) {
        try {
          final memInfo = await File('/proc/meminfo').readAsString();
          final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
          if (match != null) return int.parse(match.group(1)!) ~/ 1024;
        } catch (_) {}
        final android = await deviceInfo.androidInfo;
        return android.isLowRamDevice ? 2048 : 4096;
      }
    } catch (_) {}
    return 4096;
  }

  @override
  State<AiTokenSettingsDialog> createState() => _AiTokenSettingsDialogState();
}

const _contextSizeSteps = [512, 1024, 2048, 4096];

class _AiTokenSettingsDialogState extends State<AiTokenSettingsDialog> {
  late TokenPreset _selectedPreset;
  late TextEditingController _customController;
  late int _gpuLayers;
  late int _threads;
  late int _contextSize;
  late bool _useVision;

  final AiModelDownloadService _downloadService =
      getIt.get<AiModelDownloadService>();
  StreamSubscription<AiModelDownloadState>? _downloadSub;
  bool _isMmprojDownloading = false;
  double _mmprojProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presetFromValue(widget.currentTokens);
    _customController = TextEditingController(
      text: _selectedPreset == TokenPreset.custom
          ? widget.currentTokens.toString()
          : '',
    );
    _gpuLayers = widget.currentGpuLayers;
    _threads = widget.currentThreads;
    _contextSize = widget.currentContextSize;
    _useVision = widget.currentUseVision;

    _downloadSub = _downloadService.stateStream.listen(_onDownloadState);
  }

  void _onDownloadState(AiModelDownloadState state) {
    if (!state.isMmprojDownload) return;

    if (state.status == AiModelDownloadStatus.downloading) {
      setState(() {
        _isMmprojDownloading = true;
        _mmprojProgress = state.progress;
      });
    } else if (state.status == AiModelDownloadStatus.completed) {
      setState(() {
        _isMmprojDownloading = false;
        _mmprojProgress = 0.0;
        _useVision = true;
      });
    } else if (state.status == AiModelDownloadStatus.error ||
        state.status == AiModelDownloadStatus.cancelled) {
      setState(() {
        _isMmprojDownloading = false;
        _mmprojProgress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _customController.dispose();
    super.dispose();
  }

  TokenPreset _presetFromValue(int value) {
    if (value <= 100) return TokenPreset.low;
    if (value <= 500) return TokenPreset.medium;
    if (value <= 2000) return TokenPreset.high;
    return TokenPreset.custom;
  }

  int _currentTokenValue() {
    if (_selectedPreset == TokenPreset.custom) {
      return int.tryParse(_customController.text)
              ?.clamp(1, AppConstants.maxAllowedTokens) ??
          widget.currentTokens;
    }
    return _selectedPreset.tokens;
  }

  int _contextStepIndex() {
    final idx = _contextSizeSteps.indexOf(_contextSize);
    return idx >= 0 ? idx : 1;
  }

  Future<void> _handleVisionToggleOn() async {
    final variant = widget.activeModelConfig.variant;
    final exists =
        await _downloadService.checkMmprojExistsForVariant(variant);

    if (exists) {
      setState(() => _useVision = true);
      return;
    }

    if (!mounted) return;

    final sizeMB = widget.activeModelConfig.mmprojSizeMB;
    AppSimpleDialog.showConfirmation(
      context: context,
      title: context.l10n.deepScanDownloadTitle,
      message: context.l10n.deepScanDownloadMessage(sizeMB),
      confirmText: context.l10n.aiModelEnableDownload,
      cancelText: context.l10n.cancel,
      onConfirm: () {
        _downloadService.startMmprojDownloadForVariant(variant);
      },
    );
  }

  void _apply() {
    Navigator.of(context).pop(AiSettingsResult(
      maxTokens: _currentTokenValue(),
      gpuLayers: _gpuLayers,
      threads: _threads,
      contextSize: _contextSize,
      useVision: _useVision,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = context.primaryTextColor;
    final borderColor = context.borderColor;
    final secondaryTextColor = context.secondaryTextColor;

    final activeModel = widget.activeModelConfig;
    final kvCache = (_contextSize * 170 ~/ 1024);
    final overhead = activeModel.modelSizeMB >= 2000 ? 700 : 400;
    final visionMB = _useVision ? activeModel.mmprojSizeMB : 0;
    final estimatedMB =
        activeModel.modelSizeMB + visionMB + kvCache + overhead;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: Insets.medium),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: context.isDarkMode
                ? context.colorScheme.surface
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(textColor),
              Divider(height: 1, thickness: 1, color: borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.aiSettingsDescription,
                        style: AppTextStyle.labelLarge
                            .copyWith(color: secondaryTextColor),
                      ),
                      const SizedBox(height: Insets.small),
                      _buildDeviceInfoChip(textColor, estimatedMB),
                      const SizedBox(height: Insets.normal),
                      AiVisionToggleSection(
                        useVision: _useVision,
                        isMmprojDownloading: _isMmprojDownloading,
                        mmprojProgress: _mmprojProgress,
                        onToggleOn: _handleVisionToggleOn,
                        onToggleOff: () => setState(() => _useVision = false),
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildSliderSection(
                        context.l10n.contextSizeLabel,
                        context.l10n.contextSizeDescription,
                        _contextStepIndex(),
                        0,
                        _contextSizeSteps.length - 1,
                        _contextSizeSteps
                            .indexOf(widget.recommendedContextSize)
                            .clamp(0, _contextSizeSteps.length - 1),
                        (v) =>
                            setState(() => _contextSize = _contextSizeSteps[v]),
                        textColor,
                        secondaryTextColor,
                        borderColor,
                        label: '$_contextSize',
                        stepValues: _contextSizeSteps,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildSliderSection(
                        context.l10n.gpuLayersLabel,
                        context.l10n.gpuLayersDescription,
                        _gpuLayers,
                        0,
                        8,
                        widget.recommendedGpuLayers,
                        (v) => setState(() => _gpuLayers = v),
                        textColor,
                        secondaryTextColor,
                        borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildSliderSection(
                        context.l10n.threadsLabel,
                        context.l10n.threadsDescription,
                        _threads,
                        1,
                        Platform.numberOfProcessors.clamp(1, 8),
                        widget.recommendedThreads,
                        (v) => setState(() => _threads = v),
                        textColor,
                        secondaryTextColor,
                        borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildTokenSection(
                        textColor,
                        secondaryTextColor,
                        borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildApplyButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.normal,
        vertical: Insets.small,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _apply,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
          ),
          const SizedBox(width: Insets.small),
          Expanded(
            child: Text(
              context.l10n.aiSettings,
              style: AppTextStyle.bodyMedium
                  .copyWith(color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: _apply,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(Icons.close, size: 24, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoChip(Color textColor, int estimatedMB) {
    final ramGB = (widget.deviceRamMB / 1024).toStringAsFixed(1);
    final cores = Platform.numberOfProcessors;
    final platform = Platform.isIOS ? 'iOS' : 'Android';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.smallNormal,
        vertical: Insets.extraSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$platform  •  ${ramGB}GB RAM  •  $cores cores  •  ~${estimatedMB}MB needed',
        style: AppTextStyle.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSliderSection(
    String title,
    String description,
    int value,
    int min,
    int max,
    int recommended,
    ValueChanged<int> onChanged,
    Color textColor,
    Color secondaryTextColor,
    Color borderColor, {
    String? label,
    List<int>? stepValues,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyle.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.extraSmall),
        Text(
          description,
          style: AppTextStyle.labelSmall.copyWith(
            color: secondaryTextColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Insets.small),
        AiSliderSetting(
          value: value,
          min: min,
          max: max,
          recommended: recommended,
          onChanged: onChanged,
          textColor: textColor,
          borderColor: borderColor,
          label: label,
          stepValues: stepValues,
        ),
      ],
    );
  }

  Widget _buildTokenSection(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.setAiTokensUsage,
          style: AppTextStyle.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.extraSmall),
        Text(
          context.l10n.tokenUsageDescription,
          style: AppTextStyle.labelSmall.copyWith(
            color: secondaryTextColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Insets.small),
        AiTokenOptionsSection(
          selectedPreset: _selectedPreset,
          customController: _customController,
          onPresetChanged: (preset) =>
              setState(() => _selectedPreset = preset),
          onCustomValueChanged: () => setState(() {}),
          textColor: textColor,
          borderColor: borderColor,
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: _apply,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          context.l10n.setTokens,
          style: AppTextStyle.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
