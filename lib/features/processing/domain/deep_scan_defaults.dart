/// Whether Deep Scan (the vision model) is on when the user has not chosen.
///
/// The desktop has the memory for it; on a phone it is opt-in. Every screen
/// and the processing pipeline read the default from here, so they agree.
bool defaultDeepScan(bool isDesktop) => isDesktop;
