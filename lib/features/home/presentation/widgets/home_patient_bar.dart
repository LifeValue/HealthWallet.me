import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/widgets/share_options_sheet.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class HomePatientBar extends StatefulWidget {
  final HomeState state;
  final bool isScrolled;
  final GlobalKey patientRowKey;
  final ValueChanged<double> onHeightMeasured;

  const HomePatientBar({
    super.key,
    required this.state,
    required this.isScrolled,
    required this.patientRowKey,
    required this.onHeightMeasured,
  });

  @override
  State<HomePatientBar> createState() => _HomePatientBarState();
}

class _HomePatientBarState extends State<HomePatientBar> {
  bool _isShareMenuOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeight());
  }

  @override
  void didUpdateWidget(HomePatientBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeight());
  }

  void _measureHeight() {
    final renderBox = widget.patientRowKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (renderBox != null && mounted) {
      final height = renderBox.size.height;
      if (height > 0) {
        widget.onHeightMeasured(height);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        key: widget.patientRowKey,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: widget.isScrolled
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                )
              : BorderRadius.zero,
          boxShadow: widget.isScrolled
              ? [
                  BoxShadow(
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                ]
              : [],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.screenHorizontalPadding,
          vertical: Insets.small,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onPatientBarTap(context),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Patient: ${FhirFieldExtractor.extractHumanNameFamilyFirst(widget.state.patient?.name?.first) ?? 'Loading...'}',
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Insets.extraSmall),
              AnimatedRotation(
                turns: _isShareMenuOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Assets.icons.chevronDown.svg(
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPatientBarTap(BuildContext context) {
    if (_isShareMenuOpen) return;
    final row = widget.patientRowKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (row == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final rowTopLeft = row.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final position = RelativeRect.fromLTRB(
      Insets.normal,
      rowTopLeft.dy + row.size.height,
      Insets.normal,
      0,
    );

    setState(() => _isShareMenuOpen = true);

    final patientName = FhirFieldExtractor.extractHumanNameFamilyFirst(
        widget.state.patient?.name?.first);
    showShareOptionsMenu(
      context,
      position: position,
      patientName: patientName,
      patientId: widget.state.patient?.id,
    ).then((_) {
      if (mounted) {
        setState(() => _isShareMenuOpen = false);
      }
    });
  }
}
