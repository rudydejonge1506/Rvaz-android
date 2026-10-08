import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const wonenApi = 'https://regiovoorneaanzee.nl/wp-json/rvaz-wonen/v1';

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
    throw Exception('Wonen API HTTP ${response.statusCode}');
  }
  return jsonDecode(response.body);
}

List<Map<String, dynamic>> wonenItems(dynamic data) {
  final raw = data is List
      ? data
      : data is Map ? (data['items'] ?? data['data'] ?? data['results'] ?? []) : [];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String wonenText(Map<String, dynamic> item, String key) {
  final value = item[key];
  if (value == null || value is bool) return '';
  final text = value.toString().trim();
  return text.toLowerCase() == 'false' || text.toLowerCase() == 'null'
      ? ''
      : text;
}

// Gebruik de echte woningweergave van de website zolang de publieke API
// ingevulde woningvelden ten onrechte als false teruggeeft.
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
    future = wonenRequest('/woningen');
  }

  void reload() => setState(() => future = wonenRequest('/woningen'));

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
                      '${wonenText(item, 'woonoppervlak')} m² wonen',
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
        const Text('Meer informatie of contact met de makelaar is momenteel '
          'alleen beschikbaar wanneer de makelaars-API dit ondersteunt.'),
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
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    future = wonenRequest('/makelaar/woningen');
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WoningEditorPage(item: item)),
    );
    if (mounted) setState(refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Wonen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Woning toevoegen'),
      ),
      body: FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(
              'Makelaarstoegang of mobiele API niet beschikbaar.\n${snapshot.error}',
            ));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = wonenItems(snapshot.data);
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Aanvragen'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WonenAanvragenPage()),
                ),
              ),
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(wonenText(item, 'title')),
                    subtitle: Text(wonenText(item, 'publication_status')),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => edit(item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? <String, dynamic>{};
    id = int.tryParse(wonenText(item, 'id'));
    publicationStatus = wonenText(item, 'publication_status') == 'publish'
        ? 'publish' : 'draft';
    fields = {
      for (final key in [
        'title', 'description', 'adres', 'postcode', 'plaats', 'prijs',
        'transactie', 'woningtype', 'kamers', 'slaapkamers',
        'woonoppervlak', 'energielabel'
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
        setState(() => id = savedId ?? id);
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
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo == null) return;
    setState(() => busy = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$wonenApi/makelaar/woningen/$id/fotos'),
      );
      request.headers.addAll(await wonenHeaders());
      request.headers.remove('Content-Type');
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      final response = await request.send();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Upload HTTP ${response.statusCode}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto toegevoegd')),
        );
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
                  labelText: entry.key,
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
        ],
      ),
    );
  }
}

class WonenAanvragenPage extends StatelessWidget {
  const WonenAanvragenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Woningaanvragen')),
      body: FutureBuilder<dynamic>(
        future: wonenRequest('/makelaar/aanvragen'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = wonenItems(snapshot.data);
          return ListView(
            children: [
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(wonenText(item, 'name')),
                    subtitle: Text(
                      '${wonenText(item, 'email')} · ${wonenText(item, 'phone')}\n'
                      '${wonenText(item, 'message')}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
