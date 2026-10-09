import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  test('Submitted or published adverts cannot be submitted again and erase review', () {
    expect(wonenPrivateSubmissionVisible({'publication_status': 'draft'}), isTrue);
    expect(wonenPrivateSubmissionVisible({'publication_status': 'pending'}), isFalse);
    expect(wonenPrivateSubmissionVisible({'publication_status': 'publish'}), isFalse);
  });
  ProductDetails product({String id = wonenStoreProduct, String currency = 'EUR', double price = 25}) =>
      ProductDetails(id: id, title: 'Woning of kamer', description: 'Eén maand', price: '€25',
          rawPrice: price, currencyCode: currency);
  test('Checkout remains possible for an existing open invoice or a new month after expiry', () {
    expect(wonenStoreCheckoutVisible({'publication_status': 'pending', 'payment_status': 'open'}), isTrue);
    expect(wonenStoreCheckoutVisible({'publication_status': 'pending', 'payment_status': 'paid', 'placement_expires': 99}, now: 100), isTrue);
    expect(wonenStoreCheckoutVisible({'publication_status': 'pending', 'payment_status': 'paid', 'placement_expires': 101}, now: 100), isFalse);
    expect(wonenStoreCheckoutVisible({'publication_status': 'draft', 'payment_status': 'open'}), isFalse);
    expect(wonenStoreCheckoutVisible({'publication_status': 'publish', 'payment_status': 'paid', 'placement_expires': 99}, now: 100), isFalse);
  });
  test('Store checkout requires the exact product, EUR and 25', () {
    expect(wonenStorePriceValid(product()), isTrue);
    expect(wonenStorePriceValid(product(id: 'other')), isFalse);
    expect(wonenStorePriceValid(product(currency: 'USD')), isFalse);
    expect(wonenStorePriceValid(product(price: 24.99)), isFalse);
    expect(wonenStorePriceValid(product(price: 25.01)), isFalse);
    expect(wonenStorePriceValid(product(price: double.nan)), isFalse);
  });
}
