part of 'wonen.dart';

class WonenPrivatePage extends StatefulWidget {
  const WonenPrivatePage({super.key});
  @override
  State<WonenPrivatePage> createState() => _WonenPrivatePageState();
}
class _WonenPrivatePageState extends State<WonenPrivatePage> {
  bool authority = false, photos = false, busy = false;
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Mijn particuliere woning', path: '/particulier/woningen', content: (context, data, refresh) {
    final rows = wonenItems(data);
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Zelf je woning verkopen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const Text('Je kunt één woning tegelijk aanbieden. RVAZ beoordeelt je woning voordat deze verschijnt. Aanpassingen aan een gepubliceerde advertentie worden opnieuw beoordeeld.'),
      if (rows.isEmpty) FilledButton.icon(icon: const Icon(Icons.add_home_outlined), label: const Text('Woning toevoegen'), onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const WoningEditorPage(privateOffer: true))); refresh();
      }),
      for (final row in rows) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(wonenText(row, 'title'), style: Theme.of(context).textTheme.titleLarge),
        Text('Status: ${wonenText(row, 'publication_status') == 'publish' ? 'Gepubliceerd' : wonenText(row, 'publication_status') == 'pending' ? 'In beoordeling' : 'Concept'}'),
        Text('Betaling: ${wonenText(row, 'payment_status') == 'paid' ? 'Bevestigd' : 'Nog niet bevestigd'}'),
        if ((int.tryParse('${row['placement_expires']}') ?? 0) > 0) Text('Einddatum: ${DateTime.fromMillisecondsSinceEpoch(int.parse('${row['placement_expires']}') * 1000).toLocal().toString().substring(0, 16)}'),
        if (wonenText(row, 'review_reason').isNotEmpty) Text('Beoordeling: ${wonenText(row, 'review_reason')}'),
        OutlinedButton.icon(icon: const Icon(Icons.edit_outlined), label: const Text('Woning en foto’s bewerken'), onPressed: busy ? null : () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => WoningEditorPage(item: row, privateOffer: true))); refresh();
        }),
        CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Ik ben bevoegd deze woning aan te bieden.'), value: authority, onChanged: busy ? null : (v) => setState(() => authority = v ?? false)),
        CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Ik mag deze foto’s gebruiken.'), value: photos, onChanged: busy ? null : (v) => setState(() => photos = v ?? false)),
        FilledButton(onPressed: busy || !authority || !photos ? null : () async {
          setState(() => busy = true);
          try { await wonenRequest('/particulier/woningen/${row['id']}/indienen', body: {'authority_confirmed': authority, 'photos_confirmed': photos}); refresh(); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
          finally { if (mounted) setState(() => busy = false); }
        }, child: const Text('Indienen voor beoordeling')),
      ]))),
      ListTile(leading: const Icon(Icons.mail_outline), title: const Text('Reacties op mijn woning'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenAanvragenPage(privateOffer: true)))),
    ]);
  });
}

class WonenContactPage extends StatefulWidget {
  final int id;
  const WonenContactPage({super.key, required this.id});
  @override
  State<WonenContactPage> createState() => _WonenContactPageState();
}
class _WonenContactPageState extends State<WonenContactPage> {
  final name = TextEditingController(), email = TextEditingController(), phone = TextEditingController(), message = TextEditingController();
  bool busy = false;
  @override
  void dispose() { name.dispose(); email.dispose(); phone.dispose(); message.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reactie op woning')), body: ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Je reactie gaat naar de aanbieder van deze woning. Je contactgegevens worden meegestuurd, zodat die kan reageren.'),
    for (final e in {name:'Naam', email:'E-mail', phone:'Telefoon (optioneel)', message:'Bericht'}.entries) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: e.key, maxLines: e.key == message ? 5 : 1, keyboardType: e.key == email ? TextInputType.emailAddress : e.key == phone ? TextInputType.phone : TextInputType.text, decoration: InputDecoration(labelText: e.value))),
    FilledButton(onPressed: busy ? null : () async {
      if (name.text.trim().isEmpty || email.text.trim().isEmpty || message.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vul naam, e-mail en bericht in.'))); return; }
      setState(() => busy = true);
      try { await wonenRequest('/woningen/${widget.id}/contact', body: {'name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(), 'message': message.text.trim()}); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Je reactie is opgeslagen voor de aanbieder.'))); Navigator.pop(context); } }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
      finally { if (mounted) setState(() => busy = false); }
    }, child: Text(busy ? 'Versturen…' : 'Reactie sturen')),
  ]));
}
