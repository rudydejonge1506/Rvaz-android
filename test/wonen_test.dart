import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  group('Wonen API response parsing', () {
    test('accepts direct listing arrays', () {
      final items = wonenItems([{'id': 1, 'title': 'Testwoning'}]);
      expect(items, hasLength(1));
      expect(wonenText(items.single, 'title'), 'Testwoning');
    });

    test('accepts items envelope', () {
      expect(wonenItems({'items': [{'id': 2}]}).single['id'], 2);
    });

    test('accepts data and results envelopes', () {
      expect(wonenItems({'data': [{'id': 3}]}).single['id'], 3);
      expect(wonenItems({'results': [{'id': 4}]}).single['id'], 4);
    });

    test('rejects invalid listing payloads safely', () {
      expect(wonenItems(null), isEmpty);
      expect(wonenItems({'items': 'invalid'}), isEmpty);
      expect(wonenItems([null, 4, {'id': 5}]), hasLength(1));
    });

    test('renders absent property values as empty strings', () {
      expect(wonenText({'title': 'Huis'}, 'missing'), '');
      expect(wonenText({'prijs': 125000}, 'prijs'), '125000');
    });
  });
}
