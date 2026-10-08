import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

const wonenApi = 'https://www.regiovoorneaanzee.nl/wp-json/rvaz-wonen/v1';

Future<Map<String, String>> wonenHeaders() async {
  final token = await const FlutterSecureStorage().read(key: 'rvaz_token');
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) ...{
      'Authorization': 'Bearer $token',
      'X-RVAZ-Token': token,
    },
  };
}

Future<dynamic> wonenRequest(String path, {Map<String, dynamic>? body}) async {
  final uri = Uri.parse('$wonenApi$path');
  final headers = await wonenHeaders();
  final response = await (body == null
      ? http.get(uri, headers: headers)
      : http.post(uri, headers: headers, body: jsonEncode(body)))
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    String message;
    if (response.statusCode == 401) {
      message = 'Log opnieuw in via Mijn RVAZ.';
    } else if (response.statusCode == 403) {
      message = 'Dit account heeft geen makelaarstoegang.';
    } else if (response.statusCode == 404) {
      message = 'Deze beheerfunctie is nog niet beschikbaar. Probeer later opnieuw.';
    } else {
      message = 'De woninggegevens konden niet worden geladen. Probeer opnieuw.';
    }
    try {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      if (error is Map && error['message'] is String &&
          response.statusCode != 404 && response.statusCode < 500) {
        message = html_parser.parseFragment(error['message'] as String).text ?? message;
      }
    } catch (_) {}
    throw WonenApiException(response.statusCode, message);
  }
  if (response.body.trim().isEmpty) return <String, dynamic>{};
  return jsonDecode(utf8.decode(response.bodyBytes));
}

class WonenApiException implements Exception {
  final int status;
  final String message;
  const WonenApiException(this.status, this.message);
  @override
  String toString() => message;
}

const wonenFieldLabels = <String, String>{
  'title': 'Titel', 'description': 'Omschrijving', 'adres': 'Adres',
  'postcode': 'Postcode', 'plaats': 'Plaats', 'prijs': 'Prijs in euro',
  'transactie': 'Koop of huur', 'woningtype': 'Soort woning',
  'kamers': 'Aantal kamers', 'slaapkamers': 'Slaapkamers',
  'woonoppervlak': 'Woonoppervlakte (m²)', 'energielabel': 'Energielabel',
  'status': 'Beschikbaar, verkocht of verhuurd', 'bouwjaar': 'Bouwjaar',
  'perceel': 'Perceeloppervlakte (m²)', 'badkamers': 'Badkamers',
  'tuin': 'Tuin (Ja/Nee)', 'balkon': 'Balkon (Ja/Nee)', 'garage': 'Garage (Ja/Nee)',
  'aanvaarding': 'Aanvaarding', 'borg': 'Borg', 'contractduur': 'Contractduur',
  'inkomenseisen': 'Inkomenseisen', 'prijstype': 'Prijstype (k.k./v.o.n.)',
  'makelaar_url': 'Website makelaar',
};

Future<bool> wonenConfirm(BuildContext context, String title, String text) async =>
  await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
    title: Text(title), content: Text(text), actions: [
      TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Annuleren')),
      FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Bevestigen')),
    ],
  )) == true;

Future<void> wonenAction(BuildContext context, String path,
    Map<String, dynamic> body, VoidCallback refresh) async {
  try {
    await wonenRequest(path, body: body);
    if (context.mounted) { refresh(); ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wijziging opgeslagen.'))); }
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
}

Future<Map<String, dynamic>> wonenUpload(String path) async {
  final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (photo == null) return {};
  final request = http.MultipartRequest('POST', Uri.parse('$wonenApi$path'));
  request.headers.addAll(await wonenHeaders()); request.headers.remove('Content-Type');
  request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
  final streamed = await request.send().timeout(const Duration(seconds: 60));
  final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 20));
  final data = jsonDecode(utf8.decode(response.bodyBytes));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw WonenApiException(response.statusCode,
      data is Map ? (data['message']?.toString() ?? 'Foto toevoegen is niet gelukt.') : 'Foto toevoegen is niet gelukt.');
  }
  return Map<String, dynamic>.from(data as Map);
}

List<Map<String, dynamic>> wonenItems(dynamic data) {
  final raw = data is List
      ? data
      : data is Map ? (data['items'] ?? data['data'] ?? data['results'] ?? []) : [];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String wonenText(Map<String, dynamic> item, String key) {
  var value = item[key];
  if (key == 'id' && value is Map) value = value['ID'] ?? value['id'];
  if (value == null || value is bool) return '';
  final text = value.toString().trim();
  return text.toLowerCase() == 'false' || text.toLowerCase() == 'null'
      ? ''
      : text;
}

String wonenArea(String value) => value.contains('m²') || value.isEmpty
    ? value : '$value m²';

// Gebruik de echte woningweergave van de website zolang de publieke API
// ingevulde woningvelden ten onrechte als false teruggeeft.
// De openbare Wonen-API mist soms gegevens die op de woningpagina wel staan.
// Lees die inhoud als DATA en toon hem uitsluitend in onze eigen Flutter-widgets.
const _websiteFacts = <String, String>{
  'Soort woning': 'woningtype',
  'Aanbod': 'transactie',
  'Status': 'status',
  'Bouwjaar': 'bouwjaar',
  'Woonoppervlakte': 'woonoppervlak',
  'Perceeloppervlakte': 'perceel',
  'Aantal kamers': 'kamers',
  'Slaapkamers': 'slaapkamers',
  'Badkamers': 'badkamers',
  'Energielabel': 'energielabel',
  'Tuin': 'tuin',
  'Balkon': 'balkon',
  'Garage': 'garage',
  'Aanvaarding': 'aanvaarding',
  'Borg': 'borg',
  'Contractduur': 'contractduur',
  'Inkomenseisen': 'inkomenseisen',
};

Map<String, dynamic> mergeWoningWebsiteData(
  Map<String, dynamic> original, String htmlSource,
) {
  final doc = html_parser.parse(htmlSource);
  final property = doc.querySelector('.rvw-property');
  final main = property ?? doc.querySelector('main article') ??
      doc.querySelector('article') ?? doc.querySelector('main');
  if (main == null) return Map<String, dynamic>.from(original);
  final item = Map<String, dynamic>.from(original);
  final heading = (main.querySelector('.rvw-property-top h1') ??
      main.querySelector('h1'))?.text.trim() ?? '';
  if (heading.isNotEmpty) item['adres'] = heading;
  // De HTML-parser plakt soms tekst van opeenvolgende tags aan elkaar.
  // Scheid de paragrafen zodat postcode en plaats betrouwbaar herkenbaar zijn.
  final headerText = main.querySelectorAll(
      property != null
          ? '.rvw-property-location, .rvw-property-price' : 'h1, p')
      .map((node) => node.text.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');
  final location = RegExp(
    r'\b([1-9][0-9]{3}\s?[A-Z]{2})\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ\- ]{1,35})',
  ).firstMatch(headerText);
  if (location != null) {
    item['postcode'] = location.group(1)!.trim();
    item['plaats'] = location.group(2)!.trim();
  }
  final price = RegExp(r'€\s*([0-9][0-9.,]*(?:\s*p/m)?)',
      caseSensitive: false).firstMatch(headerText);
  if (price != null) item['prijs'] = price.group(1)!.trim();

  final rows = main.querySelectorAll('.rvw-spec-row');
  if (rows.isNotEmpty) {
    for (final row in rows) {
      final label = row.querySelector('.rvw-spec-label')?.text.trim();
      final value = row.querySelector('.rvw-spec-value')?.text.trim() ?? '';
      final key = _websiteFacts[label];
      if (key != null && value.isNotEmpty) item[key] = value;
    }
  } else {
    final facts = main.querySelectorAll('section').where((node) =>
        node.querySelector('h2')?.text.trim().toLowerCase() == 'kenmerken');
    if (facts.isNotEmpty) {
      final factText = facts.first.text.replaceAll(RegExp(r'\s+'), ' ');
      final names = _websiteFacts.keys.toList();
      final matches = RegExp(names.map(RegExp.escape).join('|'),
          caseSensitive: false).allMatches(factText).toList();
      for (var i = 0; i < matches.length; i++) {
        final match = matches[i];
        final label = names.firstWhere((name) =>
            name.toLowerCase() == match.group(0)!.toLowerCase());
        final end = i + 1 < matches.length
            ? matches[i + 1].start : factText.length;
        final value = factText.substring(match.end, end).trim();
        if (value.isNotEmpty) item[_websiteFacts[label]!] = value;
      }
    }
  }
  final description = main.querySelector('.rvw-description');
  if (description != null) item['description'] = description.text.trim();
  final photos = main.querySelectorAll('.rvw-property-gallery img')
      .map((image) => image.attributes['src'] ?? '')
      .where((url) => Uri.tryParse(url)?.scheme == 'https').toSet().toList();
  if (photos.isNotEmpty) {
    item['image'] = photos.first;
    item['photos'] = photos;
  }
  final agent = main.querySelector('.rvw-agent-card');
  if (agent != null) {
    item['makelaar_naam'] = agent.querySelector('.rvw-agent-name')?.text.trim();
    item['makelaar_telefoon'] = agent.querySelector('.rvw-agent-meta')?.text.trim();
    item['makelaar_url'] = agent.querySelector('.rvw-agent-link')?.attributes['href'];
  }
  return item;
}

Future<List<Map<String, dynamic>>> getWonenListings() async {
  final all = wonenItems(await wonenRequest('/woningen'));
  final result = <Map<String, dynamic>>[];
  for (final item in all) {
    if (wonenText(item, 'adres').isNotEmpty && wonenText(item, 'woonoppervlak').isNotEmpty) {
      result.add(item); continue;
    }
    final urlText = wonenText(item, 'url');
    final url = Uri.tryParse(urlText);
    if (url == null || url.scheme != 'https' ||
        (url.host != 'regiovoorneaanzee.nl' &&
         url.host != 'www.regiovoorneaanzee.nl') ||
        !url.path.startsWith('/woning/')) {
      result.add(item);
      continue;
    }
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        result.add(mergeWoningWebsiteData(item, utf8.decode(response.bodyBytes)));
        continue;
      }
    } catch (_) {
      // Geen gefantaseerde data bij uitval; toon alleen echte API-velden.
    }
    result.add(item);
  }
  return result;
}

class WonenPage extends StatefulWidget {
  const WonenPage({super.key});
  @override
  State<WonenPage> createState() => _WonenPageState();
}

class _WonenPageState extends State<WonenPage> {
  late Future<dynamic> future;
  String filter = 'Alles';
  String type = 'Alle woningtypen';
  @override
  void initState() {
    super.initState();
    future = getWonenListings();
  }

  void reload() => setState(() => future = getWonenListings());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wonen op Voorne'), actions: [
      IconButton(tooltip: 'Vernieuwen', onPressed: reload,
        icon: const Icon(Icons.refresh)),
    ]),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Woningen ophalen is niet gelukt.'),
            TextButton(onPressed: reload, child: const Text('Opnieuw proberen')),
          ]));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = wonenItems(snapshot.data);
        final items = all.where((item) {
          final transaction = wonenText(item, 'transactie').toLowerCase();
          final kind = wonenText(item, 'woningtype').toLowerCase();
          return (filter == 'Alles' || transaction == filter.toLowerCase()) &&
              (type == 'Alle woningtypen' || kind == type.toLowerCase());
        }).toList();
        return Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Koop- en huurwoningen op Voorne aan Zee',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final choice in ['Alles', 'Koop', 'Huur'])
                    Padding(padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(choice),
                        selected: filter == choice,
                        onSelected: (_) => setState(() => filter = choice))),
                ])),
              DropdownButton<String>(value: type, isExpanded: true,
                items: ['Alle woningtypen', 'Woning', 'Appartement',
                  'Nieuwbouw', 'Bedrijfspand']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
                onChanged: (value) => setState(() =>
                  type = value ?? 'Alle woningtypen')),
              Text('${items.length} resultaten'),
            ])),
          Expanded(child: items.isEmpty
            ? const Center(child: Text('Geen woningen gevonden met deze filters.'))
            : ListView.builder(itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final image = wonenText(item, 'image');
                  final title = wonenText(item, 'adres').isNotEmpty
                    ? wonenText(item, 'adres') : wonenText(item, 'title');
                  final location = [
                    wonenText(item, 'postcode'), wonenText(item, 'plaats')
                  ].where((e) => e.isNotEmpty).join(' ');
                  final price = wonenText(item, 'prijs');
                  final details = [
                    if (wonenText(item, 'woonoppervlak').isNotEmpty)
                      '${wonenArea(wonenText(item, 'woonoppervlak'))} wonen',
                    if (wonenText(item, 'kamers').isNotEmpty)
                      '${wonenText(item, 'kamers')} kamers',
                    if (wonenText(item, 'energielabel').isNotEmpty)
                      'Label ${wonenText(item, 'energielabel')}',
                  ].join(' · ');
                  return Card(clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: InkWell(onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                        WoningDetailPage(item: item))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (image.isNotEmpty)
                            Image.network(image, width: double.infinity,
                              height: 190, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                const SizedBox(height: 90,
                                  child: Center(child: Icon(Icons.home_outlined)))),
                          Padding(padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment:
                              CrossAxisAlignment.start, children: [
                              Text(title, style: Theme.of(context).textTheme.titleLarge),
                              if (location.isNotEmpty) Text(location),
                              if (price.isNotEmpty)
                                Text('€ $price', style: Theme.of(context).textTheme.titleMedium),
                              if (details.isNotEmpty) Text(details),
                              const Align(alignment: Alignment.centerRight,
                                child: Icon(Icons.chevron_right)),
                            ])),
                        ])));
                })),
        ]);
      },
    ),
  );
}

class WoningDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;
  const WoningDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final image = wonenText(item, 'image');
    final gallery = item['gallery'] ?? item['photos'];
    final photos = gallery is List ? gallery.whereType<String>().toList() : <String>[];
    final address = wonenText(item, 'adres');
    final title = address.isNotEmpty ? address : wonenText(item, 'title');
    final location = [wonenText(item, 'postcode'),
      wonenText(item, 'plaats')].where((e) => e.isNotEmpty).join(' ');
    final price = wonenText(item, 'prijs');
    const labels = <String, String>{
      'woningtype': 'Soort woning', 'transactie': 'Aanbod',
      'status': 'Status', 'bouwjaar': 'Bouwjaar',
      'woonoppervlak': 'Woonoppervlakte', 'perceel': 'Perceeloppervlakte',
      'kamers': 'Aantal kamers', 'slaapkamers': 'Slaapkamers',
      'badkamers': 'Badkamers', 'energielabel': 'Energielabel',
      'tuin': 'Tuin', 'balkon': 'Balkon', 'garage': 'Garage',
      'aanvaarding': 'Aanvaarding', 'borg': 'Borg',
      'contractduur': 'Contractduur', 'inkomenseisen': 'Inkomenseisen',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Woning' : title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (image.isNotEmpty) ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(image, width: double.infinity,
            height: 240, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
              const SizedBox(height: 120,
                child: Center(child: Icon(Icons.home_outlined))))),
        if (photos.length > 1) SizedBox(height: 110, child: ListView(
          scrollDirection: Axis.horizontal,
          children: [for (final photo in photos) Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Image.network(photo, width: 150, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
          )],
        )),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (location.isNotEmpty) Text(location),
        if (price.isNotEmpty) Text('€ $price',
          style: Theme.of(context).textTheme.titleLarge),
        if (wonenText(item, 'description').isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Omschrijving', style: Theme.of(context).textTheme.titleLarge),
          Text(wonenText(item, 'description')
            .replaceAll(RegExp(r'<[^>]*>'), ' ').trim()),
        ],
        const SizedBox(height: 18),
        Text('Kenmerken', style: Theme.of(context).textTheme.titleLarge),
        for (final entry in labels.entries)
          if (wonenText(item, entry.key).isNotEmpty)
            ListTile(contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(wonenText(item, entry.key),
                  textAlign: TextAlign.end))),
        const SizedBox(height: 12),
        if (wonenText(item, 'makelaar_naam').isNotEmpty)
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.real_estate_agent_outlined),
            title: Text(wonenText(item, 'makelaar_naam')),
            subtitle: Text(wonenText(item, 'makelaar_telefoon'))),
        if (wonenText(item, 'makelaar_url').isNotEmpty)
          OutlinedButton.icon(icon: const Icon(Icons.open_in_new),
            label: const Text('Website makelaar'),
            onPressed: () async {
              final uri = Uri.tryParse(wonenText(item, 'makelaar_url'));
              if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
              final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('De makelaarswebsite kon niet worden geopend.')));
              }
            }),
      ]),
    );
  }
}

class MijnWonenPage extends StatefulWidget {
  const MijnWonenPage({super.key});
  @override
  State<MijnWonenPage> createState() => _MijnWonenPageState();
}

class _MijnWonenPageState extends State<MijnWonenPage> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); refresh(); }
  Future<Map<String, dynamic>> overview() async {
    final me = Map<String, dynamic>.from(await wonenRequest('/makelaar/me') as Map);
    if (me['makelaar'] != true) return {'me': me};
    final data = await Future.wait([wonenRequest('/makelaar/woningen'), wonenRequest('/makelaar/dashboard')]);
    return {'me': me, 'items': data[0], 'stats': data[1]};
  }
  void refresh() { future = overview(); }
  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(refresh);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mijn Wonen'), actions: [
      IconButton(tooltip: 'Vernieuwen', icon: const Icon(Icons.refresh), onPressed: () => setState(refresh)),
    ]),
    body: FutureBuilder<Map<String, dynamic>>(future: future, builder: (context, snapshot) {
      if (snapshot.hasError) return WonenErrorView(error: snapshot.error!, retry: () => setState(refresh));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!, me = Map<String, dynamic>.from(data['me'] as Map);
      if (me['blocked'] == true) return const Center(child: Text('Je makelaarstoegang is geblokkeerd. Neem contact op met RVAZ.'));
      if (me['makelaar'] != true) return WonenApplicationForm(me: me, refresh: () => setState(refresh));
      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('Welkom ${wonenText(me, 'name')}', style: Theme.of(context).textTheme.titleLarge),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in {'published':'Actief', 'draft':'Concept', 'sold':'Verkocht/verhuurd',
            'views':'Weergaven', 'contact_clicks':'Contactklikken', 'agent_clicks':'Makelaar-klikken'}.entries)
            Chip(label: Text('${entry.value}: ${stats[entry.key] ?? 0}')),
        ]),
        ListTile(leading: const Icon(Icons.business_outlined), title: const Text('Mijn kantoor'), onTap: () => open(const WonenProfilePage())),
        ListTile(leading: const Icon(Icons.mail_outline), title: const Text('Berichten en aanvragen'), onTap: () => open(const WonenAanvragenPage())),
        ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('Abonnement en facturen'), onTap: () => open(const WonenSubscriptionPage())),
        ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Instellingen'), onTap: () => open(const WonenProfilePage(settings: true))),
        FilledButton.icon(onPressed: () => open(const WoningEditorPage()), icon: const Icon(Icons.add), label: const Text('Woning toevoegen')),
        const SizedBox(height: 16),
        Text('Mijn woningen', style: Theme.of(context).textTheme.titleLarge),
        if (wonenItems(data['items']).isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Je hebt nog geen woningen toegevoegd.')),
        for (final item in wonenItems(data['items'])) Card(child: ListTile(
          title: Text(wonenText(item, 'title')),
          subtitle: Text(wonenText(item, 'publication_status') == 'publish' ? 'Gepubliceerd' : 'Concept'),
          trailing: const Icon(Icons.edit_outlined), onTap: () => open(WoningEditorPage(item: item)),
        )),
      ]);
    }),
  );
}

class WonenErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const WonenErrorView({super.key, required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.info_outline, size: 40), const SizedBox(height: 12),
      Text(error.toString(), textAlign: TextAlign.center), const SizedBox(height: 12),
      TextButton(onPressed: retry, child: const Text('Opnieuw proberen')),
    ],
  )));
}

class WoningEditorPage extends StatefulWidget {
  final Map<String, dynamic>? item;
  const WoningEditorPage({super.key, this.item});
  @override
  State<WoningEditorPage> createState() => _WoningEditorPageState();
}

class _WoningEditorPageState extends State<WoningEditorPage> {
  late final Map<String, TextEditingController> fields;
  int? id;
  bool busy = false;
  String publicationStatus = 'draft';
  List<Map<String, dynamic>> photos = [];
  String newsPromo = '';

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? <String, dynamic>{};
    id = int.tryParse(wonenText(item, 'id'));
    photos = wonenItems(item['photos']);
    newsPromo = wonenText(item, 'news_promo');
    publicationStatus = wonenText(item, 'publication_status') == 'publish'
        ? 'publish' : 'draft';
    fields = {
      for (final key in [
        'title', 'description', 'adres', 'postcode', 'plaats', 'prijs',
        'transactie', 'woningtype', 'kamers', 'slaapkamers',
        'woonoppervlak', 'energielabel', 'status', 'bouwjaar', 'perceel',
        'badkamers', 'tuin', 'balkon', 'garage', 'aanvaarding', 'borg',
        'contractduur', 'inkomenseisen', 'prijstype', 'makelaar_url'
      ])
        key: TextEditingController(text: wonenText(item, key)),
    };
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        for (final entry in fields.entries) entry.key: entry.value.text,
        'publication_status': publicationStatus,
      };
      final response = await wonenRequest(
        id == null ? '/makelaar/woningen' : '/makelaar/woningen/$id',
        body: body,
      );
      final savedId = response is Map ? int.tryParse('${response['id']}') : null;
      if (id == null && savedId == null) {
        throw StateError('API gaf geen woningnummer terug; foto-upload is nog niet beschikbaar.');
      }
      if (mounted) {
        setState(() { id = savedId ?? id; photos = wonenItems(response['photos']); });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Woning opgeslagen. Je kunt nu foto’s toevoegen.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addPhoto() async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sla de woning eerst op.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final data = await wonenUpload('/makelaar/woningen/$id/fotos');
      if (data.isEmpty) return;
      if (mounted) {
        setState(() => photos = wonenItems(data['photos']));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto toegevoegd.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto upload mislukt: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updatePhotos(List<Map<String, dynamic>> next) async {
    setState(() => busy = true);
    try {
      final data = await wonenRequest('/makelaar/woningen/$id/galerij', body: {
        'photo_ids': next.map((photo) => int.parse(wonenText(photo, 'id'))).toList(),
      });
      if (mounted) setState(() => photos = wonenItems(data['photos']));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> deleteProperty() async {
    if (!await wonenConfirm(context, 'Woning verwijderen', 'Deze woning wordt naar de prullenbak verplaatst en verdwijnt uit het aanbod.')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await wonenRequest('/makelaar/woningen/$id/verwijderen', body: {'confirm': true});
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'Nieuwe woning' : 'Woning bewerken')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: entry.value,
                maxLines: entry.key == 'description' ? 4 : 1,
                decoration: InputDecoration(
                  labelText: wonenFieldLabels[entry.key] ?? entry.key,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: publicationStatus,
            items: const [
              DropdownMenuItem(value: 'draft', child: Text('Concept')),
              DropdownMenuItem(value: 'publish', child: Text('Publiceren')),
            ],
            onChanged: (value) =>
                setState(() => publicationStatus = value ?? 'draft'),
          ),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('Woning opslaan'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : addPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Foto toevoegen'),
          ),
          for (var i = 0; i < photos.length; i++) Card(child: ListTile(
            leading: Image.network(wonenText(photos[i], 'url'), width: 60, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
            title: Text(i == 0 ? 'Hoofdfoto' : 'Foto ${i + 1}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (i > 0) IconButton(tooltip: 'Als hoofdfoto', icon: const Icon(Icons.star_outline), onPressed: busy ? null : () {
                final next = [...photos], photo = next.removeAt(i); next.insert(0, photo); updatePhotos(next);
              }),
              IconButton(tooltip: 'Foto uit woning verwijderen', icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () async {
                if (!await wonenConfirm(context, 'Foto verwijderen', 'Deze foto wordt uit de woning verwijderd.')) return;
                if (!mounted) return;
                final next = [...photos]..removeAt(i); await updatePhotos(next);
              }),
            ]),
          )),
          if (id != null) OutlinedButton.icon(icon: const Icon(Icons.campaign_outlined),
            label: Text(newsPromo == 'requested' ? 'Nieuwsbericht aangevraagd' : 'Promoot als nieuws (€29)'),
            onPressed: busy || newsPromo == 'requested' ? null : () async {
              if (!await wonenConfirm(context, 'Nieuwsbericht aanvragen', 'Vraag promotie van deze woning als nieuwsbericht aan voor €29. RVAZ verwerkt je aanvraag.')) return;
              if (!mounted) return;
              await wonenAction(context, '/makelaar/woningen/$id/promotie', {'confirm': true, 'expected_price': '29.00'}, () => setState(() => newsPromo = 'requested'));
            }),
          if (id != null) TextButton.icon(onPressed: busy ? null : deleteProperty,
            icon: const Icon(Icons.delete_outline), label: const Text('Woning verwijderen')),

        ],
      ),
    );
  }
}


class WonenDataPage extends StatefulWidget {
  final String title, path;
  final Widget Function(BuildContext, dynamic, VoidCallback) content;
  const WonenDataPage({super.key, required this.title, required this.path, required this.content});
  @override
  State<WonenDataPage> createState() => _WonenDataPageState();
}
class _WonenDataPageState extends State<WonenDataPage> {
  late Future<dynamic> future;
  @override
  void initState() { super.initState(); future = wonenRequest(widget.path); }
  void refresh() => setState(() => future = wonenRequest(widget.path));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [IconButton(tooltip: 'Vernieuwen', onPressed: refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<dynamic>(future: future, builder: (context, snapshot) {
      if (snapshot.hasError) return WonenErrorView(error: snapshot.error!, retry: refresh);
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return widget.content(context, snapshot.data, refresh);
    }),
  );
}

Future<void> wonenOpenLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null || !['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) return;
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('De link kon niet worden geopend.')));
  }
}

class WonenAanvragenPage extends StatelessWidget {
  const WonenAanvragenPage({super.key});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Berichten en aanvragen', path: '/makelaar/aanvragen', content: (context, data, refresh) {
    final items = wonenItems(data);
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (items.isEmpty) const Text('Nog geen woningaanvragen.'),
      for (final item in items) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(wonenText(item, 'name'), style: Theme.of(context).textTheme.titleMedium),
        Text('${wonenText(item, 'created')} · ${wonenText(item, 'status') == 'new' ? 'Nieuw' : 'Gelezen'}'),
        const SizedBox(height: 12), Text(wonenText(item, 'message')),
        TextButton(onPressed: () => wonenOpenLink(context, 'mailto:${wonenText(item, 'email')}'), child: Text(wonenText(item, 'email'))),
        if (wonenText(item, 'phone').isNotEmpty) TextButton(onPressed: () => wonenOpenLink(context, 'tel:${wonenText(item, 'phone')}'), child: Text(wonenText(item, 'phone'))),
        Wrap(spacing: 8, children: [
          if (wonenText(item, 'status') == 'new') OutlinedButton(onPressed: () => wonenAction(context,
            '/makelaar/aanvragen/${wonenText(item, 'id')}', {'action': 'read'}, refresh), child: const Text('Markeer gelezen')),
          TextButton(onPressed: () async {
            if (!await wonenConfirm(context, 'Bericht verwijderen', 'Dit bericht wordt definitief verwijderd.')) return;
            if (context.mounted) await wonenAction(context, '/makelaar/aanvragen/${wonenText(item, 'id')}', {'action': 'delete', 'confirm': true}, refresh);
          }, child: const Text('Verwijderen')),
        ]),
      ]))),
    ]);
  });
}

class WonenProfilePage extends StatelessWidget {
  final bool settings;
  const WonenProfilePage({super.key, this.settings = false});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: settings ? 'Instellingen' : 'Mijn kantoor',
    path: settings ? '/makelaar/instellingen' : '/makelaar/kantoor', content: (context, data, refresh) =>
      WonenProfileForm(key: ValueKey(data.toString()), data: Map<String, dynamic>.from(data as Map), settings: settings));
}
class WonenProfileForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool settings;
  const WonenProfileForm({super.key, required this.data, this.settings = false});
  @override
  State<WonenProfileForm> createState() => _WonenProfileFormState();
}
class _WonenProfileFormState extends State<WonenProfileForm> {
  late Map<String, TextEditingController> fields;
  bool notify = false, busy = false;
  String logo = '';
  Map<String, String> get labels => widget.settings ? {'contact_email': 'Contact e-mailadres'} : {
    'office_name': 'Kantoornaam', 'kvk': 'KvK-nummer', 'address': 'Adres',
    'postcode': 'Postcode', 'place': 'Plaats', 'phone': 'Telefoon', 'website': 'Website',
  };
  @override
  void initState() {
    super.initState(); fields = {for (final key in labels.keys) key: TextEditingController(text: wonenText(widget.data, key))};
    notify = widget.data['email_notifications'] == true; logo = wonenText(widget.data, 'logo');
  }
  @override
  void dispose() { for (final field in fields.values) { field.dispose(); } super.dispose(); }
  Future<void> save() async {
    setState(() => busy = true);
    try {
      await wonenRequest(widget.settings ? '/makelaar/instellingen' : '/makelaar/kantoor', body: {
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
        if (widget.settings) 'email_notifications': notify,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gegevens opgeslagen.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> addLogo() async {
    setState(() => busy = true);
    try {
      final data = await wonenUpload('/makelaar/kantoor/logo');
      if (mounted && data.isNotEmpty) setState(() => logo = wonenText(data, 'logo'));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    for (final entry in fields.entries) Padding(padding: const EdgeInsets.only(bottom: 14), child: TextField(
      controller: entry.value, enabled: !busy,
      keyboardType: entry.key == 'contact_email' ? TextInputType.emailAddress : entry.key == 'phone' ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: labels[entry.key], border: const OutlineInputBorder()),
    )),
    if (widget.settings) SwitchListTile(title: const Text('E-mailmeldingen ontvangen'), value: notify,
      onChanged: busy ? null : (value) => setState(() => notify = value)),
    if (!widget.settings) ...[
      if (logo.isNotEmpty) Image.network(logo, height: 100, errorBuilder: (_, __, ___) => const Icon(Icons.business_outlined)),
      OutlinedButton.icon(onPressed: busy ? null : addLogo, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Kantoorlogo toevoegen')),
    ],
    FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Opslaan…' : 'Opslaan')),
  ]);
}

class WonenSubscriptionPage extends StatelessWidget {
  const WonenSubscriptionPage({super.key});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Abonnement', path: '/makelaar/abonnement', content: (context, data, refresh) {
    final map = Map<String, dynamic>.from(data as Map);
    final sub = map['subscription'] is Map ? Map<String, dynamic>.from(map['subscription'] as Map) : <String, dynamic>{};
    final plans = Map<String, dynamic>.from(map['plans'] as Map);
    final active = sub['status'] == 'active';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(sub.isEmpty ? 'Geen abonnement.' : 'Huidig pakket: ${wonenText(sub, 'plan')} · ${wonenText(sub, 'status')}', style: Theme.of(context).textTheme.titleLarge),
      if (wonenText(sub, 'start_date').isNotEmpty) Text('${wonenText(sub, 'start_date')} t/m ${wonenText(sub, 'end_date')}'),
      if (wonenText(sub, 'next_invoice_date').isNotEmpty) Text('Volgende factuur: ${wonenText(sub, 'next_invoice_date')}'),
      const SizedBox(height: 16),
      for (final key in ['basis', 'plus', 'pro']) if (plans[key] is Map) Builder(builder: (context) {
        final plan = Map<String, dynamic>.from(plans[key] as Map);
        if (wonenText(plan, 'enabled') != '1') return const SizedBox.shrink();
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(wonenText(plan, 'name'), style: Theme.of(context).textTheme.titleLarge),
          Text('€${wonenText(plan, 'price')} per maand'), Text(wonenText(plan, 'features')),
          if (active) OutlinedButton(onPressed: sub['plan'] == key ? null : () async {
            if (!await wonenConfirm(context, 'Pakket wijzigen', 'Kies ${wonenText(plan, 'name')} voor €${wonenText(plan, 'price')} per maand. Hiervoor wordt volgens de website een nieuwe factuur aangemaakt.')) return;
            if (context.mounted) await wonenAction(context, '/makelaar/abonnement', {'plan': key, 'expected_price': wonenText(plan, 'price'), 'confirm': true}, refresh);
          }, child: Text(sub['plan'] == key ? 'Huidig pakket' : 'Wijzig pakket')),
        ])));
      }),
      ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('Mijn facturen'), trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenInvoicesPage()))),
      if (active) TextButton(onPressed: () async {
        if (!await wonenConfirm(context, 'Abonnement opzeggen', 'Er worden geen nieuwe facturen gemaakt. Je actieve woningen worden concept en verdwijnen uit het aanbod. Je RVAZ-account blijft bestaan.')) return;
        if (context.mounted) await wonenAction(context, '/makelaar/abonnement/opzeggen', {'confirm': true}, refresh);
      }, child: const Text('Abonnement opzeggen')),
    ]);
  });
}

class WonenInvoicesPage extends StatelessWidget {
  const WonenInvoicesPage({super.key});
  @override
  Widget build(BuildContext context) => WonenDataPage(title: 'Mijn facturen', path: '/makelaar/facturen', content: (context, data, refresh) {
    final map = Map<String, dynamic>.from(data as Map), items = wonenItems(data);
    final billing = Map<String, dynamic>.from(map['billing'] as Map);
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (items.isEmpty) const Text('Nog geen facturen.'),
      for (final item in items) Card(child: ExpansionTile(title: Text(wonenText(item, 'invoice_no')),
        subtitle: Text('€ ${wonenText(item, 'total')} · ${wonenText(item, 'status')}'), childrenPadding: const EdgeInsets.all(16), children: [
          Text('Periode: ${wonenText(item, 'period')}'), Text('Factuurdatum: ${wonenText(item, 'invoice_date')}'),
          Text('Vervaldatum: ${wonenText(item, 'due_date')}'), Text('BTW: € ${wonenText(item, 'vat')}'),
          if (wonenText(item, 'paid_date').isNotEmpty) Text('Betaald: ${wonenText(item, 'paid_date')}'),
          if (wonenText(billing, 'iban').isNotEmpty) SelectableText('IBAN: ${wonenText(billing, 'iban')}'),
          Text(wonenText(billing, 'account_name')), Text(wonenText(billing, 'note')),
          OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Factuur als PDF delen'), onPressed: () async {
            try {
              final pdf = await wonenRequest('/makelaar/facturen/${wonenText(item, 'id')}/pdf');
              await SharePlus.instance.share(ShareParams(files: [XFile.fromData(base64Decode(pdf['pdf_base64'] as String),
                mimeType: 'application/pdf', name: '${wonenText(item, 'invoice_no')}.pdf')],
                fileNameOverrides: ['${wonenText(item, 'invoice_no')}.pdf'],
                sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1)));
            } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
          }),
          if (wonenText(item, 'tikkie_url').isNotEmpty && wonenText(item, 'status') == 'open')
            FilledButton(onPressed: () => wonenOpenLink(context, wonenText(item, 'tikkie_url')), child: const Text('Betalen')),
        ],
      )),
    ]);
  });
}

class WonenApplicationForm extends StatefulWidget {
  final Map<String, dynamic> me;
  final VoidCallback refresh;
  const WonenApplicationForm({super.key, required this.me, required this.refresh});
  @override
  State<WonenApplicationForm> createState() => _WonenApplicationFormState();
}
class _WonenApplicationFormState extends State<WonenApplicationForm> {
  final office = TextEditingController(), name = TextEditingController(), phone = TextEditingController();
  String? plan;
  bool busy = false;
  @override
  void dispose() { office.dispose(); name.dispose(); phone.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final application = widget.me['application'];
    if (application is Map && ['pending', 'email_pending'].contains(application['status'])) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(application['status'] == 'email_pending'
        ? 'Bevestig je e-mailadres via de ontvangen e-mail. Daarna beoordeelt RVAZ je aanvraag.' : 'Je makelaarsaanvraag is in behandeling bij RVAZ.')));
    }
    final plans = widget.me['plans'] is Map ? Map<String, dynamic>.from(widget.me['plans'] as Map) : <String, dynamic>{};
    final keys = ['basis', 'plus', 'pro'].where((key) => plans[key] is Map && wonenText(Map<String, dynamic>.from(plans[key]), 'enabled') == '1').toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Makelaarsabonnement aanvragen', style: Theme.of(context).textTheme.titleLarge),
      const Text('Je aanvraag wordt eerst door RVAZ beoordeeld. Er wordt niet automatisch afgeschreven.'),
      for (final entry in {office:'Kantoornaam', name:'Contactpersoon', phone:'Telefoon'}.entries) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8), child: TextField(controller: entry.key, decoration: InputDecoration(labelText: entry.value))),
      DropdownButtonFormField<String>(initialValue: plan, decoration: const InputDecoration(labelText: 'Abonnement'), items: [
        for (final key in keys) DropdownMenuItem(value: key, child: Text('${plans[key]['name']} · €${plans[key]['price']}/maand')),
      ], onChanged: busy ? null : (value) => setState(() => plan = value)),
      FilledButton(onPressed: busy || plan == null ? null : () async {
        if ([office, name, phone].any((field) => field.text.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vul alle verplichte velden in.'))); return;
        }
        final selected = plan!, price = plans[selected]['price'].toString();
        if (!await wonenConfirm(context, 'Abonnement aanvragen', 'Vraag ${plans[selected]['name']} aan voor €$price per maand, na beoordeling door RVAZ.')) return;
        if (!context.mounted) return;
        setState(() => busy = true);
        try {
          await wonenRequest('/makelaar/aanmelden', body: {'office': office.text.trim(), 'contact_name': name.text.trim(),
            'phone': phone.text.trim(), 'plan': selected, 'expected_price': price, 'confirm': true});
          if (mounted) widget.refresh();
        } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
        finally { if (mounted) setState(() => busy = false); }
      }, child: Text(busy ? 'Aanvragen…' : 'Abonnement aanvragen')),
    ]);
  }
}
