part of 'import_bloc.dart';

@freezed
class ImportEvent with _$ImportEvent {
  const factory ImportEvent.importDocument() = ImportDocumentPressed;
  const factory ImportEvent.pickImage() = PickImagePressed;
  const factory ImportEvent.externalFilesReceived({
    required List<String> filePaths,
  }) = ExternalFilesReceived;
}
