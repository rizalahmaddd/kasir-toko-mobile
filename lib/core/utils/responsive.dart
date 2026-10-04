import 'package:flutter/widgets.dart';

extension Responsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Tablets and landscape phones get the side-by-side catalog + cart layout.
  bool get isWide => screenWidth >= 840;

  bool get isMedium => screenWidth >= 600;
}
