import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const RvazApp());

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
    InfoPage('Nieuws', 'Al het nieuws uit Voorne aan Zee.'),
    InfoPage('Weekblad', 'Het digitale Weekblad Voorne aan Zee.'),
    InfoPage('Agenda', 'Evenementen en activiteiten in de regio.'),
    InfoPage('Account', 'Mijn RVAZ: favorieten, meldingen en bijdragen.'),
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

class InfoPage extends StatelessWidget {
  final String title;
  final String text;
  const InfoPage(this.title, this.text, {super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(text,
                      style: const TextStyle(fontSize: 17, height: 1.5)))),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(site), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open website')),
        ],
      );
}
