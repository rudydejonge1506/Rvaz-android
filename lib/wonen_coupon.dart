part of 'wonen.dart';

typedef WonenRequester = Future<dynamic> Function(String path, {Map<String, dynamic>? body});

class WonenCouponQuote {
  final String code;
  final String? total;
  final bool ready;
  const WonenCouponQuote(this.code, this.total, this.ready);
}

class WonenCouponField extends StatefulWidget {
  final String audience, normalPrice, defaultPrice;
  final String? plan;
  final bool returning;
  final ValueChanged<WonenCouponQuote> onChanged;
  final WonenRequester? request;
  const WonenCouponField({super.key, required this.audience, required this.normalPrice,
    required this.defaultPrice, required this.onChanged, this.plan,
    this.returning = false, this.request});
  @override
  State<WonenCouponField> createState() => _WonenCouponFieldState();
}

class _WonenCouponFieldState extends State<WonenCouponField> {
  final controller = TextEditingController();
  Timer? debounce;
  int revision = 0;
  String? total, error;
  bool checking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) check(); });
  }
  @override
  void didUpdateWidget(covariant WonenCouponField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan || oldWidget.normalPrice != widget.normalPrice ||
        oldWidget.defaultPrice != widget.defaultPrice) {
      revision++; debounce?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) check(); });
    }
  }
  @override
  void dispose() { revision++; debounce?.cancel(); controller.dispose(); super.dispose(); }
  void changed(String _) {
    debounce?.cancel(); revision++;
    setState(() { total = null; error = null; checking = true; });
    widget.onChanged(WonenCouponQuote(controller.text.trim().toUpperCase(), null, false));
    debounce = Timer(const Duration(milliseconds: 350), check);
  }
  Future<void> check() async {
    debounce?.cancel();
    final current = ++revision, code = controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() { total = null; error = null; checking = false; });
      widget.onChanged(const WonenCouponQuote('', null, true)); return;
    }
    setState(() { checking = true; error = null; total = null; });
    widget.onChanged(WonenCouponQuote(code, null, false));
    try {
      if (widget.returning && code == 'MAKELAAR') {
        throw StateError('MAKELAAR geldt alleen voor een nieuw makelaarskantoor.');
      }
      final quote = await (widget.request ?? wonenRequest)('/kortingscode/controleren', body: {
        'audience': widget.audience, 'code': code, if (widget.plan != null) 'plan': widget.plan,
      });
      final amount = quote is Map ? double.tryParse('${quote['total']}') : null;
      final normal = double.tryParse(widget.normalPrice);
      if (amount == null || !amount.isFinite || amount < 0 || normal == null || amount > normal) {
        throw StateError('De prijs kon niet worden gecontroleerd.');
      }
      if (!mounted || current != revision) return;
      final value = amount.toStringAsFixed(2);
      setState(() { total = value; checking = false; });
      widget.onChanged(WonenCouponQuote(code, value, true));
    } catch (exception) {
      if (!mounted || current != revision) return;
      setState(() { total = null; checking = false; error = '$exception'; });
      widget.onChanged(WonenCouponQuote(code, null, false));
    }
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: controller, textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: 'Kortingscode (optioneel)', errorText: error,
          border: const OutlineInputBorder(), suffixIcon: IconButton(
            tooltip: 'Kortingscode controleren', icon: const Icon(Icons.check_circle_outline),
            onPressed: checking ? null : check)), onChanged: changed, onSubmitted: (_) => check()),
      const SizedBox(height: 8),
      Text(checking ? 'Kortingscode controleren…' : error != null
        ? 'Verwijder of wijzig de code om verder te gaan.'
        : '${widget.audience == 'makelaar' ? 'Eerste maand' : 'Eén maand plaatsing'}: €${(total ?? widget.defaultPrice).replaceAll('.', ',')}',
        style: const TextStyle(fontWeight: FontWeight.bold)),
      if (widget.audience == 'makelaar') Text('Daarna €${widget.normalPrice.replaceAll('.', ',')} per maand. Korting wordt niet gestapeld.'),
    ]));
}

class WonenPrivateOrder extends StatefulWidget {
  final int id;
  final VoidCallback refresh;
  final WonenRequester? request;
  const WonenPrivateOrder({super.key, required this.id, required this.refresh, this.request});
  @override
  State<WonenPrivateOrder> createState() => _WonenPrivateOrderState();
}

class _WonenPrivateOrderState extends State<WonenPrivateOrder> {
  WonenCouponQuote quote = const WonenCouponQuote('', null, true);
  bool busy = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('€25 voor één woning, één kalendermaand vanaf publicatie. Geen automatische verlenging. RVAZ beoordeelt eerst de woning.'),
    WonenCouponField(audience: 'particulier', normalPrice: '25.00', defaultPrice: '25.00',
      request: widget.request, onChanged: (value) { if (mounted) setState(() => quote = value); }),
    FilledButton(onPressed: busy || !quote.ready ? null : () async {
      final code = quote.code;
      setState(() => busy = true);
      try {
        final request = widget.request ?? wonenRequest;
        String amount = '25.00';
        if (code.isNotEmpty) {
          final fresh = await request('/kortingscode/controleren', body: {'audience': 'particulier', 'code': code});
          amount = '${fresh['total']}';
        }
        if (!context.mounted || !await wonenConfirm(context, 'Plaatsing aanvragen',
          'Bevestig €${amount.replaceAll('.', ',')} voor één woning, één kalendermaand vanaf publicatie. Geen automatische verlenging.')) return;
        await request('/particulier/woningen/${widget.id}/bestellen', body: {
          'confirm': true, 'expected_price': '25.00', 'expected_period': '1_month', 'coupon_code': code,
        });
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aanvraag opgeslagen. Bekijk Mijn facturen voor de factuur en eventuele betaling.'))); widget.refresh(); }
      } catch (exception) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$exception')));
      } finally { if (mounted) setState(() => busy = false); }
    }, child: Text(busy ? 'Aanvragen…' : 'Plaatsing aanvragen')),
  ]);
}
