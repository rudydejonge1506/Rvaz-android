import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const site = 'https://regiovoorneaanzee.nl';

final navigatorKey = GlobalKey<NavigatorState>();

class AppConfig {
  final String logoUrl, homeIntro, breakingBanner, homeTitle, latestTitle, agendaTitle, weekbladTitle, accountTitle;
  final List<String> places, navOrder, homeBlocks, accountBlocks;
  final Map<String,bool> navigation, features;
  final Map<String,dynamic> limits;
  final Color primary, accent, success, background;
  const AppConfig({
    this.logoUrl='', this.homeIntro='Actueel nieuws van Regio Voorne aan Zee.', this.breakingBanner='',
    this.homeTitle='Regio Voorne aan Zee', this.latestTitle='Laatste nieuws', this.agendaTitle='Agenda',
    this.weekbladTitle='Weekblad', this.accountTitle='Mijn RVAZ',
    this.places=const ['Voorne aan Zee','Hellevoetsluis','Brielle','Rockanje','Oostvoorne'],
    this.navOrder=const ['home','news','weekblad','agenda','account'],
    this.homeBlocks=const ['news','agenda','weekblad','ads'],
    this.accountBlocks=const ['saved','notifications','tips','contributions','weekblad','profile'],
    this.navigation=const {'home':true,'news':true,'weekblad':true,'agenda':true,'account':true},
    this.features=const {'search':true,'saved':true,'tips':true,'contributions':true,'push':true,'share':true,'listen':true,'traffic':true,'emergency112':true},
    this.limits=const {'news_per_page':20,'home_news':8,'agenda_home':4,'ad_frequency':5},
    this.primary=navy, this.accent=cyan, this.success=green, this.background=const Color(0xFFF7F9FB),
  });
  static Color _color(dynamic v, Color fallback) {
    final x=(v??'').toString().replaceAll('#','');
    final n=int.tryParse(x.length==6?'FF$x':x,radix:16);
    return n==null?fallback:Color(n);
  }
  factory AppConfig.fromJson(Map<String,dynamic> j) {
    final theme=j['theme'] is Map?Map<String,dynamic>.from(j['theme']):<String,dynamic>{};
    final texts=j['texts'] is Map?Map<String,dynamic>.from(j['texts']):<String,dynamic>{};
    Map<String,bool> boolMap(dynamic x)=>x is Map?x.map((k,v)=>MapEntry(k.toString(),v==true||v==1)):<String,bool>{};
    List<String> list(dynamic x,List<String> d)=>x is List?x.map((e)=>e.toString()).toList():d;
    return AppConfig(
      logoUrl:(j['logo_url']??'').toString(), homeIntro:(j['home_intro']??'Actueel nieuws van Regio Voorne aan Zee.').toString(),
      breakingBanner:(j['breaking_banner']??'').toString(),
      homeTitle:(texts['home_title']??'Regio Voorne aan Zee').toString(), latestTitle:(texts['latest_title']??'Laatste nieuws').toString(),
      agendaTitle:(texts['agenda_title']??'Agenda').toString(), weekbladTitle:(texts['weekblad_title']??'Weekblad').toString(),
      accountTitle:(texts['account_title']??'Mijn RVAZ').toString(),
      places:list(j['places'],const ['Voorne aan Zee','Hellevoetsluis','Brielle','Rockanje','Oostvoorne']),
      navOrder:list(j['nav_order'],const ['home','news','weekblad','agenda','account']), homeBlocks:list(j['home_blocks'],const ['news','agenda','weekblad','ads']),
      accountBlocks:list(j['account_blocks'],const ['saved','notifications','tips','contributions','weekblad','profile']),
      navigation:boolMap(j['navigation']), features:boolMap(j['features']),
      limits:j['limits'] is Map?Map<String,dynamic>.from(j['limits']):const {'news_per_page':20,'home_news':8,'agenda_home':4,'ad_frequency':5},
      primary:_color(theme['primary'],navy), accent:_color(theme['accent']??j['accent_color'],cyan), success:_color(theme['success'],green),
      background:_color(theme['background'],const Color(0xFFF7F9FB)),
    );
  }
  bool feature(String key,[bool fallback=true])=>features.containsKey(key)?features[key]!:fallback;
  bool nav(String key)=>navigation.containsKey(key)?navigation[key]!:true;
  int limit(String key,int fallback)=>int.tryParse('${limits[key]??fallback}')??fallback;
}
AppConfig appConfig=const AppConfig();
Future<void> loadConfig() async {try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/config'));if(r.statusCode==200){final d=jsonDecode(r.body);if(d is Map<String,dynamic>)appConfig=AppConfig.fromJson(d);}}catch(_){}}

Future<void> registerDeviceToken() async {
  final m = FirebaseMessaging.instance;
  final token = await m.getToken();
  if (token == null || token.isEmpty) return;
  try {
    await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/device'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'token':token,'topics':['all','breaking','112','verkeer','agenda','weekblad']}));
  } catch (_) {}
}


Future<void> openPushMessage(RemoteMessage message) async {
  final data = message.data;
  final rawId = data['post_id'] ?? data['postId'] ?? data['id'];
  final postId = int.tryParse('${rawId ?? ''}');
  final link = data['url']?.toString() ?? data['link']?.toString() ?? '';
  dynamic post;
  try {
    if (postId != null && postId > 0) {
      final r = await http.get(Uri.parse('$site/wp-json/wp/v2/posts/$postId?_embed=1'));
      if (r.statusCode == 200) post = jsonDecode(r.body);
    } else if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      final slug = uri?.pathSegments.where((x) => x.isNotEmpty).lastOrNull;
      if (slug != null) {
        final r = await http.get(Uri.parse('$site/wp-json/wp/v2/posts?slug=${Uri.encodeQueryComponent(slug)}&_embed=1'));
        if (r.statusCode == 200) {
          final list = jsonDecode(r.body);
          if (list is List && list.isNotEmpty) post = list.first;
        }
      }
    }
  } catch (_) {}
  if (post != null) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ArticlePage(post: post)));
  } else if (link.isNotEmpty) {
    launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await loadConfig();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await messaging.subscribeToTopic('all');
  await messaging.subscribeToTopic('breaking');
  await messaging.subscribeToTopic('112');
  await messaging.unsubscribeFromTopic('traffic');
  await messaging.subscribeToTopic('verkeer');
  await messaging.subscribeToTopic('agenda');
  await messaging.subscribeToTopic('weekblad');
  await registerDeviceToken();
  messaging.onTokenRefresh.listen((_) => registerDeviceToken());
  FirebaseMessaging.onMessageOpenedApp.listen(openPushMessage);
  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => openPushMessage(initialMessage));
  }
  FirebaseMessaging.onMessage.listen((m) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m.notification?.title ?? 'Nieuwe RVAZ-melding')));
  });
  runApp(const RvazApp());
}

const navy = Color(0xFF203253);
const cyan = Color(0xFF11BDEB);
const green = Color(0xFF00CE8B);

class RvazApp extends StatelessWidget {
  const RvazApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Regio Voorne aan Zee',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: appConfig.accent),
          useMaterial3: true,
          scaffoldBackgroundColor: appConfig.background,
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
  static const pageMap = <String,Widget>{
    'home': HomePage(),
    'news': NewsPage(),
    'weekblad': WeekbladPage(),
    'agenda': AgendaPage(),
    'account': AccountPage(),
  };
  static const iconMap = <String,IconData>{
    'home':Icons.home_outlined,'news':Icons.article_outlined,'weekblad':Icons.menu_book_outlined,'agenda':Icons.event_outlined,'account':Icons.person_outline,
  };
  static const labelMap = <String,String>{'home':'Home','news':'Nieuws','weekblad':'Weekblad','agenda':'Agenda','account':'Account'};

  @override
  Widget build(BuildContext context) {
    final keys=appConfig.navOrder.where((k)=>pageMap.containsKey(k)&&appConfig.nav(k)).toList();
    if(keys.isEmpty) keys.addAll(['home','news','weekblad','agenda','account']);
    if(index>=keys.length) index=0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: appConfig.primary,
        title: const Row(children: [Expanded(child: LogoMark())]),
        actions: [
          if(appConfig.feature('push') && keys.contains('account')) IconButton(onPressed:()=>setState(()=>index=keys.indexOf('account')),icon:const Icon(Icons.notifications_none)),
          if(appConfig.feature('search')) IconButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const SearchPage())),icon:const Icon(Icons.search)),
        ],
      ),
      body: pageMap[keys[index]],
      bottomNavigationBar: NavigationBar(
        selectedIndex:index,
        onDestinationSelected:(v)=>setState(()=>index=v),
        destinations:keys.map((k)=>NavigationDestination(icon:Icon(iconMap[k]),label:labelMap[k]??k)).toList(),
      ),
    );
  }
}

class LogoMark extends StatefulWidget {
  const LogoMark({super.key});
  @override
  State<LogoMark> createState() => _LogoMarkState();
}
class _LogoMarkState extends State<LogoMark> {
  String logoUrl = '';
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/config'));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        final u = j['logo_url']?.toString() ?? '';
        if (mounted && u.isNotEmpty) setState(() => logoUrl = u);
      }
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 41,
    child: logoUrl.isNotEmpty
      ? Image.network(logoUrl, width: 220, height: 41, fit: BoxFit.contain, alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => Image.asset('assets/rvaz-logo.png', width: 220, height: 41, fit: BoxFit.contain, alignment: Alignment.centerLeft))
      : Image.asset('assets/rvaz-logo.png', width: 220, height: 41, fit: BoxFit.contain, alignment: Alignment.centerLeft),
  );
}

class AppAd {
  final int id;
  final String title, image, url, label;
  const AppAd(this.id, this.title, this.image, this.url, this.label);
  factory AppAd.fromJson(dynamic j) => AppAd(
    int.tryParse('${j['id'] ?? 0}') ?? 0,
    '${j['title'] ?? j['name'] ?? 'Advertentie'}',
    '${j['image'] ?? j['image_url'] ?? ''}',
    '${j['url'] ?? j['link'] ?? ''}',
    '${j['label'] ?? 'Advertentie'}',
  );
}

Future<List<AppAd>> loadAppAds({String placement = 'news_feed'}) async {
  final uris = [
    Uri.parse('$site/wp-json/rvaz-app/v1/ads?placement=$placement'),
    Uri.parse('$site/wp-json/rvaz-ads/v1/ads?placement=$placement'),
    Uri.parse('$site/wp-json/rvaz/v1/app-ads?placement=$placement'),
  ];
  for (final uri in uris) {
    try {
      final r = await http.get(uri);
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        final list = decoded is List ? decoded : (decoded['ads'] is List ? decoded['ads'] : []);
        final ads = list.map<AppAd>((x) => AppAd.fromJson(x)).where((a)=>a.id>0).toList();
        if (ads.isNotEmpty) return ads;
      }
    } catch (_) {}
  }
  return [];
}

Future<void> trackAd(int id, String type) async { try { await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/ad-event'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'id':id,'type':type})); } catch (_) {} }

class AppAdCard extends StatefulWidget {
  final AppAd ad;
  const AppAdCard({super.key, required this.ad});
  @override State<AppAdCard> createState()=>_AppAdCardState();
}
class _AppAdCardState extends State<AppAdCard> {
  bool sent=false;
  @override void didChangeDependencies(){super.didChangeDependencies();if(!sent){sent=true;trackAd(widget.ad.id,'impression');}}
  @override Widget build(BuildContext context){final ad=widget.ad; return Card(
    margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: ad.url.isEmpty?null:() async {await trackAd(ad.id,'click'); if(context.mounted) Navigator.of(context).push(MaterialPageRoute(builder:(_)=>InAppWebPage(title:ad.title,url:ad.url)));},child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(ad.image.isNotEmpty)Image.network(ad.image,height:150,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(ad.label.toUpperCase(),style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Colors.black54)),const SizedBox(height:4),Text(ad.title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:navy))]))])));
  }
}

String formatPostDate(dynamic p) {
  final raw = p['date']?.toString() ?? '';
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return '';
  const months = ['januari','februari','maart','april','mei','juni','juli','augustus','september','oktober','november','december'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year} · $hh:$mm';
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
    final bodyHtml = post['content']?['rendered']?.toString() ?? '';
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
                Html(data: bodyHtml, style: {'body': Style(fontSize: FontSize(17), lineHeight: const LineHeight(1.45), margin: Margins.zero), 'p': Style(margin: Margins.only(bottom: 14)), 'h2': Style(color: navy, fontWeight: FontWeight.w800), 'h3': Style(color: navy, fontWeight: FontWeight.w800)}),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage>{
  late Future<List<dynamic>> posts;
  late Future<List<dynamic>> events;
  late Future<List<AppAd>> ads;
  @override void initState(){super.initState();_reload();}
  void _reload(){posts=_posts();events=_events();ads=loadAppAds(placement:'home');}
  Future<List<dynamic>> _posts() async {
    final r=await http.get(Uri.parse('$site/wp-json/wp/v2/posts?per_page=${appConfig.limit('home_news',8)}&_embed=1'));
    return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];
  }
  Future<List<dynamic>> _events() async {
    final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/agenda?per_page=20'));
    if(r.statusCode!=200)return [];
    final d=jsonDecode(r.body);
    return d is List?List<dynamic>.from(d):(d is Map&&d['items'] is List?List<dynamic>.from(d['items']):[]);
  }
  String clean(dynamic s)=>'$s'.replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&amp;','&').replaceAll('&#8211;','–');
  @override Widget build(BuildContext context)=>RefreshIndicator(
    onRefresh:()async{setState(_reload);await Future.wait([posts,events,ads]);},
    child:ListView(padding:const EdgeInsets.all(16),children:[
      FutureBuilder<List<dynamic>>(future:posts,builder:(context,s){
        final x=s.data??[];
        final image=x.isNotEmpty?postImage(x.first):'';
        return Container(
          constraints:const BoxConstraints(minHeight:210),
          padding:const EdgeInsets.all(20),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(18),
            gradient:image.isEmpty?const LinearGradient(colors:[navy,Color(0xFF087BA8)]):null,
            image:image.isEmpty?null:DecorationImage(image:NetworkImage(image),fit:BoxFit.cover,colorFilter:ColorFilter.mode(navy.withValues(alpha:.64),BlendMode.srcOver)),
          ),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.end,children:[
            if(appConfig.breakingBanner.isNotEmpty)Text(appConfig.breakingBanner,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),
            const Spacer(),Text('Welkom bij\nRegio Voorne aan Zee',style:const TextStyle(color:Colors.white,fontSize:28,height:1.05,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),Text(appConfig.homeIntro,style:const TextStyle(color:Colors.white)),
          ]),
        );
      }),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:_HomeShortcut(icon:Icons.location_on,color:Colors.blue,label:'Plaatsnieuws')),
        const SizedBox(width:8),Expanded(child:_HomeShortcut(icon:Icons.warning_amber_rounded,color:Colors.red,label:'112 & Verkeer')),
        const SizedBox(width:8),Expanded(child:_HomeShortcut(icon:Icons.calendar_month,color:Colors.blue,label:'Agenda')),
        const SizedBox(width:8),Expanded(child:_HomeShortcut(icon:Icons.menu_book,color:green,label:'Weekblad')),
      ]),
      const SizedBox(height:18),
      if(appConfig.homeBlocks.contains('news')) ...[
        Text(appConfig.latestTitle,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),
        FutureBuilder<List<dynamic>>(future:posts,builder:(context,s)=>Column(children:(s.data??[]).take(5).map<Widget>((p)=>Card(child:ListTile(
          leading:postImage(p).isEmpty?const Icon(Icons.article_outlined):Image.network(postImage(p),width:78,height:58,fit:BoxFit.cover),
          title:Text(clean(p['title']?['rendered']??''),maxLines:2,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),
          subtitle:Text(formatPostDate(p)),
          onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ArticlePage(post:p))),
        ))).toList())),
        const SizedBox(height:12),
      ],
      if(appConfig.homeBlocks.contains('ads')) FutureBuilder<List<AppAd>>(future:ads,builder:(context,s){final x=s.data??[];return x.isEmpty?const SizedBox.shrink():AppAdCard(ad:x.first);}),
      if(appConfig.homeBlocks.contains('agenda')) ...[
        const SizedBox(height:12),Text(appConfig.agendaTitle,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),
        FutureBuilder<List<dynamic>>(future:events,builder:(context,s)=>Column(children:(s.data??[]).take(appConfig.limit('agenda_home',4)).map<Widget>((e)=>Card(child:ListTile(
          leading:const Icon(Icons.event_outlined,color:navy),
          title:Text(clean(e['title'] is Map?e['title']['rendered']:e['title']??''),style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Text([e['display_date'],e['location'],e['place']].where((x)=>x!=null&&'$x'.isNotEmpty).join(' · ')),
          onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDetailPage(event:e))),
        ))).toList())),
      ],
    ]),
  );
}
class _HomeShortcut extends StatelessWidget{
  final IconData icon;final Color color;final String label;
  const _HomeShortcut({required this.icon,required this.color,required this.label});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(vertical:12,horizontal:4),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFE2E8EE))),child:Column(children:[Icon(icon,color:color),const SizedBox(height:5),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:navy))]));
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late Future<List<dynamic>> future;
  late Future<List<AppAd>> adsFuture;
  @override
  void initState() {
    super.initState();
    future = load();
    adsFuture = loadAppAds();
  }

  Future<List<dynamic>> load() async {
    final count=appConfig.limit('news_per_page',20).clamp(1,100);
    final r = await http.get(Uri.parse('$site/wp-json/wp/v2/posts?per_page=$count&_embed=1'));
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
            return FutureBuilder<List<AppAd>>(future: adsFuture, builder: (context, adSnapshot) {
            final ads = adSnapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(appConfig.latestTitle,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: navy)),
                const SizedBox(height: 5),
                Text(appConfig.homeIntro),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: appConfig.places.map((x) => ActionChip(
                      label: Text(x),
                      onPressed: () {
                        final filtered = x == 'Voorne aan Zee'
                            ? load()
                            : http.get(Uri.parse('$site/wp-json/wp/v2/search?search=${Uri.encodeQueryComponent(x)}&subtype=post&per_page=30')).then((r) async {
                                if (r.statusCode != 200) return <dynamic>[];
                                final ids = (jsonDecode(r.body) as List).map((e) => e['id']).whereType<int>().toList();
                                if (ids.isEmpty) return <dynamic>[];
                                final pr = await http.get(Uri.parse('$site/wp-json/wp/v2/posts?include=${ids.join(',')}&per_page=30&_embed=1'));
                                return pr.statusCode == 200 ? List<dynamic>.from(jsonDecode(pr.body)) : <dynamic>[];
                              });
                        setState(() => future = filtered);
                      },
                    )).toList(),
                ),
                const SizedBox(height: 12),
                ...posts.asMap().entries.expand((entry) {
                  final p = entry.value;
                  final widgets = <Widget>[Card(
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
                            const SizedBox(height: 6),
                            if (formatPostDate(p).isNotEmpty) ...[
                              Row(children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.black54),
                                const SizedBox(width: 5),
                                Text(formatPostDate(p), style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 8),
                            ],
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
                  )];
                  final freq=appConfig.limit('ad_frequency',5).clamp(2,20); if (ads.isNotEmpty && entry.key>0 && (entry.key+1)%freq==0) widgets.add(AppAdCard(ad: ads[(entry.key~/freq)%ads.length]));
                  return widgets;
                }),
              ],
            ); });
          },
        ),
      );
}


class AgendaPage extends StatefulWidget{const AgendaPage({super.key});@override State<AgendaPage> createState()=>_AgendaPageState();}
class _AgendaPageState extends State<AgendaPage>{
  late Future<List<dynamic>> future; String place='Alle plaatsen',category='Alle categorieën',period='Alles';
  @override void initState(){super.initState();future=load();}
  Future<List<dynamic>> load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/agenda?per_page=250'));if(r.statusCode!=200)return[];final d=jsonDecode(r.body);return d is List?List<dynamic>.from(d):(d is Map&&d['items'] is List?List<dynamic>.from(d['items']):[]);}
  String val(dynamic p,List<String> k){for(final x in k){final z=p[x];if(z!=null&&'$z'.trim().isNotEmpty)return '$z';}return'';}
  DateTime? date(dynamic p)=>DateTime.tryParse(val(p,['start_date','date']));
  String clean(dynamic s)=>'$s'.replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&amp;','&').replaceAll('&#8211;','–');
  String title(dynamic p){final t=p['title'];return clean(t is Map?t['rendered']:t??'');}
  String placeOf(dynamic p)=>val(p,['place','city','town','plaats']);
  String catOf(dynamic p){final x=p['category']??p['categories']??p['event_category'];if(x is List)return x.map((e)=>e is Map?(e['name']??e['title']??''):'$e').where((e)=>'$e'.isNotEmpty).join(', ');if(x is Map)return '${x['name']??x['title']??''}';return x?.toString()??'';}
  bool periodOk(dynamic p){final d=date(p);if(period=='Alles'||d==null)return true;final n=DateTime.now(),t=DateTime(n.year,n.month,n.day);if(period=='Vandaag')return d.year==t.year&&d.month==t.month&&d.day==t.day;if(period=='Deze week')return !d.isBefore(t)&&d.isBefore(t.add(const Duration(days:7)));return d.year==t.year&&d.month==t.month;}
  @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(future:future,builder:(context,s){
    if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    final all=s.data??[];
    final places=<String>{'Alle plaatsen',...all.map(placeOf).where((x)=>x.isNotEmpty)}.toList()..sort();
    final cats=<String>{'Alle categorieën',...all.map(catOf).where((x)=>x.isNotEmpty)}.toList()..sort();
    final n=DateTime.now(),today=DateTime(n.year,n.month,n.day);
    final items=all.where((p){final d=date(p);return(d==null||!d.isBefore(today))&&(place=='Alle plaatsen'||placeOf(p)==place)&&(category=='Alle categorieën'||catOf(p).contains(category))&&periodOk(p);}).toList()..sort((a,b)=>(date(a)??DateTime(2100)).compareTo(date(b)??DateTime(2100)));
    return ListView(padding:const EdgeInsets.all(18),children:[
      Text(appConfig.agendaTitle,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:navy)),const Text('Evenementen en activiteiten op Voorne.'),const SizedBox(height:12),
      Wrap(spacing:10,runSpacing:6,children:[
        DropdownButton<String>(value:places.contains(place)?place:'Alle plaatsen',items:places.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>place=v??'Alle plaatsen')),
        DropdownButton<String>(value:cats.contains(category)?category:'Alle categorieën',items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v??'Alle categorieën')),
        DropdownButton<String>(value:period,items:['Alles','Vandaag','Deze week','Deze maand'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>period=v??'Alles')),
      ]),
      const SizedBox(height:12),
      if(items.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Geen evenementen gevonden met deze filters.'))),
      ...items.map<Widget>((p)=>Card(child:ListTile(
        contentPadding:const EdgeInsets.all(14),leading:const CircleAvatar(child:Icon(Icons.event)),title:Text(title(p),style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),
        subtitle:Text([val(p,['display_date','start_date','date']),val(p,['time','start_time']),val(p,['venue','location']),placeOf(p),catOf(p)].where((x)=>x.isNotEmpty).join(' · '),maxLines:4),
        trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDetailPage(event:p))),
      ))),
    ]);
  });
}

class WeekbladPage extends StatefulWidget {
  const WeekbladPage({super.key});
  @override State<WeekbladPage> createState()=>_WeekbladPageState();
}
class _WeekbladPageState extends State<WeekbladPage> {
  late Future<List<dynamic>> future;
  @override void initState(){super.initState();future=load();}
  Future<List<dynamic>> load() async { final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/weekblad')); if(r.statusCode==200)return jsonDecode(r.body); return []; }
  @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(future:future,builder:(context,s){
    if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    final issues=s.data??[];
    return ListView(padding:const EdgeInsets.all(18),children:[
      Text(appConfig.weekbladTitle,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:navy)),
      const Text('Weekblad Voorne aan Zee'),const SizedBox(height:18),
      if(issues.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Er zijn nog geen gepubliceerde edities via de app-API beschikbaar.'))),
      ...issues.map((x)=>Card(child:ListTile(leading:const Icon(Icons.menu_book,color:navy),title:Text('${x['title']??'Weekblad'}'.replaceAll('&#8211;','–').replaceAll('&amp;','&'),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${x['date']??''} · ${x['pages']??0} pagina’s'),trailing:const Icon(Icons.chevron_right),onTap:()=>launchUrl(Uri.parse('${x['pdf']}'),mode:LaunchMode.externalApplication))))
    ]);
  });
}

class AccountPage extends StatefulWidget { const AccountPage({super.key}); @override State<AccountPage> createState()=>_AccountPageState(); }
class _AccountPageState extends State<AccountPage>{
 String? userName; bool busy=false; bool advertiser=false; Map<String,dynamic> userInfo={};
 @override void initState(){super.initState();restore();}
 Future<void> restore()async{final t=await const FlutterSecureStorage().read(key:'rvaz_token');if(t==null)return;try{final r=await http.get(Uri.parse('\$site/wp-json/rvaz-app/v1/me'),headers:{'Authorization':'Bearer $t'});if(r.statusCode==200){final d=jsonDecode(r.body);if(mounted)setState((){userInfo=Map<String,dynamic>.from(d['user']??{});userName=userInfo['name']?.toString();advertiser=userInfo['advertiser']==true;});}}catch(_){}}
 Future<void> auth(bool reg)async{final n=TextEditingController(),e=TextEditingController(),p=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(reg?'Account aanmaken':'Inloggen'),content:Column(mainAxisSize:MainAxisSize.min,children:[if(reg)TextField(controller:n,decoration:const InputDecoration(labelText:'Naam')),TextField(controller:e,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mailadres')),TextField(controller:p,obscureText:true,decoration:InputDecoration(labelText:'Wachtwoord',helperText:reg?'Minimaal 8 tekens':null))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Annuleren')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(reg?'Account aanmaken':'Inloggen'))]));if(ok!=true)return;if(reg&&(n.text.trim().isEmpty||p.text.length<8)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Naam en minimaal 8 tekens voor het wachtwoord zijn nodig.')));return;}setState(()=>busy=true);try{final body=reg?{'name':n.text.trim(),'email':e.text.trim(),'password':p.text}:{'login':e.text.trim(),'password':p.text};final endpoint=reg?'register':'login';final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/$endpoint'),headers:{'Content-Type':'application/json','Accept':'application/json'},body:jsonEncode(body));if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body),t=d['token']?.toString()??'';if(t.isNotEmpty)await const FlutterSecureStorage().write(key:'rvaz_token',value:t);if(mounted){final u=Map<String,dynamic>.from(d['user']??{});setState((){userInfo=u;userName=u['name']?.toString()??n.text.trim();advertiser=u['advertiser']==true;});}}else{String m='Inloggen of registreren mislukt.';try{m=jsonDecode(r.body)['message']?.toString()??m;}catch(_){}if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));}}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding met RVAZ.')));}if(mounted)setState(()=>busy=false);}
 Future<void> logout()async{final t=await const FlutterSecureStorage().read(key:'rvaz_token');if(t!=null){try{await http.post(Uri.parse('\$site/wp-json/rvaz-app/v1/logout'),headers:{'Authorization':'Bearer $t'});}catch(_){}}await const FlutterSecureStorage().delete(key:'rvaz_token');if(mounted)setState((){userName=null;advertiser=false;userInfo={};});}
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(appConfig.accountTitle, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RVAZ-account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 5),
        Text(userName == null ? 'Hetzelfde account werkt op website en app' : 'Ingelogd als $userName'),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (userName == null) Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(onPressed: busy ? null : () => auth(false), icon: const Icon(Icons.login), label: const Text('Inloggen')),
          OutlinedButton.icon(onPressed: busy ? null : () => auth(true), icon: const Icon(Icons.person_add), label: const Text('Account aanmaken')),
        ]) else OutlinedButton.icon(onPressed: logout, icon: const Icon(Icons.logout), label: const Text('Uitloggen')),
      ]))),
      const SizedBox(height: 14),
      if (userName != null) Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Mijn profiel'), subtitle: Text(userInfo['email']?.toString()??''), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user:userInfo)))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Meldingen'), subtitle: const Text('Kies welke pushmeldingen je ontvangt'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.bookmark_outline), title: const Text('Opgeslagen artikelen'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.campaign_outlined), title: const Text('Tip de redactie'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TipPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.article_outlined), title: const Text('Mijn bijdragen'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributionsPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Weekblad'), subtitle: const Text('Lees de nieuwste editie'), trailing: const Icon(Icons.chevron_right)),
        if (advertiser) ...[
          const Divider(height:1),
          ListTile(leading: const Icon(Icons.campaign), title: const Text('Mijn advertenties'), subtitle: const Text('Campagnes, bereik en klikken'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAdsPage()))),
          const Divider(height:1),
          ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('Advertentiefacturen'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage()))),
        ],
      ])),    ],
  );
}

class SearchPage extends StatefulWidget { const SearchPage({super.key}); @override State<SearchPage> createState()=>_SearchPageState(); }
class _SearchPageState extends State<SearchPage>{final c=TextEditingController();List<dynamic> results=[];bool busy=false;Future<void> go()async{final q=c.text.trim();if(q.isEmpty)return;setState(()=>busy=true);try{final r=await http.get(Uri.parse('$site/wp-json/wp/v2/posts?search=${Uri.encodeQueryComponent(q)}&per_page=30&_embed=1'));if(r.statusCode==200)results=List<dynamic>.from(jsonDecode(r.body));}catch(_){}if(mounted)setState(()=>busy=false);}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const LogoMark(),backgroundColor:Colors.white,foregroundColor:navy),body:Column(children:[Padding(padding:const EdgeInsets.all(16),child:TextField(controller:c,textInputAction:TextInputAction.search,onSubmitted:(_)=>go(),decoration:InputDecoration(hintText:'Zoek nieuws op Voorne',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:go,icon:const Icon(Icons.arrow_forward))))),if(busy)const LinearProgressIndicator(),Expanded(child:ListView.builder(itemCount:results.length,itemBuilder:(context,i){final p=results[i];final title=(p['title']?['rendered']??'').toString().replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&#8211;','–').replaceAll('&amp;','&');return ListTile(leading:postImage(p).isEmpty?const Icon(Icons.article_outlined):Image.network(postImage(p),width:72,height:54,fit:BoxFit.cover),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text(formatPostDate(p)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ArticlePage(post:p))));}))]));}


// ignore: unused_element
class NativeInfoPage extends StatelessWidget { final String title,text; final IconData icon; const NativeInfoPage({super.key,required this.title,required this.icon,required this.text}); @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title),backgroundColor:Colors.white,foregroundColor:navy),body:Padding(padding:const EdgeInsets.all(22),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:42,color:cyan),const SizedBox(height:16),Text(title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:10),Text(text,style:const TextStyle(fontSize:16,height:1.5))]))))); }



Future<Map<String,String>> authHeaders() async { final t=await const FlutterSecureStorage().read(key:'rvaz_token'); return {'Accept':'application/json',if(t!=null&&t.isNotEmpty)'Authorization':'Bearer $t'}; }
class SavedPage extends StatefulWidget{const SavedPage({super.key});@override State<SavedPage> createState()=>_SavedPageState();}class _SavedPageState extends State<SavedPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/saved'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Opgeslagen artikelen')),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Nog geen opgeslagen artikelen.')):ListView(children:x.map((e)=>ListTile(title:Text('${e['title']}'))).toList());}));}
class ContributionsPage extends StatefulWidget{const ContributionsPage({super.key});@override State<ContributionsPage> createState()=>_ContributionsPageState();}class _ContributionsPageState extends State<ContributionsPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/contributions'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Mijn bijdragen')),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Je hebt nog geen bijdragen.')):ListView(children:x.map((e)=>ListTile(title:Text('${e['title']}'),subtitle:Text('${e['status']} · ${e['type']}'))).toList());}));}
class TipPage extends StatefulWidget{const TipPage({super.key});@override State<TipPage> createState()=>_TipPageState();}class _TipPageState extends State<TipPage>{final subject=TextEditingController(),place=TextEditingController(),body=TextEditingController();bool busy=false;Future<void>send()async{setState(()=>busy=true);final h=await authHeaders();h['Content-Type']='application/json';final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/tip'),headers:h,body:jsonEncode({'subject':subject.text,'place':place.text,'text':body.text}));if(!mounted)return;setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r.statusCode==200?'Tip is naar de redactie gestuurd.':'Kon tip niet versturen. Log in en probeer opnieuw.')));if(r.statusCode==200)Navigator.pop(context);}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Tip de redactie')),body:ListView(padding:const EdgeInsets.all(18),children:[TextField(controller:subject,decoration:const InputDecoration(labelText:'Onderwerp')),TextField(controller:place,decoration:const InputDecoration(labelText:'Plaats')),const SizedBox(height:12),TextField(controller:body,minLines:8,maxLines:14,decoration:const InputDecoration(labelText:'Vertel ons wat er speelt',border:OutlineInputBorder())),const SizedBox(height:16),FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.send),label:Text(busy?'Versturen…':'Verstuur naar redactie'))]));}
class InAppWebPage extends StatelessWidget{final String title,url;const InAppWebPage({super.key,required this.title,required this.url});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(title)),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.ads_click,size:44,color:navy),const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:10),const Text('Advertentielink. Je verlaat de app alleen wanneer je hieronder kiest om de bestemming te openen.'),const SizedBox(height:16),FilledButton(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),child:const Text('Open bestemming'))]))));}


class EventDetailPage extends StatelessWidget{final dynamic event;const EventDetailPage({super.key,required this.event});String v(List<String> keys){for(final k in keys){final x=event[k];if(x!=null&&'$x'.trim().isNotEmpty)return '$x';}return'';}String title(){final x=event['title'];return x is Map?'${x['rendered']??''}':'${x??''}';}String category(){final x=event['category']??event['categories']??event['event_category'];if(x is List)return x.map((e)=>e is Map?(e['name']??e['title']??''):'$e').where((e)=>'$e'.isNotEmpty).join(', ');if(x is Map)return '${x['name']??x['title']??''}';return x?.toString()??'';}String address(){final full=v(['full_address','address']);if(full.isNotEmpty)return full;final street=v(['street','straat','location']),nr=v(['house_number','number','huisnummer']),zip=v(['postcode','postal_code']),city=v(['place','city','town','plaats']);final first=[street,nr].where((x)=>x.isNotEmpty).join(' '),second=[zip,city].where((x)=>x.isNotEmpty).join(' ');return[first,second].where((x)=>x.isNotEmpty).join('\n');}
@override Widget build(BuildContext context){final image=v(['image','featured_image']),html=v(['content','description']),venue=v(['venue','location_name']),addr=address(),cat=category();return Scaffold(appBar:AppBar(backgroundColor:Colors.white,foregroundColor:navy,title:const LogoMark()),body:ListView(children:[if(image.isNotEmpty)Image.network(image,height:230,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('AGENDA',style:TextStyle(color:cyan,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(title(),style:const TextStyle(fontSize:28,height:1.1,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:16),if(v(['display_date','start_date','date']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month,color:navy),title:Text(v(['display_date','start_date','date'])),subtitle:v(['time','start_time']).isNotEmpty?Text(v(['time','start_time'])):null),if(cat.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.category_outlined,color:navy),title:Text(cat)),if(venue.isNotEmpty||addr.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined,color:navy),title:Text(venue.isNotEmpty?venue:addr),subtitle:venue.isNotEmpty&&addr.isNotEmpty?Text(addr):null),if(v(['organizer','organisation','organisatie']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.groups_outlined,color:navy),title:Text(v(['organizer','organisation','organisatie']))),if(v(['price','kosten']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.euro_outlined,color:navy),title:Text(v(['price','kosten']))),const Divider(height:28),if(html.isNotEmpty)Html(data:html,style:{'body':Style(fontSize:FontSize(16),lineHeight:const LineHeight(1.5),margin:Margins.zero)}),if(html.isEmpty&&v(['excerpt']).isNotEmpty)Text(v(['excerpt']),style:const TextStyle(fontSize:16,height:1.5))]))]));}}


class MyAdsPage extends StatefulWidget{const MyAdsPage({super.key});@override State<MyAdsPage> createState()=>_MyAdsPageState();}
class _MyAdsPageState extends State<MyAdsPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/my-ads'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Mijn advertenties'),backgroundColor:Colors.white,foregroundColor:navy),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Je hebt nog geen advertentiecampagnes.')):ListView(padding:const EdgeInsets.all(16),children:x.map((e)=>Card(child:ListTile(title:Text('${e['title']}',style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text('${e['approved']==true?'Actief':'Wacht op goedkeuring'} · ${e['channel']}\nWebsite: ${e['web_impressions']} vertoningen / ${e['web_clicks']} klikken\nApp: ${e['app_impressions']} vertoningen / ${e['app_clicks']} klikken')))).toList());}));}
class InvoicesPage extends StatefulWidget{const InvoicesPage({super.key});@override State<InvoicesPage> createState()=>_InvoicesPageState();}
class _InvoicesPageState extends State<InvoicesPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/invoices'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Facturen'),backgroundColor:Colors.white,foregroundColor:navy),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Nog geen facturen.')):ListView(padding:const EdgeInsets.all(16),children:x.map((e)=>Card(child:ListTile(leading:const Icon(Icons.receipt_long,color:navy),title:Text('${e['number']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${e['date']}'),trailing:Text('€ ${e['total']}',style:const TextStyle(fontWeight:FontWeight.w900,color:navy))))).toList());}));}

class ProfilePage extends StatelessWidget{final Map<String,dynamic> user;const ProfilePage({super.key,required this.user});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Mijn profiel'),backgroundColor:Colors.white,foregroundColor:navy),body:ListView(padding:const EdgeInsets.all(18),children:[Card(child:Column(children:[ListTile(leading:const Icon(Icons.person),title:Text(user['name']?.toString()??''),subtitle:const Text('Naam')),const Divider(height:1),ListTile(leading:const Icon(Icons.email_outlined),title:Text(user['email']?.toString()??''),subtitle:const Text('E-mailadres')),if((user['place']?.toString()??'').isNotEmpty)...[const Divider(height:1),ListTile(leading:const Icon(Icons.location_on_outlined),title:Text(user['place'].toString()),subtitle:const Text('Woonplaats'))]]))]));}
class NotificationPreferencesPage extends StatefulWidget{const NotificationPreferencesPage({super.key});@override State<NotificationPreferencesPage> createState()=>_NotificationPreferencesPageState();}
class _NotificationPreferencesPageState extends State<NotificationPreferencesPage>{Map<String,bool> p={'breaking':true,'news':true,'emergency112':true,'traffic':true,'agenda':true,'weekblad':true};bool busy=true;@override void initState(){super.initState();load();}Future<void>load()async{try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/preferences'),headers:await authHeaders());if(r.statusCode==200){final d=Map<String,dynamic>.from(jsonDecode(r.body));for(final k in p.keys)if(d.containsKey(k))p[k]=d[k]==true;}}catch(_){}if(mounted)setState(()=>busy=false);}Future<void>save(String k,bool v)async{setState(()=>p[k]=v);try{await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/preferences'),headers:{...(await authHeaders()),'Content-Type':'application/json'},body:jsonEncode(p));final m=FirebaseMessaging.instance;final topic=k=='emergency112'?'112':k;if(v){await m.subscribeToTopic(topic);}else{await m.unsubscribeFromTopic(topic);}}catch(_){}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Meldingen'),backgroundColor:Colors.white,foregroundColor:navy),body:busy?const Center(child:CircularProgressIndicator()):ListView(children:[for(final e in {'breaking':'Breaking nieuws','news':'Nieuws','emergency112':'112 & veiligheid','traffic':'Verkeer','agenda':'Agenda','weekblad':'Weekblad'}.entries)SwitchListTile(value:p[e.key]??true,onChanged:(v)=>save(e.key,v),title:Text(e.value))]));}
