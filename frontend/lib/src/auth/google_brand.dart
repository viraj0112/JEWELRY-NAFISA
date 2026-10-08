import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Google's official four-colour "G" mark, as used on "Sign in with Google"
/// buttons across the web. Inlined so no asset needs to be bundled.
const String _googleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

const _googleBlue = Color(0xFF4285F4);
const _googleRed = Color(0xFFEA4335);
const _googleYellow = Color(0xFFFBBC05);
const _googleGreen = Color(0xFF34A853);

/// The multicolour Google "G" logo.
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_googleGSvg, width: size, height: size);
  }
}

/// "Continue with Google" label, with "Google" in its brand colours
/// (G blue, o red, o yellow, g blue, l green, e red).
class ContinueWithGoogleLabel extends StatelessWidget {
  const ContinueWithGoogleLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      color: const Color(0xFF333333),
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    TextSpan letter(String char, Color color) => TextSpan(
          text: char,
          style: base.copyWith(color: color, fontWeight: FontWeight.w600),
        );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Continue with '),
          letter('G', _googleBlue),
          letter('o', _googleRed),
          letter('o', _googleYellow),
          letter('g', _googleBlue),
          letter('l', _googleGreen),
          letter('e', _googleRed),
        ],
      ),
    );
  }
}
