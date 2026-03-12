import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/widgets/dialogs/confirmation_dialog.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_network_data_source.dart';
import 'package:health_wallet/features/scan/domain/services/ai_model_download_service.dart';
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
    final config = ScanNetworkDataSourceImpl.computeModelConfig(
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
        return ScanNetworkDataSourceImpl.estimateIosRam(ios.utsname.machine);
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

enum _TokenPreset {
  low(100),
  medium(500),
  high(2000),
  custom(0);

  final int tokens;
  const _TokenPreset(this.tokens);
}

const _contextSizeSteps = [512, 1024, 2048, 4096];

class _AiTokenSettingsDialogState extends State<AiTokenSettingsDialog> {
  late _TokenPreset _selectedPreset;
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
      text: _selectedPreset == _TokenPreset.custom
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

  _TokenPreset _presetFromValue(int value) {
    if (value <= 100) return _TokenPreset.low;
    if (value <= 500) return _TokenPreset.medium;
    if (value <= 2000) return _TokenPreset.high;
    return _TokenPreset.custom;
  }

  int _currentTokenValue() {
    if (_selectedPreset == _TokenPreset.custom) {
      return int.tryParse(_customController.text)?.clamp(1, AppConstants.maxAllowedTokens) ??
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
    ConfirmationDialog.show(
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
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;
    final secondaryTextColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final activeModel = widget.activeModelConfig;
    final kvCache = (_contextSize * 170 ~/ 1024);
    final overhead = activeModel.modelSizeMB >= 2000 ? 700 : 400;
    final visionMB = _useVision ? activeModel.mmprojSizeMB : 0;
    final estimatedMB = activeModel.modelSizeMB + visionMB + kvCache + overhead;

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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.normal,
                  vertical: Insets.small,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _apply,
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: textColor,
                      ),
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
                        child: Icon(
                          Icons.close,
                          size: 24,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.aiSettingsDescription,
                        style: AppTextStyle.labelLarge.copyWith(color: secondaryTextColor),
                      ),
                      const SizedBox(height: Insets.small),
                      _buildDeviceInfoChip(textColor, estimatedMB),
                      const SizedBox(height: Insets.normal),
                      _buildVisionToggle(textColor, secondaryTextColor, borderColor),
                      const SizedBox(height: Insets.normal),
                      _buildSectionHeader(
                        context.l10n.contextSizeLabel,
                        textColor,
                      ),
                      const SizedBox(height: Insets.extraSmall),
                      Text(
                        context.l10n.contextSizeDescription,
                        style: AppTextStyle.labelSmall.copyWith(
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Insets.small),
                      _buildSliderSetting(
                        value: _contextStepIndex(),
                        min: 0,
                        max: _contextSizeSteps.length - 1,
                        recommended: _contextSizeSteps.indexOf(widget.recommendedContextSize).clamp(0, _contextSizeSteps.length - 1),
                        label: '$_contextSize',
                        onChanged: (v) => setState(() => _contextSize = _contextSizeSteps[v]),
                        textColor: textColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildSectionHeader(
                        context.l10n.gpuLayersLabel,
                        textColor,
                      ),
                      const SizedBox(height: Insets.extraSmall),
                      Text(
                        context.l10n.gpuLayersDescription,
                        style: AppTextStyle.labelSmall.copyWith(
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Insets.small),
                      _buildSliderSetting(
                        value: _gpuLayers,
                        min: 0,
                        max: 8,
                        recommended: widget.recommendedGpuLayers,
                        onChanged: (v) => setState(() => _gpuLayers = v),
                        textColor: textColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildSectionHeader(
                        context.l10n.threadsLabel,
                        textColor,
                      ),
                      const SizedBox(height: Insets.extraSmall),
                      Text(
                        context.l10n.threadsDescription,
                        style: AppTextStyle.labelSmall.copyWith(
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Insets.small),
                      _buildSliderSetting(
                        value: _threads,
                        min: 1,
                        max: Platform.numberOfProcessors.clamp(1, 8),
                        recommended: widget.recommendedThreads,
                        onChanged: (v) => setState(() => _threads = v),
                        textColor: textColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      _buildSectionHeader(
                        context.l10n.setAiTokensUsage,
                        textColor,
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
                      _buildTokenOptions(
                        textColor: textColor,
                        borderColor: borderColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                      const SizedBox(height: Insets.normal),
                      SizedBox(
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
                      ),
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

  Widget _buildVisionToggle(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.smallNormal,
        vertical: Insets.small,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.useVisionLabel,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Insets.extraSmall),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Beta',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
              const Spacer(),
              _buildOnOffToggle(borderColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.useVisionDescription,
            style: AppTextStyle.labelSmall.copyWith(
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnOffToggle(Color borderColor) {
    if (_isMmprojDownloading) {
      return _buildMmprojProgressIndicator();
    }

    final colorScheme = context.colorScheme;

    return GestureDetector(
      onTap: () {
        if (_useVision) {
          setState(() => _useVision = false);
        } else {
          _handleVisionToggleOn();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 76,
        height: 36,
        padding: const EdgeInsets.all(Insets.extraSmall),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: !_useVision
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'OFF',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: !_useVision
                          ? (context.isDarkMode
                              ? Colors.white
                              : colorScheme.onPrimary)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _useVision
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'ON',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: _useVision
                          ? (context.isDarkMode
                              ? Colors.white
                              : colorScheme.onPrimary)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMmprojProgressIndicator() {
    final percent = _mmprojProgress.round();
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: AppTextStyle.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _mmprojProgress / 100,
              minHeight: 4,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: AppTextStyle.bodyMedium.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSliderSetting({
    required int value,
    required int min,
    required int max,
    required int recommended,
    required ValueChanged<int> onChanged,
    required Color textColor,
    required Color borderColor,
    String? label,
  }) {
    final isRecommended = value == recommended;
    final displayValue = label ?? '$value';
    final recLabel = label != null
        ? _contextSizeSteps[recommended.clamp(0, _contextSizeSteps.length - 1)].toString()
        : '$recommended';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayValue,
              style: AppTextStyle.titleSmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.recommended,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => onChanged(recommended),
                child: Text(
                  '${context.l10n.recommended}: $recLabel',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: borderColor,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min > 0 ? max - min : 1,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenOptions({
    required Color textColor,
    required Color borderColor,
    required Color secondaryTextColor,
  }) {
    return Column(
      children: [
        _buildTokenChip(
          _TokenPreset.low,
          context.l10n.tokenPresetLow,
          '~100',
          textColor,
          borderColor,
        ),
        const SizedBox(height: Insets.extraSmall),
        _buildTokenChip(
          _TokenPreset.medium,
          context.l10n.tokenPresetMedium,
          '~500',
          textColor,
          borderColor,
        ),
        const SizedBox(height: Insets.extraSmall),
        _buildTokenChip(
          _TokenPreset.high,
          context.l10n.tokenPresetHigh,
          '~2000',
          textColor,
          borderColor,
        ),
        const SizedBox(height: Insets.extraSmall),
        _buildCustomTokenRow(textColor, borderColor),
      ],
    );
  }

  Widget _buildTokenChip(
    _TokenPreset preset,
    String title,
    String tokenLabel,
    Color textColor,
    Color borderColor,
  ) {
    final isSelected = _selectedPreset == preset;

    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = preset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.smallNormal,
          vertical: Insets.small,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildRadioCircle(isSelected),
            const SizedBox(width: Insets.small),
            Text(
              title,
              style: AppTextStyle.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$tokenLabel ${context.l10n.tokens}',
              style: AppTextStyle.labelSmall.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTokenRow(Color textColor, Color borderColor) {
    final isSelected = _selectedPreset == _TokenPreset.custom;

    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = _TokenPreset.custom),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.smallNormal,
          vertical: Insets.small,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildRadioCircle(isSelected),
            const SizedBox(width: Insets.small),
            Text(
              context.l10n.tokenPresetCustom,
              style: AppTextStyle.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: Insets.small),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyle.labelLarge.copyWith(
                      color: textColor,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.small,
                        vertical: 7,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadioCircle(bool isSelected) {
    if (isSelected) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color.fromRGBO(30, 30, 30, 0.3),
          width: 1.5,
        ),
      ),
    );
  }
}
