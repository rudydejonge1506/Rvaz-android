import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  testWidgets('private editor fixes sale and does not allow self-publication or promotions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningEditorPage(privateOffer: true, item: {'id': 12, 'title': 'Mijn woning', 'transactie': 'Koop', 'publication_status': 'publish'})));
    await tester.pumpAndSettle();
    expect(find.text('Particuliere verkoopwoning. Na elke wijziging is opnieuw beoordeling door RVAZ nodig.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Woning opslaan'), 500, scrollable: find.byType(Scrollable).first);
    expect(find.text('Publiceren'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Promoot als nieuws (€29)'), findsNothing);
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
