import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDownloadService extends Fake implements AiModelDownloadService {
  final controller = StreamController<AiModelDownloadState>.broadcast();

  @override
  Stream<AiModelDownloadState> get stateStream => controller.stream;

  @override
  bool get isAnyDownloading => false;

  Future<void> closeStream() => controller.close();
}

class _FakeNotificationBloc extends Fake implements NotificationBloc {
  final events = <NotificationEvent>[];

  @override
  void add(NotificationEvent event) => events.add(event);
}

class _FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ro = lookupAppLocalizations(const Locale('ro'));
  const variant = AiModelVariant.qwen;
  final modelName = AiModelConfig.fromVariant(variant).displayName;

  late _FakeDownloadService service;
  late _FakeNotificationBloc notifications;
  late LoadModelBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _FakeDownloadService();
    notifications = _FakeNotificationBloc();
    bloc = LoadModelBloc(
      service,
      notifications,
      _FakeDeviceCapabilityService(),
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('ro')),
    );
  });

  tearDown(() async {
    await bloc.close();
    await service.closeStream();
  });

  Future<NotificationTypeUpdated> notificationFor(
    AiModelDownloadStatus status,
  ) async {
    bloc.add(
      LoadModelServiceStateChanged(
        serviceState: AiModelDownloadState(status: status, variant: variant),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    return notifications.events.whereType<NotificationTypeUpdated>().last;
  }

  test('download complete notification is Romanian', () async {
    final notification = await notificationFor(
      AiModelDownloadStatus.completed,
    );

    expect(notification.text, ro.aiModelReadyTitle(modelName));
    expect(notification.description, ro.aiModelDownloadedMessage(modelName));
    expect(notification.text, isNot(en.aiModelReadyTitle(modelName)));
  });

  test(
    'download failure notification and state message are Romanian',
    () async {
      final notification = await notificationFor(AiModelDownloadStatus.error);

      expect(notification.text, ro.aiModelDownloadFailedTitle);
      expect(notification.description, ro.aiModelDownloadFailedMessage);
      expect(bloc.state.errorMessage, ro.aiModelDownloadFailed);
      expect(ro.aiModelDownloadFailed, isNot(en.aiModelDownloadFailed));
    },
  );

  test('download cancelled notification is Romanian', () async {
    final notification = await notificationFor(
      AiModelDownloadStatus.cancelled,
    );

    expect(notification.text, ro.aiModelDownloadCancelledTitle);
    expect(notification.description, ro.aiModelDownloadInterruptedMessage);
  });
}
