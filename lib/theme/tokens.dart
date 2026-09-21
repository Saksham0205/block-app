import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Colour system. Near-black canvas, two loud accents with clear jobs:
/// [violet] means "yours / selected", [coral] means "locked right now".
abstract final class AppColors {
  static const bg = Color(0xFF0D0D0D);
  static const surface = Color(0xFF171717);
  static const surfaceHigh = Color(0xFF222222);
  static const line = Color(0xFF2E2E2E);

  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFF8E8E93);

  static const violet = Color(0xFF7C5CFF);
  static const coral = Color(0xFFFF4D67);
  static const white = Color(0xFFFFFFFF);
}

/// Type scale. One family (Urbanist – geometric, close to CRED's Gilroy),
/// heavy weights for numerals and headings, medium for reading text.
abstract final class AppText {
  static TextStyle _u(double size, FontWeight w,
          {double ls = 0, double h = 1.2, Color color = AppColors.text}) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: w,
        letterSpacing: ls,
        height: h,
        color: color,
      );

  /// Giant status number.
  static TextStyle get display => _u(76, FontWeight.w800, ls: -3, h: 1);

  /// Page titles.
  static TextStyle get title => _u(38, FontWeight.w800, ls: -1.2);

  /// Big time readout on cards and pickers.
  static TextStyle get numeral => _u(30, FontWeight.w800, ls: -0.8, h: 1.1);

  static TextStyle get heading => _u(22, FontWeight.w700, ls: -0.4);
  static TextStyle get subheading => _u(17, FontWeight.w700, ls: -0.1);
  static TextStyle get body => _u(15, FontWeight.w500, h: 1.4);
  static TextStyle get bodyMuted =>
      _u(15, FontWeight.w500, h: 1.4, color: AppColors.muted);
  static TextStyle get caption =>
      _u(13, FontWeight.w600, color: AppColors.muted);
  static TextStyle get button => _u(17, FontWeight.w800, ls: 0.1, h: 1);
}
