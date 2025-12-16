import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/trust_manager_service.dart';
import 'package:injectable/injectable.dart';
import 'package:jose/jose.dart';

part 'trust_event.dart';
part 'trust_state.dart';
part 'trust_bloc.freezed.dart';

@injectable
class TrustBloc extends Bloc<TrustEvent, TrustState> {
  final TrustManagerService _trustManagerService;

  TrustBloc(this._trustManagerService) : super(const TrustState()) {
    on<TrustInitialized>(_onInitialized);
    on<TrustLoadIssuers>(_onLoadIssuers);
    on<TrustAddIssuer>(_onAddIssuer);
    on<TrustRemoveIssuer>(_onRemoveIssuer);
  }

  Future<void> _onInitialized(
    TrustInitialized event,
    Emitter<TrustState> emit,
  ) async {
    add(const TrustLoadIssuers());
  }

  Future<void> _onLoadIssuers(
    TrustLoadIssuers event,
    Emitter<TrustState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final issuers = await _trustManagerService.getTrustedIssuers();
      emit(state.copyWith(
        isLoading: false,
        issuers: issuers,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAddIssuer(
    TrustAddIssuer event,
    Emitter<TrustState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      await _trustManagerService.addTrustedIssuer(
        issuerId: event.issuerId,
        name: event.name,
        publicKey: event.publicKey,
        source: event.source,
      );

      // Reload issuers
      add(const TrustLoadIssuers());

      emit(state.copyWith(
        isLoading: false,
        successMessage: 'Issuer added successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRemoveIssuer(
    TrustRemoveIssuer event,
    Emitter<TrustState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      await _trustManagerService.removeTrustedIssuer(event.issuerId);

      // Reload issuers
      add(const TrustLoadIssuers());

      emit(state.copyWith(
        isLoading: false,
        successMessage: 'Issuer removed successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
