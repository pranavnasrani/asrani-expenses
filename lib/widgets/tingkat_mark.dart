import 'package:flutter/material.dart';

const jade = Color(0xFF1E6F66);
const butter = Color(0xFFF2C14E);
const butterRim = Color(0xFFD9A532);
const coral = Color(0xFFE07A93);
const coralRim = Color(0xFFB84A68);
const enamel = Color(0xFFFFFFFF);
const enamelRim = Color(0xFFCFE0DB);
const steel = Color(0xFFDCE7E3);

/// Three stacked enamel tiers with a carry handle. [monochrome] draws every
/// part in one colour for Android themed icons.
class TingkatPainter extends CustomPainter {
  final double scale;
  final Color? background;
  final Color? monochrome;

  const TingkatPainter({required this.scale, this.background, this.monochrome});

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }
    final s = size.width * scale;
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    Offset p(double x, double y) => origin + Offset(x * s, y * s);
    Color c(Color color) => monochrome ?? color;

    // Carrying frame: rails down both sides of the stack, joined across
    // the top, with a grip in the middle. This is what makes it a tingkat.
    final frame = Path()
      ..moveTo(p(0.15, 0.86).dx, p(0.15, 0.86).dy)
      ..lineTo(p(0.15, 0.22).dx, p(0.15, 0.22).dy)
      ..arcToPoint(p(0.23, 0.14), radius: Radius.circular(0.08 * s))
      ..lineTo(p(0.77, 0.14).dx, p(0.77, 0.14).dy)
      ..arcToPoint(p(0.85, 0.22), radius: Radius.circular(0.08 * s))
      ..lineTo(p(0.85, 0.86).dx, p(0.85, 0.86).dy);
    final framePaint = Paint()
      ..color = c(steel)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.04 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(frame, framePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.36, 0.105), p(0.64, 0.175)),
        Radius.circular(0.035 * s),
      ),
      Paint()..color = c(butter),
    );

    const h = 0.19;
    void tier(double top, Color body, Color rim) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.21, top), p(0.79, top + h)),
        Radius.circular(0.06 * s),
      );
      // Latch tabs where the tier clips onto the frame.
      final tab = Paint()..color = c(steel);
      for (final x in [0.13, 0.75]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromPoints(
              p(x, top + h / 2 - 0.022),
              p(x + 0.12, top + h / 2 + 0.022),
            ),
            Radius.circular(0.02 * s),
          ),
          tab,
        );
      }
      canvas.drawRRect(rect, Paint()..color = c(body));
      if (monochrome != null) return;
      // Painted rim band across the top of each tier.
      canvas.save();
      canvas.clipRRect(rect);
      canvas.drawRect(
        Rect.fromPoints(p(0.21, top), p(0.79, top + 0.042)),
        Paint()..color = rim,
      );
      canvas.restore();
    }

    tier(0.25, butter, butterRim);
    tier(0.47, coral, coralRim);
    tier(0.69, enamel, enamelRim);

    // Gaps between tiers read as the latch line in monochrome.
    if (monochrome != null) {
      final gap = Paint()..blendMode = BlendMode.clear;
      for (final y in [0.44, 0.66]) {
        canvas.drawRect(Rect.fromPoints(p(0.19, y), p(0.81, y + 0.03)), gap);
      }
    }
  }

  @override
  bool shouldRepaint(TingkatPainter old) => false;
}

/// The app mark, as used on the login screen and in the launcher icon.
class TingkatMark extends StatelessWidget {
  final double size;
  const TingkatMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: TingkatPainter(scale: 1)),
  );
}
