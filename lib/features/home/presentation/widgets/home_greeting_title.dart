import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/widgets/share_options_sheet.dart';
import 'package:health_wallet/features/notifications/notification_widget.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/preference_modal.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class HomeGreetingTitle extends StatelessWidget {
  final HomeState homeState;
  final bool showPatientInsteadOfGreeting;

  const HomeGreetingTitle({
    super.key,
    required this.homeState,
    this.showPatientInsteadOfGreeting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: showPatientInsteadOfGreeting
              ? _PatientLabel(homeState: homeState)
              : _GreetingLabel(),
        ),
        _HomeActions(editMode: homeState.editMode),
      ],
    );
  }
}

class _GreetingLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, userState) {
        return BlocBuilder<SyncBloc, SyncState>(
          builder: (context, syncState) {
            final displayName = userState.user.name.isNotEmpty
                ? userState.user.name
                : (syncState.syncQrData?.tokenMeta.fullName.isNotEmpty == true
                    ? syncState.syncQrData!.tokenMeta.fullName
                    : 'User');
            return RichText(
              text: TextSpan(
                style: AppTextStyle.titleMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(text: context.l10n.homeHi),
                  TextSpan(
                    text: displayName,
                    style: TextStyle(color: context.colorScheme.primary),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PatientLabel extends StatefulWidget {
  final HomeState homeState;

  const _PatientLabel({required this.homeState});

  @override
  State<_PatientLabel> createState() => _PatientLabelState();
}

class _PatientLabelState extends State<_PatientLabel> {
  final GlobalKey _tapKey = GlobalKey();
  bool _isMenuOpen = false;

  void _onTap() {
    if (_isMenuOpen) return;
    final box = _tapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlay);

    setState(() => _isMenuOpen = true);

    final patientName = FhirFieldExtractor.extractHumanNameFamilyFirst(
        widget.homeState.patient?.name?.first);

    showShareOptionsMenu(
      context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + box.size.height + 4,
        pos.dx + box.size.width,
        0,
      ),
      patientName: patientName,
      patientId: widget.homeState.patient?.id,
    ).then((_) {
      if (mounted) setState(() => _isMenuOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientName = FhirFieldExtractor.extractHumanNameFamilyFirst(
            widget.homeState.patient?.name?.first) ??
        'Loading...';

    return GestureDetector(
      key: _tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Patient: ',
            style: AppTextStyle.titleSmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Flexible(
            child: Text(
              patientName,
              style: AppTextStyle.titleSmall.copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: _isMenuOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: context.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActions extends StatelessWidget {
  final bool editMode;

  const _HomeActions({required this.editMode});

  @override
  Widget build(BuildContext context) {
    if (editMode) {
      return TextButton(
        onPressed: () =>
            context.read<HomeBloc>().add(const HomeEditModeChanged(false)),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
        ),
        child: Text(context.l10n.done),
      );
    }

    return Row(
      children: [
        const NotificationWidget(),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            icon: Assets.icons.settings.svg(
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              PreferenceModal.show(context);
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
