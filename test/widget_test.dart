import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nms_mobile/widgets/status_badge.dart';

void main() {
  // ── StatusBadge widget tests ────────────────────────────────────────

  group('StatusBadge', () {
    Widget wrap(Widget child) =>
        MaterialApp(home: Scaffold(body: Center(child: child)));

    testWidgets('shows SUW label', (tester) async {
      await tester.pumpWidget(wrap(const StatusBadge(status: 'SUW')));
      expect(find.text('SUW'), findsOneWidget);
    });

    testWidgets('shows UW label', (tester) async {
      await tester.pumpWidget(wrap(const StatusBadge(status: 'UW')));
      expect(find.text('UW'), findsOneWidget);
    });

    testWidgets('shows Normal label', (tester) async {
      await tester.pumpWidget(wrap(const StatusBadge(status: 'Normal')));
      expect(find.text('Normal'), findsOneWidget);
    });

    testWidgets('shows SW label', (tester) async {
      await tester.pumpWidget(wrap(const StatusBadge(status: 'SW')));
      expect(find.text('SW'), findsOneWidget);
    });

    testWidgets('shows MW label', (tester) async {
      await tester.pumpWidget(wrap(const StatusBadge(status: 'MW')));
      expect(find.text('MW'), findsOneWidget);
    });

    testWidgets('renders empty status without crashing', (tester) async {
      await tester.pumpWidget(wrap(const StatusBadge(status: '')));
      expect(tester.takeException(), isNull);
    });
  });

  // ── Z-score classification logic tests (pure Dart) ─────────────────

  group('WFA classification thresholds', () {
    String classifyWfa(double z) {
      if (z < -3.0) return 'SUW';
      if (z < -2.0) return 'UW';
      if (z <= 2.0) return 'Normal';
      if (z <= 3.0) return 'OW';
      return 'OB';
    }

    test('z < -3.0 is SUW',    () => expect(classifyWfa(-3.1), 'SUW'));
    test('z = -3.0 is UW',     () => expect(classifyWfa(-3.0), 'UW'));
    test('z = -2.0 is Normal', () => expect(classifyWfa(-2.0), 'Normal'));
    test('z = 0.0 is Normal',  () => expect(classifyWfa(0.0),  'Normal'));
    test('z = 2.0 is Normal',  () => expect(classifyWfa(2.0),  'Normal'));
    test('z = 2.5 is OW',      () => expect(classifyWfa(2.5),  'OW'));
    test('z = 3.1 is OB',      () => expect(classifyWfa(3.1),  'OB'));
  });

  group('WFL/H classification thresholds', () {
    String classifyWflh(double z) {
      if (z < -3.0) return 'SW';
      if (z < -2.0) return 'MW';
      if (z <= 2.0) return 'Normal';
      if (z <= 3.0) return 'Risk OW';
      return 'OW';
    }

    test('z < -3.0 is SW',     () => expect(classifyWflh(-3.1), 'SW'));
    test('z = -3.0 is MW',     () => expect(classifyWflh(-3.0), 'MW'));
    test('z = -2.0 is Normal', () => expect(classifyWflh(-2.0), 'Normal'));
    test('z = 0.0 is Normal',  () => expect(classifyWflh(0.0),  'Normal'));
    test('z = 2.5 is Risk OW', () => expect(classifyWflh(2.5),  'Risk OW'));
    test('z = 3.1 is OW',      () => expect(classifyWflh(3.1),  'OW'));
  });
}
