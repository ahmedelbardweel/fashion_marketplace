import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/protected_tryon_preview.dart';

import 'capture_quality_test.dart' show body;

void main() {
  testWidgets(
    'composited pixels preserve the face and background; invalid output vanishes immediately',
    (tester) async {
      final boundary = GlobalKey();
      final generated = GlobalKey();
      Future<void> render({
        bool enabled = true,
        double outputAspect = 256 / 455,
        double observationAspect = 256 / 455,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 256,
                  height: 455,
                  child: ProtectedTryonPreview(
                    original: const ColoredBox(color: Colors.blue),
                    generated: ColoredBox(key: generated, color: Colors.red),
                    points: body(),
                    outputPoints: body(),
                    sourceAspect: 256 / 455,
                    outputAspect: outputAspect,
                    observationAspect: observationAspect,
                    region: 'upper body garment',
                    enabled: enabled,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Future<void> check({required bool clothing}) async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        Color pixel(int x, int y) {
          final i = (y * image.width + x) * 4;
          return Color.fromARGB(
            data.getUint8(i + 3),
            data.getUint8(i),
            data.getUint8(i + 1),
            data.getUint8(i + 2),
          );
        }

        expect(
          pixel(128, 55).toARGB32(),
          Colors.blue.toARGB32(),
          reason: 'Face stays original',
        );
        expect(
          pixel(5, 180).toARGB32(),
          Colors.blue.toARGB32(),
          reason: 'Background stays original',
        );
        expect(
          pixel(128, 180).toARGB32(),
          (clothing ? Colors.red : Colors.blue).toARGB32(),
        );
        image.dispose();
        expect(
          find.byKey(generated),
          findsOneWidget,
          reason: 'Remote view stays mounted for first-frame detection',
        );
      }

      await render();
      await tester.runAsync(() => check(clothing: true));
      await render(enabled: false);
      await tester.runAsync(() => check(clothing: false));
      await render(outputAspect: 16 / 9);
      await tester.runAsync(() => check(clothing: false));
      await render(observationAspect: 16 / 9);
      await tester.runAsync(() => check(clothing: false));
    },
  );
}
