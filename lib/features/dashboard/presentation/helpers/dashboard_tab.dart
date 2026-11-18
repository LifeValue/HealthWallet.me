/// Indexes of the dashboard's pages.
///
/// The phone has Home, Records, Scan and Import. The desktop has no Scan
/// page, so its Import page sits one place earlier, and a Handover page
/// follows it while a transfer from the phone is open.
abstract final class DashboardTab {
  static const home = 0;
  static const records = 1;

  /// Phone only: the desktop has no Scan page.
  static const scan = 2;

  static int import({required bool isDesktop}) => isDesktop ? 2 : 3;

  /// Desktop only, and only while a handover is open.
  static const handover = 3;
}
