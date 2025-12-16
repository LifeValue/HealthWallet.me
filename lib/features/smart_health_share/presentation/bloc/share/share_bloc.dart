import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/entities/shc_share_result.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/repositories/share_repository.dart';
import 'package:injectable/injectable.dart';

part 'share_event.dart';
part 'share_state.dart';
part 'share_bloc.freezed.dart';

@injectable
class ShareBloc extends Bloc<ShareEvent, ShareState> {
  final ShareRepository _shareRepository;
  final RecordsRepository _recordsRepository;

  ShareBloc(
    this._shareRepository,
    this._recordsRepository,
  ) : super(const ShareState()) {
    on<ShareInitialized>(_onInitialized);
    on<ShareLoadResources>(_onLoadResources);
    on<ShareResourcesSelected>(_onResourcesSelected);
    on<ShareGenerateQrCode>(_onGenerateQrCode);
    on<ShareReset>(_onReset);
  }

  Future<void> _onInitialized(
    ShareInitialized event,
    Emitter<ShareState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: false,
      errorMessage: null,
      qrCodeData: null,
      shareResult: null,
    ));
    // Load resources when initialized
    add(const ShareEvent.loadResources());
  }

  Future<void> _onLoadResources(
    ShareLoadResources event,
    Emitter<ShareState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      // Load all available resources (excluding Patient as it's automatically included)
      final resources = await _recordsRepository.getResources(
        resourceTypes: [],
        limit: 1000, // Load a large number of resources
      );

      // Filter out Patient resources as they're automatically included
      final filteredResources =
          resources.where((r) => r.fhirType != FhirType.Patient).toList();

      emit(state.copyWith(
        isLoading: false,
        availableResources: filteredResources,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load resources: $e',
      ));
    }
  }

  Future<void> _onResourcesSelected(
    ShareResourcesSelected event,
    Emitter<ShareState> emit,
  ) async {
    emit(state.copyWith(selectedResourceIds: event.resourceIds));
  }

  Future<void> _onGenerateQrCode(
    ShareGenerateQrCode event,
    Emitter<ShareState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      qrCodeData: null,
    ));

    try {
      final result = await _shareRepository.generateHealthCard(
        resourceIds: event.resourceIds,
        issuerUrl: event.issuerUrl,
        sourceId: event.sourceId,
      );

      emit(state.copyWith(
        isLoading: false,
        qrCodeData: result.qrCodeData,
        shareResult: result,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onReset(
    ShareReset event,
    Emitter<ShareState> emit,
  ) async {
    emit(const ShareState());
  }
}
