import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  test('rental-only fields never appear for sale or an unknown transaction', () {
    for (final key in ['borg', 'contractduur', 'inkomenseisen']) {
      expect(wonenFieldVisible(key, 'Huur'), isTrue);
      expect(wonenFieldVisible(key, 'Koop'), isFalse);
      expect(wonenFieldVisible(key, ''), isFalse);
    }
    expect(wonenFieldVisible('prijstype', 'Koop'), isTrue);
    expect(wonenFieldVisible('prijstype', 'Huur'), isFalse);
    expect(wonenFieldVisible('balkon', 'Koop'), isTrue);
  });
  testWidgets('switching transaction updates private and broker fields and retains input', (tester) async {
    for (final privateOffer in [true, false]) {
      await tester.pumpWidget(MaterialApp(home: WoningEditorPage(key: ValueKey(privateOffer), privateOffer: privateOffer, item: const {'id': 13, 'transactie': 'Huur', 'borg': '650'})));
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.widgetWithText(TextField, 'Borg'), 400, scrollable: scrollable);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Borg')).controller!.text, '650');
      await tester.drag(scrollable, const Offset(0, 5000)); await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wonen-transactie'))); await tester.pumpAndSettle();
      await tester.tap(find.text('Koopwoning').last); await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.widgetWithText(TextField, 'Prijstype (k.k./v.o.n.)'), 400, scrollable: scrollable);
      expect(find.widgetWithText(TextField, 'Borg'), findsNothing);
      await tester.drag(scrollable, const Offset(0, 5000)); await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wonen-transactie'))); await tester.pumpAndSettle();
      await tester.tap(find.text('Huurwoning').last); await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.widgetWithText(TextField, 'Borg'), 400, scrollable: scrollable);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Borg')).controller!.text, '650');
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('private editor allows housing types and does not allow self-publication or promotions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningEditorPage(privateOffer: true, item: {'id': 12, 'title': 'Mijn woning', 'transactie': 'Koop', 'publication_status': 'publish'})));
    await tester.pumpAndSettle();
    expect(find.text('Particulier aanbod: koopwoning, huurwoning of kamer. Na elke wijziging is opnieuw beoordeling door RVAZ nodig.'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Woning opslaan'), 500, scrollable: find.byType(Scrollable).first);
    expect(find.text('Publiceren'), findsNothing);
    expect(find.text('Promoot als nieuws (€29)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('private rental room retains selected transaction', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningEditorPage(privateOffer: true, item: {'id': 13, 'title': 'Kamer', 'transactie': 'Huur', 'woningtype': 'Kamer'})));
    await tester.pumpAndSettle();
    expect(find.text('Huurwoning'), findsOneWidget);
    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('wonen-transactie'))).initialValue, 'Huur');
    expect(tester.takeException(), isNull);
  });
  testWidgets('native contact form requires sender details before sending', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WonenContactPage(id: 12)));
    await tester.tap(find.text('Reactie sturen'));
    await tester.pump();
    expect(find.text('Vul naam, e-mail en bericht in.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
