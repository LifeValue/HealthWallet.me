import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_wallet/flutter_google_wallet_plugin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/wallet_pass_labels.dart';
import 'package:health_wallet/features/wallet_pass/domain/repository/wallet_pass_repository.dart';
import 'package:health_wallet/features/wallet_pass/domain/service/emergency_card_builder.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

part 'wallet_pass_bloc.freezed.dart';
part 'wallet_pass_event.dart';
part 'wallet_pass_state.dart';

@injectable
class WalletPassBloc extends Bloc<WalletPassEvent, WalletPassState> {
  final EmergencyCardBuilder _cardBuilder;
  final WalletPassRepository _repository;
  final AppStringsProvider _strings;

  WalletPassBloc(this._cardBuilder, this._repository, this._strings)
    : super(const WalletPassState()) {
    on<WalletPassRequested>(_onRequested);
  }

  Future<void> _onRequested(
    WalletPassRequested event,
    Emitter<WalletPassState> emit,
  ) async {
    emit(state.copyWith(status: WalletPassStatus.loading, errorMessage: null));

    try {
      final cardData = await _cardBuilder.build(patientId: event.patientId);
      emit(
        state.copyWith(
          status: WalletPassStatus.dataReady,
          cardData: cardData,
        ),
      );

      final labels = event.labels ?? WalletPassLabels.fromL10n(_strings.l10n);
      switch (event.type) {
        case WalletPassType.apple:
          await _handleApplePass(cardData, event.patientId, emit, labels);
        case WalletPassType.google:
          await _handleGooglePass(cardData, event.patientId, emit, labels);
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: WalletPassStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleApplePass(
    EmergencyCardData cardData,
    String patientId,
    Emitter<WalletPassState> emit,
    WalletPassLabels labels,
  ) async {
    final passBytes = await _repository.generateApplePass(
      cardData: cardData,
      patientId: patientId,
      labels: labels,
    );
    emit(
      state.copyWith(
        status: WalletPassStatus.passGenerated,
        passBytes: passBytes,
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/HealthWallet_Emergency.pkpass';
    final file = File(filePath);
    await file.writeAsBytes(passBytes);

    const channel = MethodChannel(
      'com.techstackapps.healthwallet/apple_wallet',
    );
    await channel.invokeMethod('addPass', {'filePath': filePath});

    emit(state.copyWith(status: WalletPassStatus.passAddedToWallet));
  }

  Future<void> _handleGooglePass(
    EmergencyCardData cardData,
    String patientId,
    Emitter<WalletPassState> emit,
    WalletPassLabels labels,
  ) async {
    final passJson = await _repository.generateGooglePassJson(
      cardData: cardData,
      patientId: patientId,
      labels: labels,
    );
    emit(
      state.copyWith(
        status: WalletPassStatus.passGenerated,
        googlePassJson: passJson,
      ),
    );

    final plugin = FlutterGoogleWalletPlugin();
    unawaited(plugin.initWalletClient());

    unawaited(
      plugin.savePassesJwt(
        jsonPass: passJson,
        addToGoogleWalletRequestCode: 1,
      ),
    );

    emit(state.copyWith(status: WalletPassStatus.passAddedToWallet));
  }
}
