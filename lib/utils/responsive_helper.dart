import 'package:flutter/material.dart';

/// Responsive breakpoints and helper functions for adaptive layouts
class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1800;

  /// Check if current device is mobile-sized
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if current device is tablet-sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if current device is desktop-sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Check if current device is large desktop-sized
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeDesktopBreakpoint;
  }

  /// Get device type
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    if (width < desktopBreakpoint) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }

  /// Get number of grid columns based on screen width
  static int getGridCrossAxisCount(BuildContext context, {
    int mobileCount = 2,
    int tabletCount = 3,
    int desktopCount = 4,
    int largeDesktopCount = 5,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return mobileCount;
    if (width < tabletBreakpoint) return tabletCount;
    if (width < desktopBreakpoint) return desktopCount;
    return largeDesktopCount;
  }

  /// Get optimal child aspect ratio for property cards based on screen
  static double getPropertyCardAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 0.7; // Taller cards on mobile
    if (width < tabletBreakpoint) return 0.75;
    if (width < desktopBreakpoint) return 0.72;
    return 0.7; // Consistent ratio on large screens
  }

  /// Get sidebar width for desktop navigation
  static double getSidebarWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= largeDesktopBreakpoint) return 280;
    if (width >= desktopBreakpoint) return 250;
    return 220;
  }

  /// Get optimal content padding based on screen size
  static EdgeInsets getContentPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return const EdgeInsets.all(16);
    if (width < tabletBreakpoint) return const EdgeInsets.all(20);
    if (width < desktopBreakpoint) return const EdgeInsets.all(24);
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
  }

  /// Get max content width for centering content on large screens
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < desktopBreakpoint) return double.infinity;
    if (width < largeDesktopBreakpoint) return 1200;
    return 1400;
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// Widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints)? tablet;
  final Widget Function(BuildContext context, BoxConstraints constraints)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveHelper.isDesktop(context) && desktop != null) {
          return desktop!(context, constraints);
        }
        if (ResponsiveHelper.isTablet(context) && tablet != null) {
          return tablet!(context, constraints);
        }
        return mobile(context, constraints);
      },
    );
  }
}

/// Responsive value selector - returns different values based on screen size
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  if (ResponsiveHelper.isDesktop(context) && desktop != null) {
    return desktop;
  }
  if (ResponsiveHelper.isTablet(context) && tablet != null) {
    return tablet;
  }
  return mobile;
}
