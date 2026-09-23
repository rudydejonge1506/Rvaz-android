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

class RvazApi {
  static const base = '$site/wp-json/rvaz-app/v1';
  static Future<dynamic> get(String path, {Map<String,String>? query}) async {
    final uri=Uri.parse('$base/$path').replace(queryParameters: query);
    final r=await http.get(uri,headers:const {'Accept':'application/json'}).timeout(const Duration(seconds:15));
    if(r.statusCode<200||r.statusCode>=300) throw Exception('API $path: HTTP ${r.statusCode}');
    if(r.body.trim().isEmpty) return null;
    return jsonDecode(r.body);
  }
  static List<dynamic> list(dynamic d,[List<String> keys=const []]){
    if(d is List)return List<dynamic>.from(d);
    if(d is Map){
      for(final k in [...keys,'items','data','results']){
        final v=d[k];
        if(v is List)return List<dynamic>.from(v);
        if(v is Map){
          for(final nk in ['items','data','results']){
            if(v[nk] is List)return List<dynamic>.from(v[nk]);
          }
        }
      }
    }
    return <dynamic>[];
  }
  static Future<List<dynamic>> firstList(List<String> paths,{List<String> keys=const []}) async {
    Object? last;
    for(final p in paths){
      try{
        final parts=p.split('?');
        Map<String,String>? q;
        if(parts.length>1){q=Uri.splitQueryString(parts.sublist(1).join('?'));}
        final x=list(await get(parts.first,query:q),keys);
        if(x.isNotEmpty)return x;
      }catch(e){last=e;}
    }
    if(last!=null) debugPrint('RVAZ API: $last');
    return <dynamic>[];
  }
}

final navigatorKey = GlobalKey<NavigatorState>();

class AppConfig {
  final String logoUrl, homeHeroUrl, homeIntro, breakingBanner, homeTitle, latestTitle, agendaTitle, weekbladTitle, accountTitle;
  final List<String> places, navOrder, homeBlocks, accountBlocks;
  final Map<String,bool> navigation, features;
  final Map<String,dynamic> limits;
  final Color primary, accent, success, background;
  const AppConfig({
    this.logoUrl='', this.homeHeroUrl='', this.homeIntro='Actueel nieuws van Regio Voorne aan Zee.', this.breakingBanner='',
    this.homeTitle='Regio Voorne aan Zee', this.latestTitle='Laatste nieuws', this.agendaTitle='Agenda',
    this.weekbladTitle='Weekblad', this.accountTitle='Mijn RVAZ',
    this.places=const ['Voorne aan Zee','Hellevoetsluis','Brielle','Rockanje','Oostvoorne','Oudenhoorn'],
    this.navOrder=const ['home','news','weekblad','agenda','account'],
    this.homeBlocks=const ['news','agenda','weekblad','ads'],
    this.accountBlocks=const ['saved','notifications','tips','contributions','weekblad','profile'],
    this.navigation=const {'home':true,'news':true,'weekblad':true,'agenda':true,'account':true},
    this.features=const {'search':true,'saved':true,'tips':true,'contributions':true,'push':true,'share':true,'listen':false,'traffic':true,'emergency112':true},
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
      logoUrl:(j['logo_url']??'').toString(), homeHeroUrl:(j['home_hero_url']??'').toString(), homeIntro:(j['home_intro']??'Actueel nieuws van Regio Voorne aan Zee.').toString(),
      breakingBanner:(j['breaking_banner']??'').toString(),
      homeTitle:(texts['home_title']??'Regio Voorne aan Zee').toString(), latestTitle:(texts['latest_title']??'Laatste nieuws').toString(),
      agendaTitle:(texts['agenda_title']??'Agenda').toString(), weekbladTitle:(texts['weekblad_title']??'Weekblad').toString(),
      accountTitle:(texts['account_title']??'Mijn RVAZ').toString(),
      places:list(j['places'],const ['Voorne aan Zee','Hellevoetsluis','Brielle','Rockanje','Oostvoorne','Oudenhoorn']),
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
  try {
    final settings = await m.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await m.getToken();
    if (token == null || token.isEmpty) return;
    final headers = <String,String>{'Content-Type':'application/json','Accept':'application/json'};
    try {
      final auth = await authHeaders();
      if (auth['Authorization']?.isNotEmpty == true) headers['Authorization'] = auth['Authorization']!;
    } catch (_) {}
    final p2000OptIn=(await const FlutterSecureStorage().read(key:'rvaz_push_112'))=='1';
    final topics=<String>['all','breaking','hellevoetsluis','brielle','rockanje','oostvoorne','verkeer','agenda','weekblad'];if(p2000OptIn)topics.add('112');
    final payload = jsonEncode({'token':token,'device_token':token,'fcm_token':token,'platform':'android','topics':topics});
    for (final endpoint in ['device']) {
      try {
        final r = await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/$endpoint'),headers:headers,body:payload).timeout(const Duration(seconds:8));
        if (r.statusCode >= 200 && r.statusCode < 300) return;
      } catch (_) {}
    }
  } catch (_) {}
}


Future<void> testPushOnThisDevice(BuildContext context) async {
  try {
    final token=await FirebaseMessaging.instance.getToken();
    if(token==null||token.isEmpty){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen Firebase-token op dit toestel.')));return;}
    await registerDeviceToken();
    final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/push-test'),headers:{'Content-Type':'application/json','Accept':'application/json'},body:jsonEncode({'token':token})).timeout(const Duration(seconds:15));
    if(!context.mounted)return;
    String msg=r.statusCode>=200&&r.statusCode<300?'Testmelding is naar dit toestel verstuurd.':'Push-test mislukt (${r.statusCode}). Controleer Firebase in RVAZ App.';
    try{final d=jsonDecode(r.body);if(d is Map&&d['message']!=null)msg=d['message'].toString();}catch(_){}
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
  }catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Push-test kon niet worden uitgevoerd.')));}
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
  final permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
  if (permission.authorizationStatus != AuthorizationStatus.denied) {
    for (final topic in ['all','breaking','hellevoetsluis','brielle','rockanje','oostvoorne','verkeer','agenda','weekblad']) {
      try { await messaging.subscribeToTopic(topic); } catch (_) {}
    }
    await registerDeviceToken();
  }
  messaging.onTokenRefresh.listen((_) async { await registerDeviceToken(); });
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
          scaffoldBackgroundColor: const Color(0xFFF4F7FA),
          fontFamily: 'Roboto',
          cardTheme: const CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            backgroundColor: Colors.white,
            foregroundColor: navy,
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 68,
            backgroundColor: Colors.white,
            indicatorColor: cyan.withValues(alpha:.14),
            labelTextStyle: WidgetStateProperty.resolveWith((s)=>TextStyle(
              fontSize: 11,
              fontWeight: s.contains(WidgetState.selected)?FontWeight.w800:FontWeight.w600,
              color: navy,
            )),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFDDE5EC))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFDDE5EC))),
          ),
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
    'emergency': EmergencyTrafficPage(),
    'agenda': AgendaPage(),
    'account': AccountPage(),
  };
  static const iconMap = <String,IconData>{
    'home':Icons.home_outlined,'news':Icons.article_outlined,'emergency':Icons.warning_amber_rounded,'agenda':Icons.event_outlined,'account':Icons.more_horiz,
  };
  static const labelMap = <String,String>{'home':'Home','news':'Nieuws','emergency':'112','agenda':'Agenda','account':'Mijn RVAZ'};

  @override
  Widget build(BuildContext context) {
    final keys=<String>['home','news','emergency','agenda','account'];
    if(index>=keys.length) index=0;
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: appConfig.primary,
        title: const Row(children: [Expanded(child: LogoMark())]),
        actions: [
          PageFeedbackButton(page: labelMap[keys[index]] ?? keys[index]),
          if(appConfig.feature('search')) IconButton(tooltip:'Zoeken',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const SearchPage())),icon:const Icon(Icons.search)),
          if(appConfig.feature('push') && keys.contains('account')) IconButton(tooltip:'Mijn RVAZ',onPressed:()=>setState(()=>index=keys.indexOf('account')),icon:const Icon(Icons.person_outline)),
        ],
      ),
      body: ColoredBox(color: const Color(0xFFF7F9FB), child: pageMap[keys[index]]!),
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

  static String _pick(Map j, List<String> keys) {
    for (final key in keys) {
      final value = j[key];
      if (value == null) continue;
      if (value is Map) {
        final nested = value['url'] ?? value['src'] ?? value['rendered'];
        if (nested != null && '$nested'.trim().isNotEmpty) return '$nested'.trim();
      } else if ('$value'.trim().isNotEmpty) {
        return '$value'.trim();
      }
    }
    return '';
  }

  factory AppAd.fromJson(dynamic raw) {
    final j = raw is Map ? Map<String,dynamic>.from(raw) : <String,dynamic>{};
    return AppAd(
      int.tryParse(_pick(j, ['id','ID','ad_id','campaign_id'])) ?? 0,
      _pick(j, ['title','name','campaign','advertiser','company']).isEmpty ? 'Advertentie' : _pick(j, ['title','name','campaign','advertiser','company']),
      _pick(j, ['image','image_url','creative_url','banner','banner_url','mobile_image','thumbnail','creative']),
      _pick(j, ['url','link','target_url','click_url','website','destination']),
      _pick(j, ['label','type']).isEmpty ? 'Advertentie' : _pick(j, ['label','type']),
    );
  }
}

List<dynamic> _adList(dynamic decoded) {
  dynamic raw = decoded;
  if (decoded is Map) {
    for (final key in ['ads','items','data','results','advertisements','campaigns']) {
      if (decoded[key] != null) { raw = decoded[key]; break; }
    }
    if (raw is Map) {
      for (final key in ['ads','items','data','results']) {
        if (raw[key] is List) { raw = raw[key]; break; }
      }
      if (raw is Map) raw = raw.values.toList();
    }
  }
  return raw is List ? raw : <dynamic>[];
}

Future<List<AppAd>> loadAppAds({String placement = 'news_feed'}) async {
  // The WordPress advertising plugin marks campaigns for the app. Ask the
  // canonical app endpoint first and accept the plugin's common wrappers.
  final aliases=<String>{placement, if(placement=='news_feed') 'news', 'app'};
  for(final p in aliases){
    try{
      final d=await RvazApi.get('ads',query:{'placement':p,'channel':'app'});
      final ads=_adList(d).map(AppAd.fromJson).where((a)=>a.image.isNotEmpty||a.url.isNotEmpty).toList();
      if(ads.isNotEmpty)return ads;
    }catch(_){}
  }
  // Compatibility with the installed advertising plugin while older API
  // versions are still present.
  for(final root in ['rvaz-ads/v1/ads','rvaz/v1/app-ads']){
    for(final p in aliases){
      try{
        final r=await http.get(Uri.parse('$site/wp-json/$root?placement=${Uri.encodeQueryComponent(p)}&channel=app'),headers:const {'Accept':'application/json'}).timeout(const Duration(seconds:10));
        if(r.statusCode>=200&&r.statusCode<300){
          final ads=_adList(jsonDecode(r.body)).map(AppAd.fromJson).where((a)=>a.image.isNotEmpty||a.url.isNotEmpty).toList();
          if(ads.isNotEmpty)return ads;
        }
      }catch(_){}
    }
  }
  return <AppAd>[];
}
Future<void> trackAd(int id, String type) async { if(id<=0)return; try { await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/ad-event'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'id':id,'type':type})); } catch (_) {} }

class AppAdCard extends StatefulWidget {
  final AppAd ad;
  const AppAdCard({super.key, required this.ad});
  @override State<AppAdCard> createState()=>_AppAdCardState();
}
class _AppAdCardState extends State<AppAdCard> {
  bool sent=false;
  @override void didChangeDependencies(){super.didChangeDependencies();if(!sent){sent=true;trackAd(widget.ad.id,'impression');}}
  @override
  Widget build(BuildContext context) {
    final ad=widget.ad;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ad.url.isEmpty ? null : () async {
          await trackAd(ad.id,'click');
          if(context.mounted) Navigator.of(context).push(MaterialPageRoute(builder:(_)=>InAppWebPage(title:ad.title,url:ad.url)));
        },
        child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(ad.image.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: Image.network(ad.image,width:double.infinity,height:110,fit:BoxFit.contain,
                errorBuilder:(_,__,___)=>const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12,8,12,10),
            child: Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(ad.label.toUpperCase(),style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900,color:Colors.black54)),
                const SizedBox(height:2),
                Text(ad.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,height:1.15,fontWeight:FontWeight.w800,color:navy)),
              ])),
              if(ad.url.isNotEmpty) const Padding(padding:EdgeInsets.only(left:8),child:Icon(Icons.open_in_new,size:17,color:navy)),
            ]),
          ),
        ]),
      ),
    );
  }
}

String cleanArticleHtml(String html) {
  var out = html;
  final markers = <String>['voorlees','responsivevoice','text-to-speech','tts-control'];
  for (final marker in markers) {
    out = out.replaceAll(RegExp('<[^>]*(?:class|id)=[^>]*$marker[^>]*>.*?</(?:div|section|aside|button)>', caseSensitive: false, dotAll: true), '');
  }
  // Strip inline desktop layout styles so WordPress content always fits mobile width.
  out = out.replaceAll(RegExp(r'''\sstyle=("[^"]*"|'[^']*')''', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'<(?:script|style|iframe|form)[^>]*>.*?</(?:script|style|iframe|form)>', caseSensitive: false, dotAll: true), '');
  out = out.replaceAll(RegExp(r'''\s(?:width|height|align|cellpadding|cellspacing)=("[^"]*"|'[^']*'|[^\s>]+)''', caseSensitive:false), '');
  out = out.replaceAll(RegExp(r'<\/?(?:main|article|section)[^>]*>',caseSensitive:false),'');
  return out;
}
Future<void> sendPageFeedback(BuildContext context, String page, {String? detail}) async {
  final controller=TextEditingController();
  final send=await showDialog<bool>(
    context: context,
    builder:(d)=>AlertDialog(
      title:const Text('Feedback voor de app'),
      content:TextField(controller:controller,minLines:5,maxLines:10,autofocus:true,decoration:InputDecoration(hintText:'Wat werkt goed of wat kunnen we verbeteren op $page?')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Annuleren')),
        FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Versturen')),
      ],
    ),
  );
  if(send!=true||controller.text.trim().isEmpty)return;
  try{
    final h=await authHeaders();h['Content-Type']='application/json';
    final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/feedback'),headers:h,body:jsonEncode({'page':page,'detail':detail??'','text':controller.text.trim()}));
    if(!context.mounted)return;
    if(r.statusCode>=200&&r.statusCode<300){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bedankt! Je feedback is naar de redactie gestuurd.')));
    }else if(r.statusCode==401){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Log eerst in bij Mijn RVAZ om feedback te sturen.')));
    }else{
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Feedback kon niet worden verstuurd. Probeer opnieuw.')));
    }
  }catch(_){
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding. Feedback is niet verstuurd.')));
  }
}

class PageFeedbackButton extends StatelessWidget { final String page; final String? detail; const PageFeedbackButton({super.key, required this.page, this.detail}); @override Widget build(BuildContext context)=>IconButton(tooltip:'Feedback over deze pagina',icon:const Icon(Icons.feedback_outlined),onPressed:()=>sendPageFeedback(context,page,detail:detail)); }
const defaultRVAZHero = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/cb/Vuurtoren_Hellevoetsluis_%2846736809815%29.jpg/1280px-Vuurtoren_Hellevoetsluis_%2846736809815%29.jpg';

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
  final direct = p['image']?.toString() ?? '';
  if (direct.isNotEmpty) return direct;
  try {
    final media = p['_embedded']?['wp:featuredmedia'];
    if (media is List && media.isNotEmpty) {
      return media.first['source_url']?.toString() ?? '';
    }
  } catch (_) {}
  return '';
}

bool postRequiresLogin(dynamic p){
  if(p is! Map)return false;
  bool yes(dynamic v){final x='${v??''}'.toLowerCase().trim();return v==true||v==1||['1','true','yes','ja','logged_in','members','member','login','required','private'].contains(x);}
  for(final k in ['requires_login','login_required','members_only','member_only','logged_in_only','restricted','rvaz_login_required','_rvaz_login_required']){if(yes(p[k]))return true;}
  final meta=p['meta'];if(meta is Map){for(final k in ['requires_login','login_required','members_only','member_only','rvaz_login_required','_rvaz_login_required']){if(yes(meta[k]))return true;}}
  return false;
}
Future<bool> appLoggedIn() async => (await const FlutterSecureStorage().read(key:'rvaz_token'))?.isNotEmpty==true;

Future<void> _showLoginRequired(BuildContext context) async {
  if(!context.mounted)return;
  await showDialog(context:context,builder:(d)=>AlertDialog(
    title:const Text('Alleen voor ingelogde gebruikers'),
    content:const Text('Log in bij Mijn RVAZ om dit artikel te lezen.'),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Sluiten')),
      FilledButton(onPressed:(){Navigator.pop(d);Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountLoginPage()));},child:const Text('Inloggen')),
    ],
  ));
}

Future<void> openArticle(BuildContext context,dynamic post) async {
  final id=int.tryParse('${post is Map ? post['id'] ?? '' : ''}');
  final headers=await authHeaders();

  // The app API is authoritative for access control. Never trust the public
  // WordPress post response to decide whether a members-only article may open.
  if(id!=null){
    try{
      final r=await http.get(
        Uri.parse('$site/wp-json/rvaz-app/v1/posts/$id'),
        headers:headers,
      ).timeout(const Duration(seconds:12));
      if(r.statusCode==401||r.statusCode==403){
        if(context.mounted)await _showLoginRequired(context);
        return;
      }
      if(r.statusCode>=200&&r.statusCode<300&&r.body.trim().isNotEmpty){
        final canonical=jsonDecode(r.body);
        final resolved=canonical is Map && canonical['post'] is Map ? canonical['post'] : canonical;
        if(postRequiresLogin(resolved) && !headers.containsKey('Authorization')){
          if(context.mounted)await _showLoginRequired(context);
          return;
        }
        if(context.mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>ArticlePage(post:resolved)));
        return;
      }
    }catch(_){}
  }

  // Local metadata remains a safety net when an older API does not expose
  // the detail endpoint yet.
  if(postRequiresLogin(post) && !headers.containsKey('Authorization')){
    if(context.mounted)await _showLoginRequired(context);
    return;
  }
  if(context.mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>ArticlePage(post:post)));
}

Future<bool> saveArticle(dynamic post) async {
  final id = int.tryParse('${post['id'] ?? ''}');
  if (id == null) return false;
  final headers = await authHeaders();
  if (!headers.containsKey('Authorization')) return false;
  headers['Content-Type'] = 'application/json';
  for (final body in [
    {'post_id': id},
    {'id': id},
  ]) {
    try {
      final r = await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/saved'), headers: headers, body: jsonEncode(body));
      if (r.statusCode >= 200 && r.statusCode < 300) return true;
    } catch (_) {}
  }
  return false;
}

class ArticlePage extends StatefulWidget {
  final dynamic post;
  const ArticlePage({super.key, required this.post});
  @override State<ArticlePage> createState()=>_ArticlePageState();
}
class _ArticlePageState extends State<ArticlePage>{
  dynamic post;
  bool loading=false, denied=false;
  @override void initState(){super.initState();post=widget.post;_loadProtected();}
  Future<void> _loadProtected() async {
    if(!postRequiresLogin(post))return;
    final token=await const FlutterSecureStorage().read(key:'rvaz_token');
    if(token==null||token.isEmpty){if(mounted)setState(()=>denied=true);return;}
    final id=int.tryParse('${post['id']??''}');if(id==null)return;
    setState(()=>loading=true);
    try{
      final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/posts/$id'),headers:{'Authorization':'Bearer $token','Accept':'application/json'}).timeout(const Duration(seconds:12));
      if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body);if(d is Map)post=d['post']??d;}
      else if(r.statusCode==401||r.statusCode==403){denied=true;}
    }catch(_){}
    if(mounted)setState(()=>loading=false);
  }

  String clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8211;', '–');

  @override
  Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(denied)return Scaffold(appBar:AppBar(title:const Text('Regio Voorne aan Zee')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:48,color:navy),const SizedBox(height:14),const Text('Alleen voor ingelogde gebruikers',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:8),const Text('Log in bij Mijn RVAZ om dit artikel te lezen.',textAlign:TextAlign.center),const SizedBox(height:16),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountLoginPage())),child:const Text('Inloggen'))]))));
    final image = postImage(post);
    final rawTitle = post['title'];
    final rawContent = post['content'];
    final title = clean(rawTitle is Map ? '${rawTitle['rendered'] ?? ''}' : '${rawTitle ?? ''}');
    final bodyHtml = cleanArticleHtml(rawContent is Map ? '${rawContent['rendered'] ?? ''}' : '${rawContent ?? post['excerpt'] ?? ''}');
    final articleAds = loadAppAds(placement:'article');
    final blocks=bodyHtml.split(RegExp(r'(?<=</p>)',caseSensitive:false)).where((x)=>x.trim().isNotEmpty).toList();
    final cut=blocks.length>2?(blocks.length/2).ceil():blocks.length;
    final firstHtml=blocks.take(cut).join();
    final secondHtml=blocks.skip(cut).join();
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Regio Voorne aan Zee',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Artikel bewaren',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              final ok = await saveArticle(post);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                ok ? 'Artikel opgeslagen bij Mijn RVAZ.' : 'Opslaan lukt alleen wanneer je bent ingelogd.'
              )));
            },
          ),
          PageFeedbackButton(page: 'Nieuwsartikel', detail: title),
        ],
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
                SizedBox(width:double.infinity,child:Html(data:firstHtml,style:{'body':Style(margin:Margins.zero,padding:HtmlPaddings.zero,fontSize:FontSize(17),lineHeight:LineHeight(1.55),color:const Color(0xFF202A33)),'h1':Style(fontSize:FontSize(28),fontWeight:FontWeight.w900,color:navy),'h2':Style(fontSize:FontSize(24),fontWeight:FontWeight.w900,color:navy),'h3':Style(fontSize:FontSize(20),fontWeight:FontWeight.w800,color:navy)})),
                const SizedBox(height: 12),
                FutureBuilder<List<AppAd>>(future:articleAds,builder:(context,s){final a=s.data??[];return a.isEmpty?const SizedBox.shrink():AppAdCard(ad:a.first);}),
                if(secondHtml.trim().isNotEmpty) ...[
                  const SizedBox(height:12),
                  SizedBox(width:double.infinity,child:Html(data:secondHtml,style:{'body':Style(margin:Margins.zero,padding:HtmlPaddings.zero,fontSize:FontSize(17),lineHeight:LineHeight(1.55),color:const Color(0xFF202A33)),'h1':Style(fontSize:FontSize(28),fontWeight:FontWeight.w900,color:navy),'h2':Style(fontSize:FontSize(24),fontWeight:FontWeight.w900,color:navy),'h3':Style(fontSize:FontSize(20),fontWeight:FontWeight.w800,color:navy)})),
                ],
                const SizedBox(height: 18),
                FutureBuilder<List<AppAd>>(future:articleAds,builder:(context,s){final a=s.data??[];return a.length<2?const SizedBox.shrink():AppAdCard(ad:a[1]);}),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () { final link='${post['link'] ?? post['url'] ?? ''}'; if(link.isNotEmpty) launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication); },
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

class StandaloneAppPage extends StatelessWidget {\n  final String title; final Widget child;\n  const StandaloneAppPage({super.key,required this.title,required this.child});\n  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(backgroundColor:Colors.white,foregroundColor:navy,title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800))),body:ColoredBox(color:const Color(0xFFF7F9FB),child:child));\n}\nclass AccountLoginPage extends StatelessWidget { const AccountLoginPage({super.key}); @override Widget build(BuildContext context)=>const StandaloneAppPage(title:'Inloggen bij Mijn RVAZ',child:AccountPage()); }\n\nclass HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage>{
  late Future<List<dynamic>> posts;
  late Future<List<dynamic>> events;
  late Future<List<AppAd>> ads;
  int visibleNews=8;
  @override void initState(){super.initState();_reload();}
  void _reload(){visibleNews=8;posts=_posts();events=_events();ads=loadAppAds(placement:'home');}
  Future<List<dynamic>> _posts() async {
    try{
      final r=await http.get(
        Uri.parse('$site/wp-json/rvaz-app/v1/posts?per_page=100'),
        headers:await authHeaders(),
      ).timeout(const Duration(seconds:15));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final x=RvazApi.list(d,const ['posts']);
        if(x.isNotEmpty)return x;
      }
    }catch(_){}
    return <dynamic>[];
  }
  Future<List<dynamic>> _events()=>RvazApi.firstList(['agenda?per_page=5','events?per_page=5'],keys:const ['events','agenda']);
  String clean(dynamic v)=>'$v'.replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&amp;','&').replaceAll('&#8211;','–');
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(_reload);await Future.wait([posts,events,ads]);},child:ListView(padding:EdgeInsets.zero,children:[
    Padding(
      padding: const EdgeInsets.fromLTRB(16,16,16,8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors:[Color(0xFF073B63),Color(0xFF0B6FA4)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Dichtbij op Voorne',style:TextStyle(color:Colors.white,fontSize:24,height:1.05,fontWeight:FontWeight.w900)),
            const SizedBox(height:7),
            Text('Jouw nieuws, 112, verkeer en agenda. Persoonlijk en direct.',style:TextStyle(color:Colors.white.withValues(alpha:.88),fontSize:14,height:1.35)),
          ])),
          const SizedBox(width:12),
          Container(width:52,height:52,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.13),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.location_on_outlined,color:Colors.white,size:28)),
        ]),
      ),
    ),
    Container(transform:Matrix4.translationValues(0,-12,0),padding:const EdgeInsets.symmetric(horizontal:14),child:GridView.count(crossAxisCount:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:8,crossAxisSpacing:8,childAspectRatio:1.25,children:[
      _HomeShortcut(icon:Icons.article_outlined,color:Colors.blue,label:'Nieuws',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const StandaloneAppPage(title:'Nieuws',child:NewsPage())))),
      _HomeShortcut(icon:Icons.warning_amber_rounded,color:Colors.red,label:'112 & Verkeer',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EmergencyTrafficPage()))),
      _HomeShortcut(icon:Icons.calendar_month,color:Colors.teal,label:'Agenda',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const StandaloneAppPage(title:'Agenda',child:AgendaPage())))),
      _HomeShortcut(icon:Icons.location_on,color:Colors.green,label:'Plaatsen',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PlacesPage()))),
      _HomeShortcut(icon:Icons.favorite,color:Colors.redAccent,label:'Favorieten',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountLoginPage()))),
      _HomeShortcut(icon:Icons.business,color:Colors.deepPurple,label:'Bedrijven',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessesPage()))),
    ])),
    Padding(padding:const EdgeInsets.fromLTRB(16,0,16,22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Laatste nieuws',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const StandaloneAppPage(title:'Nieuws',child:NewsPage()))),child:const Text('Meer →'))]),
      FutureBuilder<List<dynamic>>(future:posts,builder:(context,s){final all=s.data??[];if(all.isEmpty)return const SizedBox.shrink();final x=all.take(visibleNews).toList();final p=x.first;return Column(children:[
        Card(clipBehavior:Clip.antiAlias,margin:EdgeInsets.zero,child:InkWell(onTap:()=>openArticle(context,p),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(postImage(p).isNotEmpty)Image.network(postImage(p),height:175,width:double.infinity,fit:BoxFit.cover),
          Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(3)),child:const Text('NIEUWS',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))),const SizedBox(width:5),Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:cyan,borderRadius:BorderRadius.circular(3)),child:const Text('VOORNE AAN ZEE',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)))]),const SizedBox(height:7),Text(clean(p['title'] is Map?p['title']['rendered']:p['title']??''),style:const TextStyle(color:navy,fontSize:18,height:1.15,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(formatPostDate(p),style:const TextStyle(fontSize:10,color:Colors.black54))]))]))),
        const SizedBox(height:10),
        FutureBuilder<List<AppAd>>(future:ads,builder:(context,s){final a=s.data??[];return a.isEmpty?const SizedBox.shrink():Padding(padding:const EdgeInsets.only(bottom:8),child:AppAdCard(ad:a.first));}),
        const SizedBox.shrink(),
        const SizedBox(height:10),
        ...x.skip(1).map((p)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:4),leading:postImage(p).isEmpty?null:ClipRRect(borderRadius:BorderRadius.circular(4),child:Image.network(postImage(p),width:78,height:58,fit:BoxFit.cover)),title:Text(clean(p['title'] is Map?p['title']['rendered']:p['title']??''),maxLines:2,style:const TextStyle(fontWeight:FontWeight.w800,color:navy,fontSize:13)),trailing:const Icon(Icons.chevron_right,color:navy),onTap:()=>openArticle(context,p)))),
        if(visibleNews<all.length)Padding(
          padding:const EdgeInsets.only(top:8),
          child:OutlinedButton.icon(
            onPressed:()=>setState(()=>visibleNews=(visibleNews+8).clamp(1,all.length)),
            icon:const Icon(Icons.expand_more),
            label:const Text('Meer laden'),
          ),
        ),
      ]);}),
      
    ]))
  ]));
}
class _HomeShortcut extends StatelessWidget{
  final IconData icon;final Color color;final String label;final VoidCallback? onTap;
  const _HomeShortcut({required this.icon,required this.color,required this.label,this.onTap});
  @override Widget build(BuildContext context)=>Material(color:Colors.white,elevation:1,borderRadius:BorderRadius.circular(11),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(11),child:Padding(padding:const EdgeInsets.symmetric(vertical:10,horizontal:3),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color,size:26),const SizedBox(height:5),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:navy))]))));
}

class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key});
  @override Widget build(BuildContext context) {
    final places=appConfig.places.where((x)=>x!='Voorne aan Zee').toList();
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),
      appBar: AppBar(title: const Text('Plaatsen'), backgroundColor: Colors.white, foregroundColor: navy),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Nieuws per plaats',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),
          const SizedBox(height:6),
          const Text('Kies een plaats om de bijbehorende nieuwsberichten te bekijken.'),
          const SizedBox(height:14),
          ...places.map((p)=>Card(
            margin:const EdgeInsets.only(bottom:10),
            child:ListTile(
              leading:const CircleAvatar(child:Icon(Icons.location_on_outlined)),
              title:Text(p,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),
              trailing:const Icon(Icons.chevron_right,color:navy),
              onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PlaceNewsPage(place:p))),
            ),
          )),
        ],
      ),
    );
  }
}

class PlaceNewsPage extends StatefulWidget {
  final String place;
  const PlaceNewsPage({super.key,required this.place});
  @override State<PlaceNewsPage> createState()=>_PlaceNewsPageState();
}
class _PlaceNewsPageState extends State<PlaceNewsPage> {
  late Future<List<dynamic>> future;
  @override void initState(){super.initState();future=load();}
  Future<List<dynamic>> load() async {
    final q=Uri.encodeQueryComponent(widget.place);
    final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/posts?place=$q&per_page=100'),headers:await authHeaders());
    if(r.statusCode!=200)return [];
    final d=jsonDecode(r.body);
    if(d is List)return List<dynamic>.from(d);
    if(d is Map){final raw=d['items']??d['posts']??d['data'];if(raw is List)return List<dynamic>.from(raw);}
    return [];
  }
  String clean(dynamic v)=>'$v'.replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&amp;','&').replaceAll('&#8211;','–');
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),
    appBar:AppBar(title:Text(widget.place),backgroundColor:Colors.white,foregroundColor:navy),
    body:FutureBuilder<List<dynamic>>(future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      final x=s.data??[];
      if(x.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Geen nieuwsberichten voor deze plaats gevonden.')));
      return RefreshIndicator(onRefresh:()async{setState(()=>future=load());await future;},child:ListView.builder(
        padding:const EdgeInsets.all(16),itemCount:x.length,itemBuilder:(context,i){final p=x[i];return Card(
          margin:const EdgeInsets.only(bottom:10),child:ListTile(
            contentPadding:const EdgeInsets.all(10),
            leading:postImage(p).isEmpty?const Icon(Icons.article_outlined):ClipRRect(borderRadius:BorderRadius.circular(6),child:Image.network(postImage(p),width:76,height:60,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.article_outlined))),
            title:Text(clean(p['title'] is Map ? (p['title']?['rendered']??'') : (p['title']??'')),style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),
            subtitle:Text(formatPostDate(p)),trailing:const Icon(Icons.chevron_right,color:navy),
            onTap:()=>openArticle(context,p),
          ));
        },
      ));
    }),
  );
}

class EmergencyTrafficPage extends StatefulWidget{const EmergencyTrafficPage({super.key});@override State<EmergencyTrafficPage> createState()=>_EmergencyTrafficPageState();}
class _EmergencyTrafficPageState extends State<EmergencyTrafficPage>{
 String place='Rotterdam-Rijnmond';bool traffic=false;late Future<List<dynamic>> items;
 static const p2000Places=['Rotterdam-Rijnmond','Hellevoetsluis','Rockanje','Brielle','Oostvoorne','Voorne aan Zee'];
 @override void initState(){super.initState();items=load();}
 String hay(dynamic e)=>[e is Map?e['title']:'',e is Map?e['description']:'',e is Map?e['message']:'',e is Map?e['body']:'',e is Map?e['place']:'',e is Map?e['location']:'',e is Map?e['city']:''].join(' ').toLowerCase();
 Future<List<dynamic>>load()async{
   final primary=await RvazApi.firstList(
     traffic?['traffic?per_page=250&place=${Uri.encodeQueryComponent(place)}','verkeer?per_page=250&place=${Uri.encodeQueryComponent(place)}']:['p2000?region=rotterdam-rijnmond&per_page=250&place=${Uri.encodeQueryComponent(place)}','112?region=rotterdam-rijnmond&per_page=250&place=${Uri.encodeQueryComponent(place)}','meldingen?region=rotterdam-rijnmond&per_page=250&place=${Uri.encodeQueryComponent(place)}'],
     keys:traffic?const ['traffic','verkeer','meldingen']:const ['meldingen','p2000','112','items','data'],
   );
   if(primary.isNotEmpty)return primary;
   if(!traffic){for(final type in ['rvaz_p2000','rvaz_112','p2000']){try{final r=await http.get(Uri.parse('$site/wp-json/wp/v2/$type?per_page=100&_embed=1')).timeout(const Duration(seconds:10));if(r.statusCode==200){final x=RvazApi.list(jsonDecode(r.body));if(x.isNotEmpty)return x;}}catch(_){}}}
   return <dynamic>[];
 }
 List<dynamic> filtered(List<dynamic> all){if(traffic||place=='Rotterdam-Rijnmond')return all;final q=place.toLowerCase();return all.where((e)=>hay(e).contains(q)).toList();}
 void refresh(){setState(()=>items=load());}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('112 & Verkeer'),backgroundColor:Colors.white,foregroundColor:navy,actions:[
   if(!traffic)IconButton(tooltip:'P2000 pushmeldingen',icon:const Icon(Icons.notifications_active_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationPreferencesPage()))),
   const PageFeedbackButton(page:'112 & Verkeer')
 ]),body:Column(children:[
   Padding(padding:const EdgeInsets.all(16),child:Column(children:[
     DropdownButtonFormField<String>(initialValue:place,decoration:InputDecoration(labelText:traffic?'Plaats':'P2000-regio / plaats',border:const OutlineInputBorder()),items:(traffic?['Rotterdam-Rijnmond',...appConfig.places.where((x)=>x!='Voorne aan Zee')]:p2000Places).map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){setState(()=>place=v??'Rotterdam-Rijnmond');refresh();}),
     const SizedBox(height:12),
     SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('112 / P2000'),icon:Icon(Icons.warning_amber)),ButtonSegment(value:true,label:Text('Verkeer'),icon:Icon(Icons.traffic))],selected:{traffic},onSelectionChanged:(v){setState(()=>traffic=v.first);refresh();})
   ])),
   Expanded(child:FutureBuilder<List<dynamic>>(future:items,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final x=filtered(s.data??[]);if(x.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(traffic?'Geen actuele verkeersmeldingen voor deze selectie.':'Geen P2000-meldingen gevonden in de aangeleverde Rijnmond-feed.')));return RefreshIndicator(onRefresh:()async{refresh();await items;},child:ListView.separated(padding:const EdgeInsets.fromLTRB(16,0,16,20),itemCount:x.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(c,i){final e=x[i];final title='${e['title']??e['message']??e['description']??'Melding'}';final date='${e['date']??e['datetime']??e['published']??''}';return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:5),leading:Icon(traffic?Icons.traffic:Icons.warning_amber_rounded,color:traffic?navy:Colors.red),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(date),trailing:const Icon(Icons.chevron_right),onTap:(){final u=e['link']?.toString()??e['url']?.toString()??'';if(u.isNotEmpty)launchUrl(Uri.parse(u),mode:LaunchMode.externalApplication);});}));}))
 ]));}

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
    final r=await http.get(
      Uri.parse('$site/wp-json/rvaz-app/v1/posts?per_page=$count'),
      headers:await authHeaders(),
    ).timeout(const Duration(seconds:15));
    if(r.statusCode!=200)throw Exception('Nieuws kon niet worden geladen');
    final d=jsonDecode(r.body);
    return RvazApi.list(d,const ['posts']);
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
                const SizedBox.shrink(),
                const SizedBox(height: 12),
                ...posts.asMap().entries.expand((entry) {
                  final p = entry.value;
                  final widgets = <Widget>[Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => openArticle(context,p),
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
                            Text(clean((p['title'] is Map?p['title']['rendered']:p['title']??'').toString()),
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
                            Text(clean((p['excerpt'] is Map?p['excerpt']['rendered']:p['excerpt']??'').toString()),
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
 late Future<List<dynamic>> future;late Future<List<AppAd>> ads;String place='Alle';
 @override void initState(){super.initState();future=load();ads=loadAppAds(placement:'agenda');}
 Future<List<dynamic>> load() async {
   final collected=<dynamic>[];
   final seen=<String>{};
   for(final path in [
     'agenda?per_page=250',
     'agenda?limit=250',
     'events?per_page=250',
     'events?limit=250',
   ]){
     try{
       final parts=path.split('?');
       final d=await RvazApi.get(parts.first,query:Uri.splitQueryString(parts[1]));
       for(final e in RvazApi.list(d,const ['events','agenda'])){
         final key=e is Map?'${e['id']??''}|${e['start_date']??e['date']??''}|${e['title']??''}':'$e';
         if(seen.add(key))collected.add(e);
       }
     }catch(_){}
   }
   return collected;
 }
 String val(dynamic p,List<String> k){for(final x in k){final z=p[x];if(z!=null&&'$z'.trim().isNotEmpty)return '$z';}return'';}
 String clean(dynamic v)=>'$v'.replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&amp;','&').replaceAll('&#8211;','–');
 String title(dynamic p){final t=p['title'];return clean(t is Map?t['rendered']:t??'');}
 String placeOf(dynamic p)=>val(p,['place','city','town','plaats','event_place']);
 DateTime? date(dynamic p)=>DateTime.tryParse(val(p,['start_date','event_start_date','event_date','start','date','datum','datetime']));
 @override Widget build(BuildContext context)=>ColoredBox(color:const Color(0xFFF7F9FB),child:FutureBuilder<List<dynamic>>(future:future,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final all=s.data??[];final places=<String>['Alle',...appConfig.places.where((x)=>x!='Voorne aan Zee')];final items=all.where((p){if(place=='Alle')return true;final hay=[placeOf(p),val(p,['location','venue','address','full_address']),title(p)].join(' ').toLowerCase();return hay.contains(place.toLowerCase());}).toList()..sort((a,b)=>(date(a)??DateTime(2100)).compareTo(date(b)??DateTime(2100)));return Column(children:[
   SizedBox(height:54,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.fromLTRB(14,9,14,7),itemCount:places.length,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(c,i){final x=places[i],on=x==place;return ChoiceChip(label:Text(x),selected:on,onSelected:(_)=>setState(()=>place=x),selectedColor:cyan,labelStyle:TextStyle(color:on?Colors.white:navy,fontSize:11,fontWeight:FontWeight.w700),side:BorderSide(color:on?cyan:const Color(0xFFDCE5ED)),showCheckmark:false); })),
   Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,20),children:[const Text('Aankomende evenementen',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:10),FutureBuilder<List<AppAd>>(future:ads,builder:(context,s){final a=s.data??[];return a.isEmpty?const SizedBox.shrink():AppAdCard(ad:a.first);}),if(items.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Geen evenementen gevonden.')),...items.map((p){final d=date(p);final day=d?.day.toString().padLeft(2,'0')??'--';const months=['','JAN','FEB','MRT','APR','MEI','JUN','JUL','AUG','SEP','OKT','NOV','DEC'];final mon=d==null?'':months[d.month];final img=val(p,['image','image_url','thumbnail']);return Card(margin:const EdgeInsets.only(bottom:8),child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDetailPage(event:p))),child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[SizedBox(width:42,child:Column(children:[Text(day,style:const TextStyle(color:navy,fontSize:20,fontWeight:FontWeight.w900)),Text(mon,style:const TextStyle(color:navy,fontSize:10,fontWeight:FontWeight.w900))])),if(img.isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(5),child:Image.network(img,width:72,height:58,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:72,height:58))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title(p),maxLines:2,style:const TextStyle(color:navy,fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text([val(p,['display_date','start_date','date']),val(p,['venue','location']),placeOf(p),val(p,['time','start_time'])].where((x)=>x.isNotEmpty).join('\n'),maxLines:3,style:const TextStyle(fontSize:10,height:1.25,color:Color(0xFF52687A)))])),const Icon(Icons.chevron_right,color:navy)])))) ;})]))
 ]);}));
}

class WeekbladPage extends StatefulWidget {
  const WeekbladPage({super.key});
  @override State<WeekbladPage> createState()=>_WeekbladPageState();
}
class _WeekbladPageState extends State<WeekbladPage> {
  late Future<List<dynamic>> future;
  late Future<List<AppAd>> ads;
  @override void initState(){super.initState();future=load();ads=loadAppAds(placement:'weekblad');}
  Future<List<dynamic>> load() => RvazApi.firstList(
    ['weekblad','issues'],
    keys: const ['issues','editions','weekblad'],
  );
  @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(future:future,builder:(context,s){
    if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    final issues=s.data??[];
    return ListView(padding:const EdgeInsets.all(18),children:[
      Text(appConfig.weekbladTitle,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:navy)),
      const Text('Weekblad Voorne aan Zee'),const SizedBox(height:18),FutureBuilder<List<AppAd>>(future:ads,builder:(context,s){final a=s.data??[];return a.isEmpty?const SizedBox.shrink():AppAdCard(ad:a.first);}),
      if(issues.isEmpty) Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Er zijn momenteel geen weekbladedities gevonden.'),const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse('$site/weekblad/'),mode:LaunchMode.externalApplication),icon:const Icon(Icons.open_in_new),label:const Text('Bekijk weekblad op de website'))]))),
      ...issues.map((x)=>Card(child:ListTile(leading:const Icon(Icons.menu_book,color:navy),title:Text('${x['title']??'Weekblad'}'.replaceAll('&#8211;','–').replaceAll('&amp;','&'),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${x['date']??''} · ${x['pages']??0} pagina’s'),trailing:const Icon(Icons.chevron_right),onTap:()=>launchUrl(Uri.parse('${x['pdf']}'),mode:LaunchMode.externalApplication))))
    ]);
  });
}

class AccountPage extends StatefulWidget { const AccountPage({super.key}); @override State<AccountPage> createState()=>_AccountPageState(); }
class _AccountPageState extends State<AccountPage>{
 String? userName; bool busy=false; bool advertiser=false; Map<String,dynamic> userInfo={};
 @override void initState(){super.initState();restore();}
 Future<void> restore()async{final t=await const FlutterSecureStorage().read(key:'rvaz_token');if(t==null)return;try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/me'),headers:{'Authorization':'Bearer $t'});if(r.statusCode==200){final d=jsonDecode(r.body);if(mounted)setState((){userInfo=Map<String,dynamic>.from(d['user']??{});userName=userInfo['name']?.toString();advertiser=userInfo['advertiser']==true;});}}catch(_){}}
 Future<void> auth(bool reg)async{final n=TextEditingController(),e=TextEditingController(),p=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(reg?'Account aanmaken':'Inloggen'),content:Column(mainAxisSize:MainAxisSize.min,children:[if(reg)TextField(controller:n,decoration:const InputDecoration(labelText:'Naam')),TextField(controller:e,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mailadres')),TextField(controller:p,obscureText:true,decoration:InputDecoration(labelText:'Wachtwoord',helperText:reg?'Minimaal 8 tekens':null))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Annuleren')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(reg?'Account aanmaken':'Inloggen'))]));if(ok!=true)return;if(reg&&(n.text.trim().isEmpty||p.text.length<8)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Naam en minimaal 8 tekens voor het wachtwoord zijn nodig.')));return;}setState(()=>busy=true);try{final body=reg?{'name':n.text.trim(),'email':e.text.trim(),'password':p.text}:{'login':e.text.trim(),'password':p.text};final endpoint=reg?'register':'login';final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/$endpoint'),headers:{'Content-Type':'application/json','Accept':'application/json'},body:jsonEncode(body));if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body),t=d['token']?.toString()??'';if(t.isNotEmpty)await const FlutterSecureStorage().write(key:'rvaz_token',value:t);if(mounted){final u=Map<String,dynamic>.from(d['user']??{});setState((){userInfo=u;userName=u['name']?.toString()??n.text.trim();advertiser=u['advertiser']==true;});}}else{String m='Inloggen of registreren mislukt.';try{m=jsonDecode(r.body)['message']?.toString()??m;}catch(_){}if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));}}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding met RVAZ.')));}if(mounted)setState(()=>busy=false);}
 Future<void> logout()async{final t=await const FlutterSecureStorage().read(key:'rvaz_token');if(t!=null){try{await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/logout'),headers:{'Authorization':'Bearer $t'});}catch(_){}}await const FlutterSecureStorage().delete(key:'rvaz_token');if(mounted)setState((){userName=null;advertiser=false;userInfo={};});}
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
      Card(child:Column(children:[
        ListTile(leading:const Icon(Icons.feedback_outlined),title:const Text('Feedback over de app'),subtitle:const Text('Meld een fout of geef een suggestie'),trailing:const Icon(Icons.chevron_right),onTap:()=>sendPageFeedback(context,'Algemene app-feedback')),
        const Divider(height:1),
        ListTile(leading:const Icon(Icons.notifications_active_outlined),title:const Text('Test pushmelding'),subtitle:const Text('Controleer WordPress → Firebase → deze telefoon'),trailing:const Icon(Icons.chevron_right),onTap:()=>testPushOnThisDevice(context)),
        const Divider(height:1),
        ListTile(leading:const Icon(Icons.campaign_outlined),title:const Text('Tip de redactie'),subtitle:Text(userName==null?'Log in om een tip te versturen':'Stuur nieuws rechtstreeks naar de redactie'),trailing:const Icon(Icons.chevron_right),onTap:()=>userName==null?auth(false):Navigator.push(context,MaterialPageRoute(builder:(_)=>const TipPage()))),
      ])),
      const SizedBox(height:14),
      if (userName != null) Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Mijn profiel'), subtitle: Text(userInfo['email']?.toString()??''), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user:userInfo)))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Meldingen'), subtitle: const Text('Kies welke pushmeldingen je ontvangt'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.bookmark_outline), title: const Text('Opgeslagen artikelen'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.article_outlined), title: const Text('Mijn bijdragen'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributionsPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Weekblad'), subtitle: const Text('Lees de nieuwste editie'), trailing: const Icon(Icons.chevron_right), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WeekbladPage()))),
        const Divider(height:1),
        ListTile(leading: const Icon(Icons.help_outline), title: const Text('Contact & hulp'), trailing: const Icon(Icons.open_in_new), onTap:()=>launchUrl(Uri.parse('$site/contact/'),mode:LaunchMode.externalApplication)),
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
class _SearchPageState extends State<SearchPage>{final c=TextEditingController();List<dynamic> results=[];bool busy=false;Future<void> go()async{final q=c.text.trim();if(q.isEmpty)return;setState(()=>busy=true);try{final r=await http.get(Uri.parse('$site/wp-json/wp/v2/posts?search=${Uri.encodeQueryComponent(q)}&per_page=30&_embed=1'));if(r.statusCode==200)results=List<dynamic>.from(jsonDecode(r.body));}catch(_){}if(mounted)setState(()=>busy=false);}@override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const LogoMark(),backgroundColor:Colors.white,foregroundColor:navy),body:Column(children:[Padding(padding:const EdgeInsets.all(16),child:TextField(controller:c,textInputAction:TextInputAction.search,onSubmitted:(_)=>go(),decoration:InputDecoration(hintText:'Zoek nieuws op Voorne',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:go,icon:const Icon(Icons.arrow_forward))))),if(busy)const LinearProgressIndicator(),Expanded(child:ListView.builder(itemCount:results.length,itemBuilder:(context,i){final p=results[i];final title=(p['title']?['rendered']??'').toString().replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&#8211;','–').replaceAll('&amp;','&');return ListTile(leading:postImage(p).isEmpty?const Icon(Icons.article_outlined):Image.network(postImage(p),width:72,height:54,fit:BoxFit.cover),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text(formatPostDate(p)),onTap:()=>openArticle(context,p));}))]));}


// ignore: unused_element
class NativeInfoPage extends StatelessWidget { final String title,text; final IconData icon; const NativeInfoPage({super.key,required this.title,required this.icon,required this.text}); @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(title),backgroundColor:Colors.white,foregroundColor:navy),body:Padding(padding:const EdgeInsets.all(22),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:42,color:cyan),const SizedBox(height:16),Text(title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:10),Text(text,style:const TextStyle(fontSize:16,height:1.5))]))))); }



Future<Map<String,String>> authHeaders() async { final t=await const FlutterSecureStorage().read(key:'rvaz_token'); return {'Accept':'application/json',if(t!=null&&t.isNotEmpty)'Authorization':'Bearer $t'}; }
class SavedPage extends StatefulWidget{const SavedPage({super.key});@override State<SavedPage> createState()=>_SavedPageState();}class _SavedPageState extends State<SavedPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/saved'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');if(r.statusCode!=200)return[];final d=jsonDecode(r.body);return d is List?List<dynamic>.from(d):(d is Map&&d['items'] is List?List<dynamic>.from(d['items']):[]);}Future<void>open(dynamic e)async{final id=int.tryParse('${e['post_id']??e['id']??''}');if(id==null)return;try{final r=await http.get(Uri.parse('$site/wp-json/wp/v2/posts/$id?_embed=1'));if(r.statusCode==200&&mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>ArticlePage(post:jsonDecode(r.body))));}catch(_){}}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Opgeslagen artikelen')),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Nog geen opgeslagen artikelen.')):ListView(children:x.map((e){final t=e['title'];final title=t is Map?t['rendered']:'${t??'Artikel'}';return ListTile(leading:const Icon(Icons.bookmark,color:navy),title:Text('$title'),trailing:const Icon(Icons.chevron_right),onTap:()=>open(e));}).toList());}));}
class ContributionsPage extends StatefulWidget{const ContributionsPage({super.key});@override State<ContributionsPage> createState()=>_ContributionsPageState();}class _ContributionsPageState extends State<ContributionsPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/contributions'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Mijn bijdragen')),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Je hebt nog geen bijdragen.')):ListView(children:x.map((e)=>ListTile(title:Text('${e['title']}'),subtitle:Text('${e['status']} · ${e['type']}'))).toList());}));}
class BusinessesPage extends StatefulWidget{const BusinessesPage({super.key});@override State<BusinessesPage> createState()=>_BusinessesPageState();}
class _BusinessesPageState extends State<BusinessesPage>{
 late Future<List<dynamic>> future;@override void initState(){super.initState();future=load();}
 Future<List<dynamic>> load()async{try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/businesses')).timeout(const Duration(seconds:10));if(r.statusCode==200){final d=jsonDecode(r.body);if(d is List)return List<dynamic>.from(d);if(d is Map){final x=d['items']??d['businesses']??d['data'];if(x is List)return List<dynamic>.from(x);}}}catch(_){}return [];}
 String v(dynamic e,String k)=>e[k]?.toString()??'';
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Bedrijvengids'),backgroundColor:Colors.white,foregroundColor:navy,actions:const [PageFeedbackButton(page:'Bedrijvengids')]),body:FutureBuilder<List<dynamic>>(future:future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final x=s.data??[];if(x.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Er zijn nog geen bedrijven via de app-API beschikbaar.')));return ListView.separated(padding:const EdgeInsets.all(16),itemCount:x.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(c,i){final e=x[i],img=v(e,'image');return Card(child:ListTile(contentPadding:const EdgeInsets.all(10),leading:img.isEmpty?const CircleAvatar(child:Icon(Icons.storefront)):ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(img,width:64,height:64,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.storefront))),title:Text(v(e,'title'),style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text([v(e,'place'),v(e,'address')].where((z)=>z.isNotEmpty).join(' · ')),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessDetailPage(item:e)))));});}));
}
class BusinessDetailPage extends StatelessWidget{final dynamic item;const BusinessDetailPage({super.key,required this.item});String v(String k)=>item[k]?.toString()??'';@override Widget build(BuildContext context){final img=v('image'),web=v('website'),phone=v('phone'),content=v('content');return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(v('title')),actions:[PageFeedbackButton(page:'Bedrijvengids',detail:v('title'))]),body:ListView(children:[if(img.isNotEmpty)Image.network(img,height:220,width:double.infinity,fit:BoxFit.cover),Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(v('title'),style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),if(v('address').isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined),title:Text(v('address'))),if(phone.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.phone_outlined),title:Text(phone),onTap:()=>launchUrl(Uri.parse('tel:$phone'))),if(content.isNotEmpty)Html(data:cleanArticleHtml(content)),if(web.isNotEmpty)FilledButton.icon(onPressed:()=>launchUrl(Uri.parse(web),mode:LaunchMode.externalApplication),icon:const Icon(Icons.language),label:const Text('Website bedrijf'))]))]));}
}
class TipPage extends StatefulWidget{const TipPage({super.key});@override State<TipPage> createState()=>_TipPageState();}class _TipPageState extends State<TipPage>{final subject=TextEditingController(),place=TextEditingController(),body=TextEditingController();bool busy=false;Future<void>send()async{
  final s=subject.text.trim(),p=place.text.trim(),b=body.text.trim(); if(s.isEmpty||b.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul een onderwerp en je tip in.')));return;}
  setState(()=>busy=true); final h=await authHeaders(); h['Content-Type']='application/json'; h['Accept']='application/json'; var delivered=false;
  for(final payload in [{'subject':s,'place':p,'text':b,'message':b,'source':'android-app'},{'title':s,'location':p,'body':b,'message':b,'source':'android-app'}]){try{final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/tip'),headers:h,body:jsonEncode(payload)).timeout(const Duration(seconds:10));if(r.statusCode>=200&&r.statusCode<300){delivered=true;break;}}catch(_){}}
  if(!mounted)return; setState(()=>busy=false); if(delivered){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Tip is naar de redactie gestuurd.')));Navigator.pop(context);return;}
  final mail=Uri.parse('mailto:redactie@regiovoorneaanzee.nl?subject=${Uri.encodeComponent('Tip uit RVAZ-app: $s')}&body=${Uri.encodeComponent('Plaats: $p\\n\\n$b')}'); final opened=await launchUrl(mail,mode:LaunchMode.externalApplication);
  if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(opened?'De API reageerde niet; je e-mailapp is geopend als veilige fallback.':'Tip kon niet worden verstuurd.')));
}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Tip de redactie')),body:ListView(padding:const EdgeInsets.all(18),children:[TextField(controller:subject,decoration:const InputDecoration(labelText:'Onderwerp')),TextField(controller:place,decoration:const InputDecoration(labelText:'Plaats')),const SizedBox(height:12),TextField(controller:body,minLines:8,maxLines:14,decoration:const InputDecoration(labelText:'Vertel ons wat er speelt',border:OutlineInputBorder())),const SizedBox(height:16),FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.send),label:Text(busy?'Versturen…':'Verstuur naar redactie'))]));}
class InAppWebPage extends StatelessWidget{final String title,url;const InAppWebPage({super.key,required this.title,required this.url});@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(title)),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.ads_click,size:44,color:navy),const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:10),const Text('Advertentielink. Je verlaat de app alleen wanneer je hieronder kiest om de bestemming te openen.'),const SizedBox(height:16),FilledButton(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),child:const Text('Open bestemming'))]))));}


class EventDetailPage extends StatelessWidget{final dynamic event;const EventDetailPage({super.key,required this.event});String v(List<String> keys){for(final k in keys){final x=event[k];if(x!=null&&'$x'.trim().isNotEmpty)return '$x';}return'';}String title(){final x=event['title'];return x is Map?'${x['rendered']??''}':'${x??''}';}String category(){final x=event['category']??event['categories']??event['event_category'];if(x is List)return x.map((e)=>e is Map?(e['name']??e['title']??''):'$e').where((e)=>'$e'.isNotEmpty).join(', ');if(x is Map)return '${x['name']??x['title']??''}';return x?.toString()??'';}String address(){final full=v(['full_address','address']);if(full.isNotEmpty)return full;final street=v(['street','straat','location']),nr=v(['house_number','number','huisnummer']),zip=v(['postcode','postal_code']),city=v(['place','city','town','plaats']);final first=[street,nr].where((x)=>x.isNotEmpty).join(' '),second=[zip,city].where((x)=>x.isNotEmpty).join(' ');return[first,second].where((x)=>x.isNotEmpty).join('\n');}
@override Widget build(BuildContext context){final image=v(['image','featured_image']),html=v(['content','description']),venue=v(['venue','location_name']),addr=address(),cat=category();return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(backgroundColor:Colors.white,foregroundColor:navy,title:const LogoMark()),body:ListView(children:[if(image.isNotEmpty)Image.network(image,height:230,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('AGENDA',style:TextStyle(color:cyan,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(title(),style:const TextStyle(fontSize:28,height:1.1,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:16),if(v(['display_date','start_date','date']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month,color:navy),title:Text(v(['display_date','start_date','date'])),subtitle:v(['time','start_time']).isNotEmpty?Text(v(['time','start_time'])):null),if(cat.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.category_outlined,color:navy),title:Text(cat)),if(venue.isNotEmpty||addr.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined,color:navy),title:Text(venue.isNotEmpty?venue:addr),subtitle:venue.isNotEmpty&&addr.isNotEmpty?Text(addr):null),if(v(['organizer','organisation','organisatie']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.groups_outlined,color:navy),title:Text(v(['organizer','organisation','organisatie']))),if(v(['price','kosten']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.euro_outlined,color:navy),title:Text(v(['price','kosten']))),const Divider(height:28),if(html.isNotEmpty)Html(data:html,style:{'body':Style(fontSize:FontSize(16),lineHeight:const LineHeight(1.5),margin:Margins.zero)}),if(html.isEmpty&&v(['excerpt']).isNotEmpty)Text(v(['excerpt']),style:const TextStyle(fontSize:16,height:1.5))]))]));}}


class MyAdsPage extends StatefulWidget{const MyAdsPage({super.key});@override State<MyAdsPage> createState()=>_MyAdsPageState();}
class _MyAdsPageState extends State<MyAdsPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/my-ads'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Mijn advertenties'),backgroundColor:Colors.white,foregroundColor:navy),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Je hebt nog geen advertentiecampagnes.')):ListView(padding:const EdgeInsets.all(16),children:x.map((e)=>Card(child:ListTile(title:Text('${e['title']}',style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text('${e['approved']==true?'Actief':'Wacht op goedkeuring'} · ${e['channel']}\nWebsite: ${e['web_impressions']} vertoningen / ${e['web_clicks']} klikken\nApp: ${e['app_impressions']} vertoningen / ${e['app_clicks']} klikken')))).toList());}));}
class InvoicesPage extends StatefulWidget{const InvoicesPage({super.key});@override State<InvoicesPage> createState()=>_InvoicesPageState();}
class _InvoicesPageState extends State<InvoicesPage>{late Future<List<dynamic>> f;@override void initState(){super.initState();f=load();}Future<List<dynamic>>load()async{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/invoices'),headers:await authHeaders());if(r.statusCode==401)throw Exception('Log eerst in bij Account.');return r.statusCode==200?List<dynamic>.from(jsonDecode(r.body)):[];}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Facturen'),backgroundColor:Colors.white,foregroundColor:navy),body:FutureBuilder<List<dynamic>>(future:f,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));final x=s.data??[];return x.isEmpty?const Center(child:Text('Nog geen facturen.')):ListView(padding:const EdgeInsets.all(16),children:x.map((e)=>Card(child:ListTile(leading:const Icon(Icons.receipt_long,color:navy),title:Text('${e['number']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${e['date']}'),trailing:Text('€ ${e['total']}',style:const TextStyle(fontWeight:FontWeight.w900,color:navy))))).toList());}));}

class ProfilePage extends StatelessWidget{final Map<String,dynamic> user;const ProfilePage({super.key,required this.user});@override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Mijn profiel'),backgroundColor:Colors.white,foregroundColor:navy),body:ListView(padding:const EdgeInsets.all(18),children:[Card(child:Column(children:[ListTile(leading:const Icon(Icons.person),title:Text(user['name']?.toString()??''),subtitle:const Text('Naam')),const Divider(height:1),ListTile(leading:const Icon(Icons.email_outlined),title:Text(user['email']?.toString()??''),subtitle:const Text('E-mailadres')),if((user['place']?.toString()??'').isNotEmpty)...[const Divider(height:1),ListTile(leading:const Icon(Icons.location_on_outlined),title:Text(user['place'].toString()),subtitle:const Text('Woonplaats'))]]))]));}
class NotificationPreferencesPage extends StatefulWidget{const NotificationPreferencesPage({super.key});@override State<NotificationPreferencesPage> createState()=>_NotificationPreferencesPageState();}
class _NotificationPreferencesPageState extends State<NotificationPreferencesPage>{
 Map<String,bool> p={'breaking':true,'news':true,'emergency112':false,'traffic':true,'agenda':true,'weekblad':true};bool busy=true;
 @override void initState(){super.initState();load();}
 Future<void>load()async{final local=await const FlutterSecureStorage().read(key:'rvaz_push_112');if(local!=null)p['emergency112']=local=='1';try{final h=await authHeaders();if(h.containsKey('Authorization')){final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/preferences'),headers:h);if(r.statusCode==200){final d=Map<String,dynamic>.from(jsonDecode(r.body));for(final k in p.keys){if(d.containsKey(k))p[k]=d[k]==true;}}}}catch(_){}if(mounted)setState(()=>busy=false);}
 Future<void>save(String k,bool v)async{setState(()=>p[k]=v);try{if(k=='emergency112')await const FlutterSecureStorage().write(key:'rvaz_push_112',value:v?'1':'0');final h=await authHeaders();if(h.containsKey('Authorization'))await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/preferences'),headers:{...h,'Content-Type':'application/json'},body:jsonEncode(p));final m=FirebaseMessaging.instance;final topic=k=='emergency112'?'112':(k=='traffic'?'verkeer':k);if(v){await m.subscribeToTopic(topic);}else{await m.unsubscribeFromTopic(topic);}await registerDeviceToken();}catch(_){}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Meldingen'),backgroundColor:Colors.white,foregroundColor:navy),body:busy?const Center(child:CircularProgressIndicator()):ListView(children:[
   SwitchListTile(value:p['emergency112']??false,onChanged:(v)=>save('emergency112',v),title:const Text('Elke nieuwe P2000-melding'),subtitle:const Text('Pushmelding bij nieuwe P2000-meldingen uit Rotterdam-Rijnmond')),
   const Divider(height:1),
   for(final e in {'breaking':'Breaking nieuws','news':'Nieuws','traffic':'Verkeer','agenda':'Agenda','weekblad':'Weekblad'}.entries)SwitchListTile(value:p[e.key]??true,onChanged:(v)=>save(e.key,v),title:Text(e.value))
 ]));}
