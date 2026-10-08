import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  test('API failures retain a specific subscription or access message', () {
    expect(const WonenApiException(403, 'Je pakketlimiet is bereikt.').toString(), 'Je pakketlimiet is bereikt.');
  });
  testWidgets('native property editor uses Dutch labels and publication choices', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningEditorPage(item: {
      'id': 12, 'title': 'Vogelgaarde', 'adres': 'Vogelgaarde', 'publication_status': 'publish',
    })));
    await tester.pumpAndSettle();
    expect(find.text('Titel'), findsOneWidget);
    expect(find.text('Omschrijving'), findsOneWidget);
    expect(find.text('Vogelgaarde'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('Woning opslaan'), 500, scrollable: find.byType(Scrollable).first);
    expect(find.text('Publiceren'), findsOneWidget);
    expect(find.text('Foto toevoegen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('office editor reflects existing website metadata', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WonenProfileForm(data: {
      'office_name': 'Test Makelaardij', 'postcode': '3235SJ', 'phone': '0612345678',
    }))));
    await tester.pumpAndSettle();
    expect(find.text('Test Makelaardij'), findsOneWidget);
    expect(find.text('Kantoornaam'), findsOneWidget);
    expect(find.text('KvK-nummer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pending application shows review status and does not offer role activation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WonenApplicationForm(
      me: const {'application': {'status': 'pending'}}, refresh: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Je makelaarsaanvraag is in behandeling bij RVAZ.'), findsOneWidget);
    expect(find.text('Abonnement aanvragen'), findsNothing);
  });
  testWidgets('error view gives clear login message and a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WonenErrorView(
      error: const WonenApiException(401, 'Log opnieuw in via Mijn RVAZ.'), retry: () => retried = true,
    ))));
    expect(find.text('Log opnieuw in via Mijn RVAZ.'), findsOneWidget);
    expect(find.textContaining('mobiele API niet beschikbaar'), findsNothing);
    await tester.tap(find.text('Opnieuw proberen'));
    expect(retried, isTrue);
  });
}
