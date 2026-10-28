// Renders the app icon PNGs from the tingkat mark.
//
//   flutter test tool/render_icon.dart
//   dart run flutter_launcher_icons
//
// Writes assets/icon/{icon,icon_foreground,icon_monochrome}.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asrani_expenses/widgets/tingkat_mark.dart';

Future<void> _render(
  WidgetTester tester,
  String path,
  TingkatPainter painter,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: 1024,
          height: 1024,
          child: CustomPaint(painter: painter),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void main() {
  testWidgets('render icons', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Full-bleed icon for legacy Android, iOS and web.
    await _render(
      tester,
      'assets/icon/icon.png',
      const TingkatPainter(scale: 0.80, background: jade),
    );
    // Adaptive layers: flutter_launcher_icons insets these by 16%, which
    // brings the mark to ~60% of the canvas, inside the 66/108 safe zone.
    await _render(
      tester,
      'assets/icon/icon_foreground.png',
      const TingkatPainter(scale: 0.88),
    );
    // Android 13+ themed icon.
    await _render(
      tester,
      'assets/icon/icon_monochrome.png',
      const TingkatPainter(scale: 0.88, monochrome: Colors.white),
    );
  });
}
