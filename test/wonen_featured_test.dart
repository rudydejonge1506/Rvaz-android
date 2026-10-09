import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';
import 'package:rvaz_android/wonen_featured.dart';

void main() {
  testWidgets('Empty paid feed hides the housing block', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeaturedHomes(items: Future.value([])))));
    await tester.pump();
    expect(find.text('Uitgelichte woningen'), findsNothing);
  });
  testWidgets('Paid housing card opens native details on narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeaturedHomes(items: Future.value([
      {'id': 1, 'title': 'Dorpsstraat 12', 'plaats': 'Rockanje', 'prijs': '425.000', 'transactie': 'Koop'}
    ])))));
    await tester.pumpAndSettle();
    expect(find.text('Uitgelichte woningen'), findsOneWidget);
    expect(find.text('Rockanje'), findsOneWidget);
    expect(find.text('425.000 · Koop'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Dorpsstraat 12'));
    await tester.pumpAndSettle();
    expect(find.byType(WoningDetailPage), findsOneWidget);
  });
}
