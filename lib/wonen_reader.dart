part of 'wonen.dart';

class WonenFavoriteButton extends StatefulWidget {
  final int id;
  const WonenFavoriteButton({super.key, required this.id});
  @override
  State<WonenFavoriteButton> createState() => _WonenFavoriteButtonState();
}
class _WonenFavoriteButtonState extends State<WonenFavoriteButton> {
  bool saved = false, busy = false;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final d = await wonenRequest('/favorieten') as Map;
      if (mounted) setState(() => saved = (d['ids'] as List).contains(widget.id));
    } catch (_) { /* Guests can read listings; saving requires an account. */ }
  }
  Future<void> toggle() async {
    setState(() => busy = true);
    try {
      final d = await wonenRequest('/favorieten', body: {'woning_id': widget.id, 'saved': !saved}) as Map;
      if (mounted) setState(() => saved = (d['ids'] as List).contains(widget.id));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => IconButton(tooltip: saved ? 'Favoriet verwijderen' : 'Woning bewaren', onPressed: busy ? null : toggle, icon: Icon(saved ? Icons.favorite : Icons.favorite_border));
}

class WonenReaderPage extends StatelessWidget {
  const WonenReaderPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Mijn favoriete woningen')), body: ListView(children: [
    ListTile(leading: const Icon(Icons.favorite_border), title: const Text('Favorieten'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenFavoritesPage()))),
    ListTile(leading: const Icon(Icons.search), title: const Text('Opgeslagen zoekopdrachten'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenSearchesPage()))),
    ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Zoekmeldingen'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenNoticesPage()))),
    const Padding(padding: EdgeInsets.all(16), child: Text('Log in via Mijn RVAZ. Je favorieten en zoekopdrachten zijn dan ook beschikbaar op de website.')),
  ]));
}

class WonenFavoritesPage extends StatelessWidget {
  const WonenFavoritesPage({super.key});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Favoriete woningen', path: '/favorieten', content: (context, data, refresh) {
    final rows = wonenItems(data);
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (rows.isEmpty) const Text('Je hebt nog geen favoriete woningen. Bewaar een woning met het hartje op de detailpagina.'),
      for (final row in rows) Card(child: ListTile(title: Text(wonenText(row, 'title')), subtitle: Text('${wonenText(row, 'plaats')} · € ${wonenText(row, 'prijs')}'), onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => WoningDetailPage(item: row))); refresh();
      }, trailing: IconButton(tooltip: 'Favoriet verwijderen', icon: const Icon(Icons.favorite), onPressed: () async {
        try { await wonenRequest('/favorieten', body: {'woning_id': row['id'], 'saved': false}); refresh(); }
        catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
      }))),
    ]);
  });
}

String wonenSearchSummary(Map<String, dynamic> s) => [
  if ((s['plaats'] ?? '').toString().isNotEmpty) s['plaats'].toString(),
  (s['transactie'] ?? '').toString().isEmpty ? 'Koop en huur' : s['transactie'].toString(),
  if ((s['woningtype'] ?? '').toString().isNotEmpty) s['woningtype'].toString(),
  if (s['min_prijs'] != null) 'Vanaf € ${s['min_prijs']}',
  if (s['max_prijs'] != null) 'Tot € ${s['max_prijs']}',
].join(' · ');

class WonenSearchesPage extends StatelessWidget {
  const WonenSearchesPage({super.key});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Zoekopdrachten', path: '/zoekopdrachten', content: (context, data, refresh) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Bewaar maximaal 10 zoekopdrachten. Meldingen verschijnen in de app en op de website voor nieuw passend aanbod.'),
    FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Nieuwe zoekopdracht'), onPressed: () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenSearchEditor())); refresh();
    }),
    for (final s in wonenItems(data)) Card(child: Column(children: [
      ListTile(title: Text(wonenSearchSummary(s)), subtitle: Text(s['enabled'] == true ? 'Zoekmeldingen aan' : 'Zoekmeldingen uit'), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => WonenSearchEditor(search: s))); refresh(); }),
      TextButton.icon(icon: const Icon(Icons.delete_outline), label: const Text('Verwijderen'), onPressed: () async {
        final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Zoekopdracht verwijderen?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verwijderen'))]));
        if (yes != true) return;
        try { await wonenRequest('/zoekopdrachten/${s['id']}/verwijderen', body: {}); refresh(); }
        catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
      }),
    ])),
  ]));
}

class WonenSearchEditor extends StatefulWidget {
  final Map<String, dynamic>? search;
  const WonenSearchEditor({super.key, this.search});
  @override
  State<WonenSearchEditor> createState() => _WonenSearchEditorState();
}
class _WonenSearchEditorState extends State<WonenSearchEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController place, min, max;
  late String transaction, kind;
  late bool enabled;
  bool busy = false;
  @override
  void initState() { super.initState(); final s = widget.search ?? {};
    place = TextEditingController(text: s['plaats']?.toString() ?? ''); min = TextEditingController(text: s['min_prijs']?.toString() ?? ''); max = TextEditingController(text: s['max_prijs']?.toString() ?? ''); transaction = s['transactie']?.toString() ?? ''; kind = s['woningtype']?.toString() ?? ''; enabled = s['enabled'] != false;
  }
  @override
  void dispose() { place.dispose(); min.dispose(); max.dispose(); super.dispose(); }
  String? priceError(String? value) { if (value == null || value.isEmpty) return null; final n = double.tryParse(value.replaceAll(',', '.')); return n == null || !n.isFinite || n < 0 ? 'Vul een geldige prijs in zonder duizendtallen.' : null; }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await wonenRequest('/zoekopdrachten', body: {if (widget.search != null) 'id': widget.search!['id'], 'plaats': place.text.trim(), 'transactie': transaction, 'woningtype': kind, 'min_prijs': min.text.replaceAll(',', '.'), 'max_prijs': max.text.replaceAll(',', '.'), 'enabled': enabled});
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Zoekopdracht bewaren')), body: Form(key: form, child: ListView(padding: const EdgeInsets.all(16), children: [
    TextFormField(controller: place, decoration: const InputDecoration(labelText: 'Plaats (exacte plaatsnaam)')),
    DropdownButtonFormField<String>(initialValue: transaction, decoration: const InputDecoration(labelText: 'Koop / huur'), items: ['', 'Koop', 'Huur'].map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'Koop en huur' : v))).toList(), onChanged: busy ? null : (v) => setState(() => transaction = v ?? '')),
    DropdownButtonFormField<String>(initialValue: kind, decoration: const InputDecoration(labelText: 'Woningtype'), items: ['', 'Woning', 'Appartement', 'Nieuwbouw', 'Bedrijfspand'].map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'Alle woningtypen' : v))).toList(), onChanged: busy ? null : (v) => setState(() => kind = v ?? '')),
    TextFormField(controller: min, decoration: const InputDecoration(labelText: 'Minimumprijs'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: priceError),
    TextFormField(controller: max, decoration: const InputDecoration(labelText: 'Maximumprijs'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: priceError),
    SwitchListTile(title: const Text('Zoekmeldingen ontvangen'), subtitle: const Text('In de app en op de website'), value: enabled, onChanged: busy ? null : (v) => setState(() => enabled = v)),
    FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Opslaan…' : 'Zoekopdracht opslaan')),
  ])));
}

class WonenNoticesPage extends StatelessWidget {
  const WonenNoticesPage({super.key});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Zoekmeldingen', path: '/zoekmeldingen', content: (context, data, refresh) => ListView(padding: const EdgeInsets.all(16), children: [
    if (wonenItems(data).isEmpty) const Text('Nog geen nieuw passend aanbod. Bewaar eerst een zoekopdracht.'),
    for (final n in wonenItems(data)) ListTile(leading: Icon(n['read'] == true ? Icons.home_outlined : Icons.mark_email_unread_outlined), title: Text(wonenText(n, 'title')), subtitle: Text(wonenText(n, 'created')), onTap: () async {
      try { final all = wonenItems(await getWonenListings()); final matching = all.where((d) => d['id'].toString() == n['woning_id'].toString()); if (!context.mounted) return; if (matching.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deze woning is niet meer beschikbaar.'))); return; } await Navigator.push(context, MaterialPageRoute(builder: (_) => WoningDetailPage(item: matching.first))); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    }),
    if (wonenItems(data).any((n) => n['read'] != true)) TextButton(onPressed: () async { try { await wonenRequest('/zoekmeldingen', body: {'confirm': true}); refresh(); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }, child: const Text('Alles als gelezen markeren')),
  ]));
}

class WonenDashboardSummary extends StatelessWidget {
  final Map<String, dynamic> stats;
  const WonenDashboardSummary({super.key, required this.stats});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Makelaarsdashboard', style: Theme.of(context).textTheme.titleLarge),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final e in {'published':'Gepubliceerd','draft':'Concept / beoordeling','sold':'Verkocht / verhuurd','unread_messages':'Nieuwe aanvragen','views':'Weergaven'}.entries) Chip(label: Text('${e.value}: ${stats[e.key] ?? 0}'))]),
    Text('Abonnement: ${stats['plan_name'] ?? 'Bekijk je abonnement'}'),
    if (stats.containsKey('remaining')) Text('Publicatieruimte: ${stats['remaining'] == null ? 'Onbeperkt' : '${stats['remaining']} woningen'}'),
    if (stats['subscription_active'] == false) const Text('Activeer een abonnement om woningen te publiceren.'),
    for (final a in wonenItems(stats['attention'])) Text('${a['title']}: ${(a['missing'] as List).join(', ')}'),
  ])));
}
