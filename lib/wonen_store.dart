part of 'wonen.dart';

const wonenStoreProduct = 'rvaz.wonen.particulier.maand';

bool wonenStorePriceValid(ProductDetails product) =>
    product.id == wonenStoreProduct && product.currencyCode == 'EUR' &&
    (product.rawPrice - 25).abs() < 0.001;

bool wonenStoreCheckoutVisible(Map<String, dynamic> row, {int? now}) {
  if (wonenText(row, 'publication_status') != 'pending') return false;
  final payment = wonenText(row, 'payment_status');
  if (['not_ordered', 'cancelled', 'open', ''].contains(payment)) return true;
  final end = int.tryParse('${row['placement_expires']}') ?? 0;
  return payment == 'paid' && end > 0 && end <= (now ?? DateTime.now().millisecondsSinceEpoch ~/ 1000);
}

class WonenStorePayments extends ChangeNotifier {
  static final instance = WonenStorePayments();
  final storage = const FlutterSecureStorage();
  StreamSubscription<List<PurchaseDetails>>? subscription;
  Future<void>? initialization;
  Future<void> events = Future.value();
  Map<String, dynamic>? pending;
  PurchaseDetails? lastPurchase;
  String message = '';
  bool busy = false;
  int verified = 0;
  String get provider => defaultTargetPlatform == TargetPlatform.iOS ? 'apple' : 'google';
  Future<void> initialize() => initialization ??= _initialize();
  Future<void> _initialize() async {
    if (kIsWeb || ![TargetPlatform.iOS, TargetPlatform.android].contains(defaultTargetPlatform)) return;
    try {
      final saved = await storage.read(key: 'rvaz_wonen_store_pending');
      if (saved != null) pending = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      subscription = InAppPurchase.instance.purchaseStream.listen((purchases) async {
        for (final purchase in purchases) { events = events.then((_) => handle(purchase)); }
        await events;
      }, onError: (_) { message = 'De betaalwinkel is tijdelijk niet beschikbaar. Probeer opnieuw.'; busy = false; notifyListeners(); });
    } catch (_) { message = 'De veilige betaalgegevens konden niet worden geopend.'; }
  }
  Future<ProductDetails> product() async {
    await initialize();
    if (!await InAppPurchase.instance.isAvailable()) throw StateError('De betaalwinkel is niet beschikbaar op dit apparaat.');
    final response = await InAppPurchase.instance.queryProductDetails({wonenStoreProduct});
    if (response.error != null || response.productDetails.length != 1 ||
        !wonenStorePriceValid(response.productDetails.single)) {
      throw StateError('De plaatsing van €25 is nog niet beschikbaar in deze betaalwinkel. Er is niets afgeschreven.');
    }
    return response.productDetails.single;
  }
  Future<void> buy(int property, ProductDetails details) async {
    await initialize();
    if (busy) return;
    if (pending != null) throw StateError('Er staat nog een aankoop open. Bevestig die eerst opnieuw.');
    if (!wonenStorePriceValid(details)) throw StateError('De winkelprijs komt niet overeen met €25.');
    busy = true; message = 'Aankoop voorbereiden…'; notifyListeners();
    try {
      final intent = Map<String, dynamic>.from(await wonenRequest('/winkel/intentie', body: {'property_id': property, 'provider': provider}) as Map);
      if (intent['product'] != wonenStoreProduct || intent['amount'] != '25.00' || intent['currency'] != 'EUR' || intent['period'] != '1_month') throw StateError('De plaatsingsprijs kon niet worden bevestigd.');
      pending = intent;
      await storage.write(key: 'rvaz_wonen_store_pending', value: jsonEncode(intent));
      final opened = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details, applicationUserName: '${intent['id']}'),
        autoConsume: false);
      if (!opened) { await clear(); throw StateError('De betaalwinkel kon niet worden geopend.'); }
      message = 'Bevestig de aankoop in de betaalwinkel.';
    } catch (error) { busy = false; message = '$error'; rethrow; }
    finally { notifyListeners(); }
  }
  Future<void> clear() async { pending = null; await storage.delete(key: 'rvaz_wonen_store_pending'); }
  Future<void> handle(PurchaseDetails purchase) async {
    if (purchase.productID != wonenStoreProduct) return;
    lastPurchase = purchase;
    if (purchase.status == PurchaseStatus.pending) { busy = true; message = 'Betaling wacht op bevestiging. Je woning is nog niet geactiveerd.'; notifyListeners(); return; }
    if (purchase.status == PurchaseStatus.error || purchase.status == PurchaseStatus.canceled) {
      busy = false; message = purchase.status == PurchaseStatus.canceled ? 'Aankoop geannuleerd.' : 'De aankoop is niet gelukt. Er is geen plaatsing geactiveerd.';
      // Failed and cancelled transactions grant nothing. Finish only these terminal states.
      if (purchase.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(purchase);
      await clear(); notifyListeners(); return;
    }
    if (purchase.status != PurchaseStatus.purchased && purchase.status != PurchaseStatus.restored) return;
    try {
      if (pending == null) throw StateError('Deze aankoop moet door RVAZ worden gekoppeld. Er is geen woning geactiveerd.');
      busy = true; message = 'Betaling veilig controleren…'; notifyListeners();
      final data = purchase.verificationData.serverVerificationData;
      if (data.isEmpty) throw StateError('Het betalingsbewijs ontbreekt.');
      pending!['verification_data'] = data;
      await storage.write(key: 'rvaz_wonen_store_pending', value: jsonEncode(pending));
      final result = await wonenRequest('/winkel/bevestigen', body: {'intent_id': pending!['id'], 'verification_data': data});
      if (result is! Map || result['verified'] != true) throw StateError('De server heeft de betaling nog niet bevestigd.');
      if (provider == 'google') {
        final addition = InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final consumed = await addition.consumePurchase(purchase);
        if (consumed.responseCode != BillingResponse.ok && consumed.responseCode != BillingResponse.itemNotOwned) throw StateError('Betaling bevestigd. De betaalwinkel moet de aankoop nog afronden. Probeer opnieuw.');
      }
      if (purchase.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(purchase);
      await clear(); verified++;
      message = result['test'] == true ? 'Testbetaling geslaagd. Er is geen echte woning gepubliceerd.' : 'Betaling bevestigd. Je plaatsing is geactiveerd.';
    } catch (error) { message = '$error'; }
    finally { busy = false; notifyListeners(); }
  }
  Future<void> retry() async {
    await initialize();
    if (lastPurchase != null) { await handle(lastPurchase!); return; }
    // Ask the store for uncompleted transactions; do not start another charge.
    await InAppPurchase.instance.restorePurchases();
  }
}

class WonenStoreCheckout extends StatefulWidget {
  final int id;
  final VoidCallback refresh;
  const WonenStoreCheckout({super.key, required this.id, required this.refresh});
  @override
  State<WonenStoreCheckout> createState() => _WonenStoreCheckoutState();
}
class _WonenStoreCheckoutState extends State<WonenStoreCheckout> {
  final payments = WonenStorePayments.instance;
  ProductDetails? details;
  String? error;
  bool loading = true, testOnly = true;
  int verified = 0;
  @override
  void initState() { super.initState(); verified = payments.verified; payments.addListener(changed); load(); }
  @override
  void dispose() { payments.removeListener(changed); super.dispose(); }
  void changed() {
    if (!mounted) return;
    setState(() {});
    if (verified != payments.verified) { verified = payments.verified; widget.refresh(); }
  }
  Future<void> load() async {
    try {
      final catalog = await wonenRequest('/winkel/catalogus?property_id=${widget.id}');
      if (catalog is! Map || catalog[payments.provider] != true) throw StateError('Betalen via deze winkel is nog niet beschikbaar.');
      if (catalog['eligible'] != true) throw StateError('${catalog['message'] ?? 'RVAZ moet deze woning eerst goedkeuren.'}');
      testOnly = catalog['test_only'] == true;
      final result = await payments.product();
      if (mounted) setState(() => details = result);
    } catch (exception) { if (mounted) setState(() => error = '$exception'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('€25 voor één woning of kamer, één kalendermaand vanaf publicatie. Geen automatische verlenging. RVAZ beoordeelt eerst je advertentie.'),
    if (loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
    if (error != null) Text(error!),
    if (details != null) ...[
      if (testOnly) const Text('Testmodus: testbetalingen publiceren geen echte advertentie.'),
      FilledButton.icon(icon: const Icon(Icons.payment), label: Text('Plaatsing kopen · ${details!.price}'),
        onPressed: payments.busy || payments.pending != null ? null : () async {
          if (!await wonenConfirm(context, 'Eén maand plaatsing', '${details!.price} voor één woning of kamer. Geen automatische verlenging.${testOnly ? ' Dit is een testbetaling; er wordt geen echte advertentie gepubliceerd.' : ''}')) return;
          try { await payments.buy(widget.id, details!); } catch (_) {}
        }),
    ],
    if (payments.message.isNotEmpty) Text(payments.message),
    if (payments.pending != null) TextButton(onPressed: payments.busy ? null : payments.retry, child: const Text('Openstaande aankoop opnieuw controleren')),
  ]);
}
