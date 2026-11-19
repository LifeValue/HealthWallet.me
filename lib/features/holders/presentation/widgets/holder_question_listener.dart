import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

/// Asks whose records arrived when a newcomer matches no one and the wallet
/// has several people. Their records stay out of every view until the user
/// answers. It sits above the router, because records arrive from a
/// provider sync, a scan or the desktop whatever page is open.
class HolderQuestionListener extends StatefulWidget {
  const HolderQuestionListener({required this.child, super.key});

  final Widget child;

  @override
  State<HolderQuestionListener> createState() => _HolderQuestionListenerState();
}

class _HolderQuestionListenerState extends State<HolderQuestionListener> {
  static const _someoneElse = '';
  bool _asking = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PatientBloc, PatientState>(
      listenWhen: (previous, current) =>
          previous.holderQuestions != current.holderQuestions &&
          current.holderQuestions.isNotEmpty,
      listener: (context, state) => _ask(context.read<PatientBloc>(), state),
      child: widget.child,
    );
  }

  Future<void> _ask(PatientBloc bloc, PatientState state) async {
    final dialogContext = getIt<AppRouter>().navigatorKey.currentContext;
    if (_asking || dialogContext == null) return;
    _asking = true;
    try {
      final l10n = dialogContext.l10n;
      String name(Patient patient) =>
          patient.displayTitle.isEmpty ||
              patient.displayTitle == SourceTypeService.unknownPatientName
          ? l10n.unknownPatient
          : patient.displayTitle;

      final ask = state.holderQuestions.first;
      final answer = await AppSimpleDialog.showChoice<String>(
        context: dialogContext,
        title: l10n.holderQuestionTitle,
        message: l10n.holderQuestionMessage(name(ask.patient)),
        choices: [
          for (final holder in state.patientGroups.values)
            if (!holder.isDemo) (name(holder.representativePatient), holder.id),
          (l10n.holderQuestionSomeoneElse, _someoneElse),
        ],
      );
      // Closed without an answer (the app went away): asked again next time.
      if (answer == null) return;
      bloc.add(
        PatientHolderAnswered(
          ask: ask,
          holderId: answer == _someoneElse ? null : answer,
        ),
      );
    } finally {
      _asking = false;
    }
  }
}
