import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  ProductDetails product({String id = wonenStoreProduct, String currency = 'EUR', double price = 25}) =>
      ProductDetails(id: id, title: 'Woning of kamer', description: 'Eén maand', price: '€25',
          rawPrice: price, currencyCode: currency);
  test('Store checkout requires the exact product, EUR and 25', () {
    expect(wonenStorePriceValid(product()), isTrue);
    expect(wonenStorePriceValid(product(id: 'other')), isFalse);
    expect(wonenStorePriceValid(product(currency: 'USD')), isFalse);
    expect(wonenStorePriceValid(product(price: 24.99)), isFalse);
    expect(wonenStorePriceValid(product(price: 25.01)), isFalse);
    expect(wonenStorePriceValid(product(price: double.nan)), isFalse);
  });
}
