import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/capture_quality.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/tryon_preparation.dart';

const top = GarmentSelection(
  id: 't',
  name: 'Shirt',
  imageUrl: 'https://example.com/t.png',
);
const pants = GarmentSelection(
  id: 'p',
  name: 'Pants',
  imageUrl: 'https://example.com/p.png',
);
List<BodyPoint> body() {
  final p = List.generate(33, (_) => const BodyPoint(.5, .2, 0, .99));
  void set(int i, double x, double y) => p[i] = BodyPoint(x, y, 0, .99);
  set(0, .5, .12);
  set(7, .44, .14);
  set(8, .56, .14);
  set(11, .28, .25);
  set(12, .72, .25);
  set(13, .22, .38);
  set(14, .78, .38);
  set(15, .18, .52);
  set(16, .82, .52);
  set(23, .36, .52);
  set(24, .64, .52);
  set(25, .37, .7);
  set(26, .63, .7);
  for (final i in [27, 29, 31]) {
    set(i, .37, .9);
  }
  for (final i in [28, 30, 32]) {
    set(i, .63, .9);
  }
  return p;
}

CaptureObservation frame({
  List<List<BodyPoint>>? poses,
  double light = 120,
  double dark = .02,
  double bright = .01,
  double backlight = 10,
  double sharpness = 140,
}) => CaptureObservation(
  poses: poses ?? [body()],
  width: 256,
  height: 455,
  luminance: light,
  darkFraction: dark,
  brightFraction: bright,
  backlight: backlight,
  sharpness: sharpness,
);

void main() {
  test(
    'output must contain one aligned body; reframing and missing joints fail',
    () {
      expect(outputMatchesBody(body(), [body()], top), isTrue);
      expect(outputMatchesBody(body(), [body(), body()], top), isFalse);
      final shifted = body()
          .map((p) => BodyPoint(p.x + .1, p.y, p.z, p.confidence))
          .toList();
      expect(outputMatchesBody(body(), [shifted], top), isFalse);
      final hidden = body()..[11] = const BodyPoint(.28, .25, 0, .1);
      expect(outputMatchesBody(body(), [hidden], top), isFalse);
    },
  );
  test(
    'requires continuous stable frames and resets after a second person',
    () {
      final gate = CaptureQualityGate();
      expect(gate.evaluate(frame(), top, Duration.zero).ready, false);
      for (var t = 500; t <= 2000; t += 500) {
        final result = gate.evaluate(frame(), top, Duration(milliseconds: t));
        expect(result.ready, t == 2000);
      }
      expect(
        gate
            .evaluate(
              frame(poses: [body(), body()]),
              top,
              const Duration(milliseconds: 2500),
            )
            .issue,
        CaptureIssue.multiplePeople,
      );
      expect(
        gate.evaluate(frame(), top, const Duration(seconds: 3)).ready,
        false,
      );
    },
  );
  test('rejects missing person, poor light, blur and non-finite metrics', () {
    for (final item in <(CaptureObservation, CaptureIssue)>[
      (frame(poses: []), CaptureIssue.noPerson),
      (frame(light: 20), CaptureIssue.dark),
      (frame(light: 240), CaptureIssue.overexposed),
      (frame(light: 80, backlight: 90), CaptureIssue.backlit),
      (frame(sharpness: 2), CaptureIssue.blurred),
      (frame(light: double.nan), CaptureIssue.unavailable),
    ]) {
      expect(
        CaptureQualityGate().evaluate(item.$1, top, Duration.zero).issue,
        item.$2,
      );
    }
  });
  test(
    'leg occlusion blocks pants but not tops; category change resets stability',
    () {
      final p = body()..[27] = const BodyPoint(.3, 1.1, 0, .2);
      final gate = CaptureQualityGate();
      expect(
        gate.evaluate(frame(poses: [p]), top, Duration.zero).issue,
        CaptureIssue.stabilizing,
      );
      expect(
        gate
            .evaluate(
              frame(poses: [p]),
              pants,
              const Duration(milliseconds: 500),
            )
            .issue,
        CaptureIssue.cropped,
      );
      gate.evaluate(frame(), top, const Duration(seconds: 1));
      gate.evaluate(frame(), top, const Duration(seconds: 2));
      expect(
        gate.evaluate(frame(), top, const Duration(seconds: 3)).ready,
        true,
      );
      expect(
        gate.evaluate(frame(), pants, const Duration(milliseconds: 3500)).ready,
        false,
      );
    },
  );
  test('movement and stale gaps invalidate calibration', () {
    final gate = CaptureQualityGate();
    gate.evaluate(frame(), top, Duration.zero);
    gate.evaluate(frame(), top, const Duration(seconds: 1));
    final shifted = body()
        .map((p) => BodyPoint(p.x + .04, p.y, p.z, p.confidence))
        .toList();
    expect(
      gate
          .evaluate(
            frame(poses: [shifted]),
            top,
            const Duration(milliseconds: 1500),
          )
          .issue,
      CaptureIssue.moving,
    );
    expect(
      gate.evaluate(frame(), top, const Duration(seconds: 10)).ready,
      false,
    );
  });
  test('crossed arms and body tilt do not block clearly visible shoulders', () {
    final crossed = body()..[15] = const BodyPoint(.5, .4, 0, .99);
    expect(
      CaptureQualityGate()
          .evaluate(frame(poses: [crossed]), top, Duration.zero)
          .issue,
      CaptureIssue.stabilizing,
    );
    final turned = body()..[11] = const BodyPoint(.28, .25, .3, .99);
    expect(
      CaptureQualityGate()
          .evaluate(frame(poses: [turned]), top, Duration.zero)
          .issue,
      CaptureIssue.stabilizing,
    );
  });
  test(
    'cropped seated portrait needs only shoulders; concealed shoulder fails',
    () {
      final p = List.generate(33, (_) => const BodyPoint(-1, -1, 0, 0));
      p[11] = const BodyPoint(.15, .65, -.2, .95);
      p[12] = const BodyPoint(.85, .48, .2, .95);
      final gate = CaptureQualityGate();
      gate.evaluate(frame(poses: [p]), top, Duration.zero);
      gate.evaluate(frame(poses: [p]), top, const Duration(seconds: 1));
      expect(
        gate.evaluate(frame(poses: [p]), top, const Duration(seconds: 2)).ready,
        true,
      );
      expect(outputMatchesBody(p, [p], top), true);
      final mask = GarmentRegionClipper(
        points: p,
        aspect: 256 / 455,
        region: top.region,
        enabled: true,
      ).getClip(const Size(256, 455));
      expect(mask.contains(const Offset(128, 360)), true);
      expect(mask.contains(const Offset(128, 70)), false);
      p[12] = const BodyPoint(.85, .48, .2, .2);
      expect(
        gate.evaluate(frame(poses: [p]), top, const Duration(seconds: 3)).issue,
        CaptureIssue.cropped,
      );
    },
  );
  test('pants and footwear do not require the face or shoulders', () {
    final p = body();
    for (var i = 0; i < 23; i++) {
      p[i] = const BodyPoint(-1, -1, 0, 0);
    }
    expect(
      CaptureQualityGate()
          .evaluate(frame(poses: [p]), pants, Duration.zero)
          .issue,
      CaptureIssue.stabilizing,
    );
    const shoes = GarmentSelection(
      id: 's',
      name: 'Shoes',
      imageUrl: 'https://example.com/s.png',
    );
    expect(
      CaptureQualityGate()
          .evaluate(frame(poses: [p]), shoes, Duration.zero)
          .issue,
      CaptureIssue.stabilizing,
    );
  });
  test('generated mask excludes face and unrelated regions', () {
    const size = Size(256, 455);
    for (final region in [
      'upper body garment',
      'lower body garment',
      'outfit',
      'footwear',
    ]) {
      final path = GarmentRegionClipper(
        points: body(),
        aspect: 256 / 455,
        region: region,
        enabled: true,
      ).getClip(size);
      expect(path.contains(const Offset(128, 55)), false, reason: region);
      expect(path.contains(const Offset(5, 220)), false, reason: region);
    }
    final lower = GarmentRegionClipper(
      points: body(),
      aspect: 256 / 455,
      region: 'lower body garment',
      enabled: true,
    ).getClip(size);
    expect(lower.contains(const Offset(128, 150)), false);
    final disabled = GarmentRegionClipper(
      points: body(),
      aspect: 256 / 455,
      region: top.region,
      enabled: false,
    ).getClip(size);
    expect(disabled.getBounds(), Rect.zero);
  });
  testWidgets('RTL preparation and checks fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: [
                  const TryonSteps(current: 0),
                  const Expanded(child: TryonIntroduction()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CaptureChecklist(
              assessment: CaptureAssessment(issue: CaptureIssue.multiplePeople),
              region: 'upper body garment',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('تبدأ التجربة تلقائياً'), findsOneWidget);
    expect(find.text(CaptureIssue.multiplePeople.message), findsOneWidget);
  });
}
