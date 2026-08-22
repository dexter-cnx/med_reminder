import 'package:flutter/widgets.dart';

enum ResponsiveFormFactor { mobile, tablet }

class ResponsiveLayoutInfo {
  const ResponsiveLayoutInfo({
    required this.formFactor,
    required this.shapeRatio,
    required this.isLandscape,
  });

  factory ResponsiveLayoutInfo.fromSize(Size size) {
    final shortSide = size.shortestSide;
    final longSide = size.longestSide;
    final shapeRatio = longSide == 0 ? 0.0 : shortSide / longSide;

    // Ratio is the primary classification signal. The short-side guard only
    // prevents square-ish small phones/windows from being treated as tablets.
    final tabletShaped = shapeRatio >= 0.60 && shortSide >= 600;

    return ResponsiveLayoutInfo(
      formFactor: tabletShaped
          ? ResponsiveFormFactor.tablet
          : ResponsiveFormFactor.mobile,
      shapeRatio: shapeRatio,
      isLandscape: size.width > size.height,
    );
  }

  final ResponsiveFormFactor formFactor;
  final double shapeRatio;
  final bool isLandscape;

  bool get isTablet => formFactor == ResponsiveFormFactor.tablet;
  bool get isMobile => formFactor == ResponsiveFormFactor.mobile;

  double get primaryPaneFraction {
    if (!isTablet || !isLandscape) return 1;
    return 0.62;
  }

  double get secondaryPaneFraction {
    if (!isTablet || !isLandscape) return 0;
    return 1 - primaryPaneFraction;
  }
}
