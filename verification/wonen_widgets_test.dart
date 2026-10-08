import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  testWidgets('native detail toont adres, prijs en kenmerken van het woningblok', (tester) async {
    final item = mergeWoningWebsiteData({'title': 'Nieuwe woning'},
        File('test/fixtures/woning-website.html').readAsStringSync());
    // Network photos have separate device checks; keep this renderer test deterministic.
    item.remove('image');
    item.remove('photos');
    await tester.pumpWidget(MaterialApp(home: WoningDetailPage(item: item)));
    await tester.pumpAndSettle();
    expect(find.text('Vogelgaarde'), findsNWidgets(2));
    expect(find.text('Nieuwe woning'), findsNothing);
    expect(find.text('3235SJ Rockanje'), findsOneWidget);
    expect(find.text('€ 1.299 p/m'), findsOneWidget);
    expect(find.text('120 m²'), findsOneWidget);
    expect(find.text('A++++'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../verification/screenshots/wonen-detail.png'));
  });

  testWidgets('native detail blijft bruikbaar als de API kenmerken mist', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningDetailPage(
        item: {'title': 'Woning', 'prijs': false, 'adres': false})));
    await tester.pumpAndSettle();
    expect(find.text('false'), findsNothing);
    expect(find.text('null'), findsNothing);
    expect(find.text('€ '), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
