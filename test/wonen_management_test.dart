import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  test('saved search summary keeps transaction and price filters', () {
    expect(wonenSearchSummary({'plaats': 'Rockanje', 'transactie': 'Huur', 'min_prijs': 900, 'max_prijs': 1400}), 'Rockanje · Huur · Vanaf € 900 · Tot € 1400');
  });
  testWidgets('dashboard explains inactive subscription and missing fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WonenDashboardSummary(stats: {
      'published': 2, 'draft': 1, 'subscription_active': false, 'remaining': 0,
      'unread_messages': 3, 'attention': [{'id': 12, 'title': 'Duinweg', 'missing': ['Koop/huur', 'Hoofdfoto']}],
    }))));
    expect(find.text('Nieuwe aanvragen: 3'), findsOneWidget);
    expect(find.text('Publicatieruimte: 0 woningen'), findsOneWidget);
    expect(find.text('Duinweg: Koop/huur, Hoofdfoto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved search editor exposes consent and rejects invalid prices', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WonenSearchEditor(search: {'plaats': 'Rockanje', 'transactie': 'Huur', 'max_prijs': -1, 'enabled': false}))));
    expect(find.text('Huur'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    await tester.tap(find.text('Zoekopdracht opslaan'));
    await tester.pump();
    expect(find.text('Vul een geldige prijs in zonder duizendtallen.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
  testWidgets('realtor can change existing rental listing to sale using visible selector', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningEditorPage(item: {
      'id': 12, 'transactie': 'huur', 'publication_status': 'draft',
    })));
    await tester.pumpAndSettle();
    expect(find.text('Huurwoning'), findsOneWidget);
    expect(find.byKey(const ValueKey('wonen-transactie')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wonen-transactie')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koopwoning').last);
    await tester.pumpAndSettle();
    expect(find.text('Koopwoning'), findsOneWidget);
    expect(find.text('Huurwoning'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('new property requires an explicit rental or sale choice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WoningEditorPage()));
    await tester.pumpAndSettle();
    expect(find.text('Kies huur of koop'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Woning opslaan'), 500, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Woning opslaan'));
    await tester.pumpAndSettle();
    expect(find.text('Kies of de woning te huur of te koop is.'), findsOneWidget);
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
