import 'package:health_wallet/core/services/device_capability_service.dart';

/// Whether Deep Scan (the vision model) is on when the user has not chosen.
///
/// The desktop has the memory for it; on a phone it is opt-in. Every screen
/// and the processing pipeline read the default from here, so they agree.
bool defaultDeepScan(bool isDesktop) => isDesktop;

/// Whether step two reads the pages with the vision model: Deep Scan is on
/// and the device has the memory for it. On a device without that memory
/// step two still runs, from the recognised text.
bool deepScanRuns({
  required bool deepScanOn,
  required DeviceAiCapability capability,
}) => deepScanOn && capability != DeviceAiCapability.basicOnly;
