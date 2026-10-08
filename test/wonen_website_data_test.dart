import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  test('vult echte kenmerken van woningwebsite aan zonder WebView', () {
    const html = '''
    <main><article>
      <h1>Vogelgaarde</h1><p>3235SJ Rockanje</p><p>€ 1.299 p/m</p>
      <section><h2>Kenmerken</h2>
        <p>Soort woning</p><p>Woning</p>
        <p>Aanbod</p><p>Huur</p>
        <p>Status</p><p>Beschikbaar</p>
        <p>Woonoppervlakte</p><p>120 m²</p>
        <p>Energielabel</p><p>A++++</p>
      </section>
    </article></main>
    ''';
    final item = mergeWoningWebsiteData(
      <String, dynamic>{'title': 'Nieuwe woning', 'prijs': false,
        'adres': false, 'woonoppervlak': false}, html);
    expect(item['adres'], 'Vogelgaarde');
    expect(item['plaats'], 'Rockanje');
    expect(item['postcode'], '3235SJ');
    expect(item['prijs'], '1.299 p/m');
    expect(item['woonoppervlak'], '120 m²');
    expect(item['energielabel'], 'A++++');
    expect(item['transactie'], 'Huur');
    expect(wonenText(item, 'adres'), 'Vogelgaarde');
  });

  test('ontbrekende kenmerken worden niet als false of null getoond', () {
    final result = mergeWoningWebsiteData(
      <String, dynamic>{'prijs': false, 'plaats': null, 'title': 'Test'},
      '<main><article><h1>Testwoning</h1></article></main>',
    );
    expect(wonenText(result, 'prijs'), '');
    expect(wonenText(result, 'plaats'), '');
  });
}
