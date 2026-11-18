enum AppPlatform {
  mobile,
  desktop;

  bool get isDesktop => this == AppPlatform.desktop;
  bool get isMobile => this == AppPlatform.mobile;
}
