import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_ai/shared/motion/motion.dart';
import 'package:pantry_ai/shared/widgets/frigo_illustration.dart';

void main() {
  group('illustrations', () {
    test('every FrigoArt has a file on disk', () {
      for (final art in FrigoArt.values) {
        expect(File(art.path).existsSync(), isTrue,
            reason: 'missing asset: ${art.path}');
      }
    });

    test('every illustration is valid, self-contained SVG', () {
      for (final art in FrigoArt.values) {
        final svg = File(art.path).readAsStringSync();
        expect(svg.trimLeft(), startsWith('<svg'), reason: art.path);
        expect(svg.trimRight(), endsWith('</svg>'), reason: art.path);
        // flutter_svg cannot render filters, and a remote href would mean the
        // scene silently breaks offline.
        expect(svg, isNot(contains('<filter')), reason: art.path);
        expect(svg, isNot(contains('http://www.w3.org/1999/xlink')),
            reason: art.path);
      }
    });

    test('assets/illustrations is declared in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/illustrations/'));
    });
  });

  group('reduce motion', () {
    /// Builds [child] with the platform's "disable animations" flag set, the
    /// way an accessibility setting would.
    Widget reduced(Widget child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Directionality(textDirection: TextDirection.ltr, child: child),
        );

    testWidgets('FadeSlideIn renders its child immediately, fully opaque',
        (tester) async {
      await tester.pumpWidget(reduced(
        const FadeSlideIn(index: 5, child: Text('hello')),
      ));

      // No pump past the first frame: with motion reduced there is no
      // entrance to wait through, so a staggered row must not start invisible.
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(Transform), findsNothing);
    });

    testWidgets('AnimatedCounter shows the final value, not a tween',
        (tester) async {
      await tester.pumpWidget(reduced(const AnimatedCounter(42, suffix: ' x')));
      expect(find.text('42 x'), findsOneWidget);
    });

    testWidgets('AnimatedCounter does count up when motion is allowed',
        (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: AnimatedCounter(42),
      ));
      await tester.pump();
      expect(find.text('42'), findsNothing, reason: 'should start below 42');
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
    });
  });

  test('ingredient catalog is still valid JSON with every name verified', () {
    final raw = File('assets/data/ingredients.json').readAsStringSync();
    final names = (jsonDecode(raw) as List).cast<String>();
    expect(names.length, greaterThan(800));
    expect(names.toSet().length, names.length, reason: 'duplicate entries');
    expect(names.every((n) => n.trim() == n && n.isNotEmpty), isTrue);
  });
}
