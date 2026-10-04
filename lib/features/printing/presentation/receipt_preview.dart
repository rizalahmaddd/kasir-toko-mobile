import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_fonts.dart';

import '../receipt_layout.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

/// Draws the exact lines sent to the printer on a paper-like strip, so what you see is what prints.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, required this.lines, required this.paperWidth});

  final List<PrintLine> lines;
  final String paperWidth;

  static const _ink = AppColors.gray800;
  static const _style = TextStyle(
    fontFamily: AppFonts.monospace,
    fontFamilyFallback: AppFonts.monospaceFallbackCourierNew,
    fontSize: 12,
    height: 1.35,
    color: _ink,
    letterSpacing: 0,
  );

  String _pad(String text, int width, LineAlign align) {
    final clipped = text.length > width ? text.substring(0, width) : text;
    if (align == LineAlign.left) {
      return clipped.padRight(width);
    }
    final left = (width - clipped.length) ~/ 2;

    return (' ' * left + clipped).padRight(width);
  }

  Widget _line(PrintLine line, int width) {
    if (line.isRule) {
      return Text('-' * width, style: _style, maxLines: 1, softWrap: false);
    }
    final style = _style.copyWith(fontWeight: line.bold ? FontWeight.w700 : FontWeight.w400);
    if (line.large) {
      return Text(_pad(line.text, width ~/ 2, line.align), style: style.copyWith(fontSize: 24, height: 1.2), maxLines: 1, softWrap: false);
    }

    return Text(_pad(line.text, width, line.align), style: style, maxLines: 1, softWrap: false);
  }

  @override
  Widget build(BuildContext context) {
    final width = charsPerLine(paperWidth);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: paperWidth == '80' ? 380 : 290),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.circular(AppRadius.r4),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s18, AppSpacing.s14, AppSpacing.s22),
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final line in lines) _line(line, width)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
