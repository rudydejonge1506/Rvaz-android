import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await messaging.subscribeToTopic('rvaz_all');
  await messaging.subscribeToTopic('breaking');
  await messaging.subscribeToTopic('traffic');
  await messaging.subscribeToTopic('weekblad');
  runApp(const RvazApp());
}

const site = 'https://regiovoorneaanzee.nl';
const navy = Color(0xFF203253);
const cyan = Color(0xFF11BDEB);
const green = Color(0xFF00CE8B);

class RvazApp extends StatelessWidget {
  const RvazApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Regio Voorne aan Zee',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: cyan),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F9FB),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  final pages = const [
    NewsPage(),
    NewsPage(),
    WeekbladPage(),
    AgendaPage(),
    AccountPage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          title: const Row(children: [
            LogoMark(),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Regio Voorne aan Zee',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Actueel · Betrokken · Dichtbij',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
          actions: [
            IconButton(
                onPressed: () {}, icon: const Icon(Icons.notifications_none)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          ],
        ),
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.article_outlined), label: 'Nieuws'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined), label: 'Weekblad'),
            NavigationDestination(
                icon: Icon(Icons.event_outlined), label: 'Agenda'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Account'),
          ],
        ),
      );
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 42,
        height: 42,
        child: Stack(children: [
          Positioned(
              left: 14,
              top: 0,
              child: Container(width: 24, height: 30, color: navy)),
          Positioned(
              left: 0,
              top: 12,
              child: Container(width: 26, height: 24, color: green)),
          Positioned(
              left: 5,
              bottom: 0,
              child: Container(width: 37, height: 14, color: cyan)),
          const Positioned(
              left: 20,
              top: 19,
              child:
                  Icon(Icons.water_drop, color: Color(0xFFFFC400), size: 16)),
        ]),
      );
}

String postImage(dynamic p) {
  try {
    final media = p['_embedded']?['wp:featuredmedia'];
    if (media is List && media.isNotEmpty) {
      return media.first['source_url']?.toString() ?? '';
    }
  } catch (_) {}
  return '';
}

class ArticlePage extends StatelessWidget {
  final dynamic post;
  const ArticlePage({super.key, required this.post});

  String clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8211;', '–');

  @override
  Widget build(BuildContext context) {
    final image = postImage(post);
    final title = clean(post['title']?['rendered']?.toString() ?? '');
    final body = clean(post['content']?['rendered']?.toString() ?? '');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Regio Voorne aan Zee',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        children: [
          if (image.isNotEmpty)
            Image.network(image, height: 240, width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NIEUWS',
                    style: TextStyle(color: cyan, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: navy, fontSize: 29, height: 1.08,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                Text(body, style: const TextStyle(fontSize: 17, height: 1.55)),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(post['link']),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Bekijk origineel op de website'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late Future<List<dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<dynamic>> load() async {
    final r =
        await http.get(Uri.parse('$site/wp-json/wp/v2/posts?per_page=12&_embed=1'));
    if (r.statusCode != 200) {
      throw Exception('Nieuws kon niet worden geladen');
    }
    return jsonDecode(r.body);
  }

  String clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8211;', '–');

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => setState(() => future = load()),
        child: FutureBuilder<List<dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                const SizedBox(height: 180),
                Center(child: Text(snapshot.error.toString()))
              ]);
            }
            final posts = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Het laatste uit de regio',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: navy)),
                const SizedBox(height: 5),
                const Text('Actueel nieuws van Regio Voorne aan Zee.'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    'Voorne aan Zee',
                    'Hellevoetsluis',
                    'Brielle',
                    'Rockanje',
                    'Oostvoorne'
                  ].map((x) => Chip(label: Text(x))).toList(),
                ),
                const SizedBox(height: 12),
                ...posts.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ArticlePage(post: p))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (postImage(p).isNotEmpty)
                            Image.network(postImage(p), height: 190, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NIEUWS',
                                style: TextStyle(
                                    color: cyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(clean(p['title']['rendered']),
                                style: const TextStyle(
                                    fontSize: 20,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                    color: navy)),
                            const SizedBox(height: 8),
                            Text(clean(p['excerpt']['rendered']),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(height: 1.4)),
                          ],
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}


class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}
class _AgendaPageState extends State<AgendaPage> {
  late Future<List<dynamic>> future;
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<dynamic>> load() async {
    for (final endpoint in ['evenementen', 'events']) {
      final r = await http.get(Uri.parse('$site/wp-json/wp/v2/$endpoint?per_page=20&_embed=1'));
      if (r.statusCode == 200) return jsonDecode(r.body);
    }
    return [];
  }
  String clean(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&');
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final items = s.data ?? [];
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Agenda', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 4),
        const Text('Evenementen en activiteiten op Voorne.'),
        const SizedBox(height: 18),
        if (items.isEmpty) const Card(child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('De agenda wordt rechtstreeks met de RVAZ-agenda gekoppeld. Er zijn via de openbare WordPress-API nu nog geen evenementen beschikbaar.', style: TextStyle(fontSize: 16, height: 1.45)),
        )),
        ...items.map((p) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: const CircleAvatar(backgroundColor: Color(0xFFE2F7FC), child: Icon(Icons.event, color: navy)),
            title: Text(clean(p['title']?['rendered']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
            subtitle: Text(clean(p['excerpt']?['rendered']?.toString() ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        )),
      ]);
    },
  );
}

class WeekbladPage extends StatelessWidget {
  const WeekbladPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text('Weekblad', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 4),
      const Text('Weekblad Voorne aan Zee'),
      const SizedBox(height: 18),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.menu_book_rounded, size: 54, color: cyan),
            const SizedBox(height: 14),
            const Text('Digitale krant in de app', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 8),
            const Text('De reader blijft binnen RVAZ: editie kiezen, bladeren, zoomen en volledig scherm. De koppeling gebruikt straks dezelfde edities als de Weekblad-plugin.', style: TextStyle(fontSize: 16, height: 1.45)),
          ]),
        ),
      ),
    ],
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}
class _AccountPageState extends State<AccountPage> {
  bool breaking = true, emergency = true, traffic = true, events = false, weekblad = true;
  Widget sw(String title, String subtitle, bool value, ValueChanged<bool> change) => SwitchListTile(
    value: value, onChanged: change, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle), activeThumbColor: cyan);
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Mijn RVAZ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: navy)),
    const SizedBox(height: 14),
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [CircleAvatar(radius: 25, backgroundColor: Color(0xFFE2F7FC), child: Icon(Icons.person, color: navy)), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RVAZ-account', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy)), Text('Hetzelfde account als op de website')]))]),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.login), label: const Text('Inloggen / account koppelen')),
    ]))),
    const SizedBox(height: 14),
    const Text('Pushmeldingen', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: navy)),
    Card(child: Column(children: [
      sw('Breaking nieuws', 'Belangrijk regionaal nieuws', breaking, (v)=>setState(()=>breaking=v)),
      sw('112', 'Grote incidenten en hulpdiensten', emergency, (v)=>setState(()=>emergency=v)),
      sw('Verkeer', 'Afsluitingen en belangrijke verkeersmeldingen', traffic, (v)=>setState(()=>traffic=v)),
      sw('Agenda', 'Uitgelichte activiteiten', events, (v)=>setState(()=>events=v)),
      sw('Nieuw Weekblad', 'Melding bij een nieuwe editie', weekblad, (v)=>setState(()=>weekblad=v)),
    ])),
    const SizedBox(height: 14),
    Card(child: Column(children: const [
      ListTile(leading: Icon(Icons.bookmark_outline), title: Text('Opgeslagen artikelen'), trailing: Icon(Icons.chevron_right)),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.campaign_outlined), title: Text('Tip de redactie'), trailing: Icon(Icons.chevron_right)),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.article_outlined), title: Text('Mijn bijdragen'), trailing: Icon(Icons.chevron_right)),
    ])),
  ]);
}
