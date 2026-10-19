part of 'sync_bloc.dart';

abstract class SyncEvent {
  const SyncEvent();
}

@freezed
abstract class SyncInitialised extends SyncEvent with _$SyncInitialised {
  const SyncInitialised._();

  const factory SyncInitialised() = _SyncInitialised;
}

@freezed
abstract class SyncData extends SyncEvent with _$SyncData {
  const SyncData._();

  const factory SyncData({required String qrData}) = _SyncData;
}

@freezed
abstract class SyncScanQRCode extends SyncEvent with _$SyncScanQRCode {
  const SyncScanQRCode._();

  const factory SyncScanQRCode() = _SyncScanQRCode;
}

@freezed
abstract class SyncScanNewPressed extends SyncEvent with _$SyncScanNewPressed {
  const SyncScanNewPressed._();

  const factory SyncScanNewPressed() = _SyncScanNewPressed;
}

@freezed
abstract class SyncCancel extends SyncEvent with _$SyncCancel {
  const SyncCancel._();

  const factory SyncCancel() = _SyncCancel;
}

@freezed
abstract class LoadDemoData extends SyncEvent with _$LoadDemoData {
  const LoadDemoData._();

  const factory LoadDemoData() = _LoadDemoData;
}

@freezed
abstract class DataHandled extends SyncEvent with _$DataHandled {
  const DataHandled._();

  const factory DataHandled({
    required String sourceId,
    required bool isSuccess,
    String? errorMessage,
  }) = _DataHandled;
}

@freezed
abstract class TriggerTutorial extends SyncEvent with _$TriggerTutorial {
  const TriggerTutorial._();

  const factory TriggerTutorial() = _TriggerTutorial;
}

@freezed
abstract class ResetTutorial extends SyncEvent with _$ResetTutorial {
  const ResetTutorial._();

  const factory ResetTutorial() = _ResetTutorial;
}

@freezed
abstract class DemoDataConfirmed extends SyncEvent with _$DemoDataConfirmed {
  const DemoDataConfirmed._();

  const factory DemoDataConfirmed() = _DemoDataConfirmed;
}

@freezed
abstract class CreateWalletSource extends SyncEvent with _$CreateWalletSource {
  const CreateWalletSource._();

  const factory CreateWalletSource() = _CreateWalletSource;
}
