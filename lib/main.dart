import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

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
    const storage=FlutterSecureStorage();
    final p2000OptIn=(await storage.read(key:'rvaz_push_112'))=='1';
    final p2000StreetEnabled=(await storage.read(key:'rvaz_p2000_street_enabled'))=='1';
    final p2000StreetPlace=(await storage.read(key:'rvaz_p2000_street_place')??'').trim();
    final p2000StreetName=(await storage.read(key:'rvaz_p2000_street_name')??'').trim();
    final topics=<String>['all','news','breaking','hellevoetsluis','brielle','rockanje','oostvoorne','verkeer','agenda','weekblad'];
    if(p2000OptIn){
      topics.add('112');
      try{await m.subscribeToTopic('112');}catch(_){}
      for(final place in ['hellevoetsluis','rockanje','brielle','oostvoorne','voorne-aan-zee']){try{await m.unsubscribeFromTopic('p2000-$place');}catch(_){}}
    }else{
      try{await m.unsubscribeFromTopic('112');}catch(_){}
      for(final place in ['hellevoetsluis','rockanje','brielle','oostvoorne','voorne-aan-zee']){
        final topic='p2000-$place';
        if((await storage.read(key:'rvaz_p2000_$place'))=='1'){
          topics.add(topic);
          try{await m.subscribeToTopic(topic);}catch(_){}
        }else{
          try{await m.unsubscribeFromTopic(topic);}catch(_){}
        }
      }
    }
    final payload = jsonEncode({'token':token,'device_token':token,'fcm_token':token,'platform':'android','topics':topics,'p2000_street':{'enabled':p2000StreetEnabled&&p2000StreetPlace.isNotEmpty&&p2000StreetName.isNotEmpty,'place':p2000StreetPlace,'street':p2000StreetName}});
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
    for (final topic in ['all','news','breaking','hellevoetsluis','brielle','rockanje','oostvoorne','verkeer','agenda','weekblad']) {
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
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>maybeAskTesterFeedback(context));}
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
    if(ad.image.isEmpty)return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom:10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ad.url.isEmpty ? null : () async {
          await trackAd(ad.id,'click');
          if(context.mounted) Navigator.of(context).push(MaterialPageRoute(builder:(_)=>InAppWebPage(title:ad.title,url:ad.url)));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(ad.image,width:double.infinity,fit:BoxFit.fitWidth,
            errorBuilder:(_,__,___)=>const SizedBox.shrink()),
        ),
      ),
    );
  }
}

class RotatingAppAd extends StatefulWidget {
  final Future<List<AppAd>> future;
  const RotatingAppAd({super.key,required this.future});
  @override State<RotatingAppAd> createState()=>_RotatingAppAdState();
}
class _RotatingAppAdState extends State<RotatingAppAd> {
  int index=0;
  Timer? timer;
  List<AppAd> current=const [];
  @override void dispose(){timer?.cancel();super.dispose();}
  void sync(List<AppAd> ads){
    if(ads.length<=1){timer?.cancel();timer=null;return;}
    if(current.length==ads.length&&current.asMap().entries.every((e)=>e.value.id==ads[e.key].id))return;
    current=ads;
    timer?.cancel();
    timer=Timer.periodic(const Duration(seconds:10),(_){
      if(mounted)setState(()=>index=(index+1)%current.length);
    });
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<AppAd>>(
    future:widget.future,
    builder:(context,s){
      final ads=s.data??[];
      if(ads.isEmpty)return const SizedBox.shrink();
      WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)sync(ads);});
      return AppAdCard(key:ValueKey(ads[index%ads.length].id),ad:ads[index%ads.length]);
    },
  );
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

Future<void> maybeAskTesterFeedback(BuildContext context) async {
  const st=FlutterSecureStorage();
  final disabled=(await st.read(key:'rvaz_feedback_prompt_disabled'))=='1';
  if(disabled)return;
  final n=(int.tryParse(await st.read(key:'rvaz_app_opens')??'0')??0)+1;
  await st.write(key:'rvaz_app_opens',value:'$n');
  if(n<4 || (n-4)%7!=0)return;
  if(!context.mounted)return;
  final action=await showDialog<String>(context:context,builder:(d)=>AlertDialog(
    title:const Text('Help je mee de RVAZ-app beter te maken?'),
    content:const Text('Je test de app. Wil je kort delen wat goed werkt of wat we nog kunnen verbeteren?'),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(d,'stop'),child:const Text('Niet meer vragen')),
      TextButton(onPressed:()=>Navigator.pop(d,'later'),child:const Text('Later')),
      FilledButton(onPressed:()=>Navigator.pop(d,'feedback'),child:const Text('Feedback geven')),
    ],
  ));
  if(action=='stop')await st.write(key:'rvaz_feedback_prompt_disabled',value:'1');
  if(action=='feedback'&&context.mounted)await sendPageFeedback(context,'Testfeedback');
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
      FilledButton(onPressed:(){Navigator.pop(d);Navigator.push(context,MaterialPageRoute(builder:(_)=>const Scaffold(backgroundColor:Color(0xFFF7F9FB),body:SafeArea(child:AccountPage()))));},child:const Text('Inloggen')),
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
    if(denied)return Scaffold(appBar:AppBar(title:const Text('Regio Voorne aan Zee')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:48,color:navy),const SizedBox(height:14),const Text('Alleen voor ingelogde gebruikers',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:8),const Text('Log in bij Mijn RVAZ om dit artikel te lezen.',textAlign:TextAlign.center),const SizedBox(height:16),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountPage())),child:const Text('Inloggen'))]))));
    final image = postImage(post);
    final rawTitle = post['title'];
    final rawContent = post['content'];
    final title = clean(rawTitle is Map ? '${rawTitle['rendered'] ?? ''}' : '${rawTitle ?? ''}');
    final bodyHtml = cleanArticleHtml(rawContent is Map ? '${rawContent['rendered'] ?? ''}' : '${rawContent ?? post['excerpt'] ?? ''}');
    final articleAds = loadAppAds(placement:'article');
    final blocks=bodyHtml.split(RegExp(r'(?<=</p>)',caseSensitive:false)).where((x)=>x.trim().isNotEmpty).toList();
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Regio Voorne aan Zee',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Artikel delen',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final link = '${post['link'] ?? post['url'] ?? '$site/?p=${post['id'] ?? ''}'}';
              await SharePlus.instance.share(
                ShareParams(text: '$title\n\n$link'),
              );
            },
          ),
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
      body: FutureBuilder<List<AppAd>>(
        future: articleAds,
        builder: (context, adSnapshot) {
          final ads=adSnapshot.data??[];
          final content=<Widget>[];
          if(blocks.isEmpty){
            content.add(SizedBox(width:double.infinity,child:Html(data:bodyHtml,style:{'body':Style(margin:Margins.zero,padding:HtmlPaddings.zero,fontSize:FontSize(17),lineHeight:LineHeight(1.55),color:const Color(0xFF202A33)),'h1':Style(fontSize:FontSize(28),fontWeight:FontWeight.w900,color:navy),'h2':Style(fontSize:FontSize(24),fontWeight:FontWeight.w900,color:navy),'h3':Style(fontSize:FontSize(20),fontWeight:FontWeight.w800,color:navy)})));
          }else{
            // Korte artikelen: maximaal één advertentie. Langere artikelen krijgen
            // advertenties verspreid door de tekst, met minimaal drie tekstblokken ertussen.
            final adEvery=blocks.length>=10?4:(blocks.length>=6?3:blocks.length);
            var adIndex=0;
            for(var i=0;i<blocks.length;i++){
              content.add(SizedBox(width:double.infinity,child:Html(data:blocks[i],style:{'body':Style(margin:Margins.zero,padding:HtmlPaddings.zero,fontSize:FontSize(17),lineHeight:LineHeight(1.55),color:const Color(0xFF202A33)),'h1':Style(fontSize:FontSize(28),fontWeight:FontWeight.w900,color:navy),'h2':Style(fontSize:FontSize(24),fontWeight:FontWeight.w900,color:navy),'h3':Style(fontSize:FontSize(20),fontWeight:FontWeight.w800,color:navy)})));
              final after=i+1;
              final canInsert=ads.isNotEmpty&&after<blocks.length&&after%adEvery==0;
              if(canInsert){
                content.add(const SizedBox(height:14));
                content.add(AppAdCard(ad:ads[adIndex%ads.length]));
                content.add(const SizedBox(height:14));
                adIndex++;
              }
            }
          }
          return ListView(children:[
            if (image.isNotEmpty)
              Image.network(image, height: 240, width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('NIEUWS',style:TextStyle(color:cyan,fontWeight:FontWeight.w900)),
                const SizedBox(height:8),
                Text(title,style:const TextStyle(color:navy,fontSize:29,height:1.08,fontWeight:FontWeight.w900)),
                const SizedBox(height:18),
                ...content,
                if(blocks.length<6&&ads.isNotEmpty)...[
                  const SizedBox(height:14),
                  AppAdCard(ad:ads.first),
                ],
                const SizedBox(height:24),
                OutlinedButton.icon(
                  onPressed: () { final link='${post['link'] ?? post['url'] ?? ''}'; if(link.isNotEmpty) launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication); },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Bekijk origineel op de website'),
                ),
              ]),
            ),
          ]);
        },
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
  late Future<List<dynamic>> businesses;
  int visibleNews=8;
  @override void initState(){super.initState();_reload();}
  void _reload(){visibleNews=8;posts=_posts();events=_events();ads=loadAppAds(placement:'home');businesses=loadBusinesses();}
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
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(_reload);await Future.wait([posts,events,ads,businesses]);},child:ListView(padding:EdgeInsets.zero,children:[
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
    Container(padding:const EdgeInsets.fromLTRB(14,8,14,0),child:GridView.count(crossAxisCount:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:8,crossAxisSpacing:8,childAspectRatio:1.25,children:[
      _HomeShortcut(icon:Icons.article_outlined,color:Colors.blue,label:'Nieuws',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Nieuws'),backgroundColor:Colors.white,foregroundColor:navy),body:const NewsPage())))),
      _HomeShortcut(icon:Icons.warning_amber_rounded,color:Colors.red,label:'112 & Verkeer',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EmergencyTrafficPage()))),
      _HomeShortcut(icon:Icons.calendar_month,color:Colors.teal,label:'Agenda',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Agenda'),backgroundColor:Colors.white,foregroundColor:navy),body:const AgendaPage())))),
      _HomeShortcut(icon:Icons.location_on,color:Colors.green,label:'Plaatsen',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PlacesPage()))),
      _HomeShortcut(icon:Icons.favorite,color:Colors.redAccent,label:'Favorieten',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountPage()))),
      _HomeShortcut(icon:Icons.business,color:Colors.deepPurple,label:'Bedrijven',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessesPage()))),
    ])),
    Padding(padding:const EdgeInsets.fromLTRB(16,14,16,0),child:Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:10),leading:const CircleAvatar(child:Icon(Icons.photo_camera_outlined)),title:const Text('Tip de redactie',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Iets gezien? Stuur direct je tip en maximaal 5 eigen foto’s.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TipPage()))))),
    FutureBuilder<Map<String,dynamic>>(future:_editorialCapabilities(),builder:(context,s){if(s.data?['can_submit_news']!=true)return const SizedBox.shrink();return Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.edit_note)),title:const Text('Nieuws insturen',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Voor redactieleden · ter goedkeuring door de eindredactie'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EditorialSubmitPage())))));}),
    FutureBuilder<List<dynamic>>(future:businesses,builder:(context,s){
      final pros=(s.data??[]).where(_businessIsPro).toList();
      if(pros.isEmpty)return const SizedBox.shrink();
      final e=pros[DateTime.now().day%pros.length];
      String bv(String k)=>e is Map?(e[k]?.toString()??''):'';
      final img=bv('image');
      return Padding(padding:const EdgeInsets.fromLTRB(16,16,16,4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('PRO bedrijf',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessesPage())),child:const Text('Bedrijven →'))]),
        Card(child:InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessDetailPage(item:e))),child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
          img.isEmpty?const CircleAvatar(radius:34,child:Icon(Icons.storefront)):ClipRRect(borderRadius:BorderRadius.circular(9),child:Image.network(img,width:68,height:68,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:68,height:68,child:Icon(Icons.storefront)))),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:cyan,borderRadius:BorderRadius.circular(4)),child:const Text('PRO',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))),
            const SizedBox(height:6),Text(bv('title'),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:navy)),
            if(bv('place').isNotEmpty||bv('address').isNotEmpty)Text([bv('place'),bv('address')].where((x)=>x.isNotEmpty).join(' · '),maxLines:2,style:const TextStyle(fontSize:11,color:Colors.black54)),
          ])),const Icon(Icons.chevron_right,color:navy)
        ]))))
      ]));
    }),
    Padding(padding:const EdgeInsets.fromLTRB(16,0,16,22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Laatste nieuws',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Nieuws'),backgroundColor:Colors.white,foregroundColor:navy),body:const NewsPage()))),child:const Text('Meer →'))]),
      FutureBuilder<List<dynamic>>(future:posts,builder:(context,s){final all=s.data??[];if(all.isEmpty)return const SizedBox.shrink();final x=all.take(visibleNews).toList();final p=x.first;return Column(children:[
        Card(clipBehavior:Clip.antiAlias,margin:EdgeInsets.zero,child:InkWell(onTap:()=>openArticle(context,p),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(postImage(p).isNotEmpty)Image.network(postImage(p),height:175,width:double.infinity,fit:BoxFit.cover),
          Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(3)),child:const Text('NIEUWS',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))),const SizedBox(width:5),Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:cyan,borderRadius:BorderRadius.circular(3)),child:const Text('VOORNE AAN ZEE',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)))]),const SizedBox(height:7),Text(clean(p['title'] is Map?p['title']['rendered']:p['title']??''),style:const TextStyle(color:navy,fontSize:18,height:1.15,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(formatPostDate(p),style:const TextStyle(fontSize:10,color:Colors.black54))]))]))),
        const SizedBox(height:10),
        RotatingAppAd(future:ads),
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
  bool matchesPlace(dynamic p) {
    if (p is! Map) return false;
    final q=widget.place.toLowerCase();
    final fields=[p['place'],p['plaats'],p['location'],p['city'],p['categories'],p['tags'],p['title']];
    return fields.map((v)=>'$v'.toLowerCase()).any((v)=>v.contains(q));
  }
  Future<List<dynamic>> load() async {
    final q=Uri.encodeQueryComponent(widget.place);
    Future<List<dynamic>> fetch(Uri uri) async {
      final r=await http.get(uri,headers:await authHeaders()).timeout(const Duration(seconds:15));
      if(r.statusCode!=200)return <dynamic>[];
      final d=jsonDecode(r.body);
      if(d is List)return List<dynamic>.from(d);
      if(d is Map){final raw=d['items']??d['posts']??d['data'];if(raw is List)return List<dynamic>.from(raw);}
      return <dynamic>[];
    }
    var x=await fetch(Uri.parse('$site/wp-json/rvaz-app/v1/posts?place=$q&per_page=100'));
    final filtered=x.where(matchesPlace).toList();
    if(filtered.isNotEmpty)return filtered;
    x=await fetch(Uri.parse('$site/wp-json/rvaz-app/v1/posts?per_page=100'));
    return x.where(matchesPlace).toList();
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
   final region=Uri.encodeQueryComponent('Rotterdam-Rijnmond');
   final primary=await RvazApi.firstList(
     traffic?['traffic?region=$region&per_page=250','verkeer?region=$region&per_page=250']:['p2000?region=$region&per_page=250','112?region=$region&per_page=250','meldingen?region=$region&per_page=250'],
     keys:traffic?const ['traffic','verkeer','meldingen']:const ['meldingen','p2000','112','items','data'],
   );
   if(primary.isNotEmpty)return primary;
   if(!traffic){for(final type in ['rvaz_p2000','rvaz_112','p2000']){try{final r=await http.get(Uri.parse('$site/wp-json/wp/v2/$type?per_page=100&_embed=1')).timeout(const Duration(seconds:10));if(r.statusCode==200){final x=RvazApi.list(jsonDecode(r.body));if(x.isNotEmpty)return x;}}catch(_){}}}
   return <dynamic>[];
 }
 List<dynamic> filtered(List<dynamic> all){if(traffic||place=='Rotterdam-Rijnmond')return all;if(place=='Voorne aan Zee'){const places=['hellevoetsluis','brielle','rockanje','oostvoorne','oudenhoorn','nieuwenhoorn','tinte','vierpolders','zwartewaal','abbenbroek','heenvliet','geervliet','zuidland','simonshaven'];return all.where((e){final h=hay(e);return places.any(h.contains);}).toList();}final q=place.toLowerCase();return all.where((e)=>hay(e).contains(q)).toList();}
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
   Expanded(child:FutureBuilder<List<dynamic>>(future:items,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final x=filtered(s.data??[]);if(x.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(traffic?'Geen actuele verkeersmeldingen voor deze selectie.':'Geen P2000-meldingen gevonden in de aangeleverde Rijnmond-feed.')));return RefreshIndicator(onRefresh:()async{refresh();await items;},child:ListView.separated(padding:const EdgeInsets.fromLTRB(16,0,16,20),itemCount:x.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(c,i){final e=x[i];final title='${e['title']??e['message']??e['description']??'Melding'}';final date='${e['date']??e['datetime']??e['published']??''}';return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:5),leading:Icon(traffic?Icons.traffic:Icons.warning_amber_rounded,color:traffic?navy:Colors.red),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(date),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>P2000DetailPage(item:e,traffic:traffic))));}));}))
 ]));}

class P2000DetailPage extends StatelessWidget {
  final dynamic item; final bool traffic;
  const P2000DetailPage({super.key,required this.item,required this.traffic});
  String value(List<String> keys){if(item is! Map)return '';for(final k in keys){final v=item[k];if(v!=null&&'$v'.trim().isNotEmpty)return '$v'.trim();}return '';}
  @override Widget build(BuildContext context){
    final title=value(['title','message','description']).isEmpty?'Melding':value(['title','message','description']);
    final date=value(['date','datetime','published','time']);
    final place=value(['place','location','city']);
    final service=value(['service','discipline','dienst','agency']);
    final priority=value(['priority','prio']);
    final body=value(['body','description','details','content']);
    final detailAds=loadAppAds(placement:'p2000');
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(traffic?'Verkeersmelding':'P2000-melding'),backgroundColor:Colors.white,foregroundColor:navy),body:ListView(padding:const EdgeInsets.all(18),children:[
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(traffic?Icons.traffic:Icons.warning_amber_rounded,color:traffic?navy:Colors.red,size:34),const SizedBox(height:12),
        Text(title,style:const TextStyle(fontSize:22,height:1.2,fontWeight:FontWeight.w900,color:navy)),
        if(date.isNotEmpty)...[const SizedBox(height:14),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.schedule),title:Text(date))],
        if(place.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined),title:Text(place)),
        if(service.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.emergency_outlined),title:Text(service)),
        if(priority.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.priority_high),title:Text(priority)),
        if(body.isNotEmpty&&body!=title)...[const Divider(height:28),Text(body,style:const TextStyle(fontSize:16,height:1.5))],
      ]))),
      const SizedBox(height:14),
      RotatingAppAd(future:detailAds),
    ]));
  }
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
 @override Widget build(BuildContext context)=>ColoredBox(color:const Color(0xFFF7F9FB),child:FutureBuilder<List<dynamic>>(future:future,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final all=s.data??[];final places=<String>['Alle',...appConfig.places.where((x)=>x!='Voorne aan Zee')];final items=all.where((p)=>place=='Alle'||placeOf(p).toLowerCase()==place.toLowerCase()).toList()..sort((a,b)=>(date(a)??DateTime(2100)).compareTo(date(b)??DateTime(2100)));return Column(children:[
   SizedBox(height:54,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.fromLTRB(14,9,14,7),itemCount:places.length,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(c,i){final x=places[i],on=x==place;return ChoiceChip(label:Text(x),selected:on,onSelected:(_)=>setState(()=>place=x),selectedColor:cyan,labelStyle:TextStyle(color:on?Colors.white:navy,fontSize:11,fontWeight:FontWeight.w700),side:BorderSide(color:on?cyan:const Color(0xFFDCE5ED)),showCheckmark:false); })),
   Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,20),children:[const Text('Aankomende evenementen',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:10),RotatingAppAd(future:ads),if(items.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Geen evenementen gevonden.')),...items.map((p){final d=date(p);final day=d?.day.toString().padLeft(2,'0')??'--';const months=['','JAN','FEB','MRT','APR','MEI','JUN','JUL','AUG','SEP','OKT','NOV','DEC'];final mon=d==null?'':months[d.month];final img=val(p,['image','image_url','thumbnail']);return Card(margin:const EdgeInsets.only(bottom:8),child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDetailPage(event:p))),child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[SizedBox(width:42,child:Column(children:[Text(day,style:const TextStyle(color:navy,fontSize:20,fontWeight:FontWeight.w900)),Text(mon,style:const TextStyle(color:navy,fontSize:10,fontWeight:FontWeight.w900))])),if(img.isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(5),child:Image.network(img,width:72,height:58,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:72,height:58))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title(p),maxLines:2,style:const TextStyle(color:navy,fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text([val(p,['display_date','start_date','date']),val(p,['venue','location']),placeOf(p),val(p,['time','start_time'])].where((x)=>x.isNotEmpty).join('\n'),maxLines:3,style:const TextStyle(fontSize:10,height:1.25,color:Color(0xFF52687A)))])),const Icon(Icons.chevron_right,color:navy)])))) ;})]))
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
      const Text('Weekblad Voorne aan Zee'),const SizedBox(height:18),RotatingAppAd(future:ads),
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
        ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Weekblad'), subtitle: const Text('Lees de nieuwste editie'), trailing: const Icon(Icons.chevron_right), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Weekblad'),backgroundColor:Colors.white,foregroundColor:navy),body:const WeekbladPage())))),
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
bool _businessIsPro(dynamic e){
 if(e is! Map)return false;
 final p=e['pro'];
 if(p==true||p==1)return true;
 final ps=(p??'').toString().trim().toLowerCase();
 if(ps=='true'||ps=='1'||ps=='yes'||ps=='pro')return true;
 return (e['plan']??'').toString().trim().toLowerCase()=='pro';
}
Map<String,dynamic> _normalizeBusiness(dynamic e){
 if(e is! Map)return <String,dynamic>{};
 final m=Map<String,dynamic>.from(e);
 if(m['title'] is Map)m['title']=m['title']['rendered']??'';
 if(m['content'] is Map)m['content']=m['content']['rendered']??'';
 if((m['image']??'').toString().isEmpty){
  final emb=m['_embedded'];
  if(emb is Map&&emb['wp:featuredmedia'] is List&&(emb['wp:featuredmedia'] as List).isNotEmpty)m['image']=emb['wp:featuredmedia'][0]['source_url']??'';
 }
 return m;
}
Future<List<dynamic>> loadBusinesses()async{
 for(final endpoint in [
  '$site/wp-json/rvaz-app/v1/businesses?per_page=100',
  '$site/wp-json/rvaz-business/v1/businesses?per_page=100',
  '$site/wp-json/wp/v2/rvaz_bedrijf?per_page=100&_embed=1'
 ]){
  try{
   final r=await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds:10));
   if(r.statusCode==200){
    final d=jsonDecode(r.body);
    final dynamic raw=d is List?d:(d is Map?(d['items']??d['businesses']??d['data']):null);
    if(raw is List&&raw.isNotEmpty)return raw.map(_normalizeBusiness).toList();
   }
  }catch(_){}
 }
 return <dynamic>[];
}
class BusinessesPage extends StatefulWidget{const BusinessesPage({super.key});@override State<BusinessesPage> createState()=>_BusinessesPageState();}
class _BusinessesPageState extends State<BusinessesPage>{
 late Future<List<dynamic>> future; String query='',place='',category='';
 @override void initState(){super.initState();future=load();}
 Future<List<dynamic>> load()=>loadBusinesses();
 String v(dynamic e,String k)=>e is Map?e[k]?.toString()??'':'';
 List<String> vals(dynamic e,String plural,String single){final x=e is Map?e[plural]:null;if(x is List)return x.map((z)=>z.toString()).where((z)=>z.isNotEmpty).toList();final one=v(e,single);return one.isEmpty?[]:[one];}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Bedrijvengids'),backgroundColor:Colors.white,foregroundColor:navy,actions:const [PageFeedbackButton(page:'Bedrijvengids')]),body:FutureBuilder<List<dynamic>>(future:future,builder:(c,s){
   if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final all=s.data??[];if(all.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Er zijn nog geen bedrijven via de app-API beschikbaar.')));
   final places=all.expand((e)=>vals(e,'places','place')).toSet().toList()..sort();final cats=all.expand((e)=>vals(e,'categories','category')).toSet().toList()..sort();final q=query.trim().toLowerCase();final x=all.where((e){final matchQ=q.isEmpty||[v(e,'title'),v(e,'address'),...vals(e,'places','place'),...vals(e,'categories','category')].join(' ').toLowerCase().contains(q);final matchP=place.isEmpty||vals(e,'places','place').contains(place);final matchC=category.isEmpty||vals(e,'categories','category').contains(category);return matchQ&&matchP&&matchC;}).toList()..sort((a,b){final ap=_businessIsPro(a),bp=_businessIsPro(b);if(ap!=bp)return ap?-1:1;return v(a,'title').toLowerCase().compareTo(v(b,'title').toLowerCase());});
   return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,14,16,8),child:Column(children:[TextField(onChanged:(z)=>setState(()=>query=z),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Zoek bedrijf…',border:OutlineInputBorder())),const SizedBox(height:8),Row(children:[
     Expanded(child:DropdownButtonFormField<String>(initialValue:place.isEmpty?null:place,isExpanded:true,decoration:const InputDecoration(labelText:'Plaats',border:OutlineInputBorder()),items:[const DropdownMenuItem(value:'',child:Text('Alle plaatsen')),...places.map((z)=>DropdownMenuItem(value:z,child:Text(z,overflow:TextOverflow.ellipsis)))],onChanged:(z)=>setState(()=>place=z??''))),const SizedBox(width:8),
     Expanded(child:DropdownButtonFormField<String>(initialValue:category.isEmpty?null:category,isExpanded:true,decoration:const InputDecoration(labelText:'Categorie',border:OutlineInputBorder()),items:[const DropdownMenuItem(value:'',child:Text('Alle categorieën')),...cats.map((z)=>DropdownMenuItem(value:z,child:Text(z,overflow:TextOverflow.ellipsis)))],onChanged:(z)=>setState(()=>category=z??'')))
   ])])),Expanded(child:x.isEmpty?const Center(child:Text('Geen bedrijven gevonden met deze filters.')):ListView.separated(padding:const EdgeInsets.fromLTRB(16,8,16,16),itemCount:x.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(c,i){final e=x[i],img=v(e,'image');return Card(child:ListTile(contentPadding:const EdgeInsets.all(10),leading:img.isEmpty?const CircleAvatar(child:Icon(Icons.storefront)):ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(img,width:64,height:64,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.storefront))),title:Text(v(e,'title'),style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text([if(_businessIsPro(e))'PRO',v(e,'place'),v(e,'address')].where((z)=>z.isNotEmpty).join(' · ')),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessDetailPage(item:e)))));}))]
   );
 }));
}
class _BusinessLinkIcon extends StatelessWidget{
 final IconData? icon;final String? text;final Color color;final String tooltip,url;
 const _BusinessLinkIcon({this.icon,this.text,required this.color,required this.tooltip,required this.url});
 @override Widget build(BuildContext context)=>Tooltip(message:tooltip,child:InkWell(borderRadius:BorderRadius.circular(24),onTap:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),child:Container(width:44,height:44,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:color),shape:BoxShape.circle),alignment:Alignment.center,child:icon!=null?Icon(icon,color:color,size:28):Text(text??'',style:TextStyle(color:color,fontSize:20,fontWeight:FontWeight.w900)))));
}
class BusinessDetailPage extends StatelessWidget{
 final dynamic item;const BusinessDetailPage({super.key,required this.item});
 String v(String k)=>item is Map?item[k]?.toString()??'':'';
 dynamic rawValue(List<String> keys){if(item is! Map)return null;for(final k in keys){final x=item[k];if(x!=null&&x.toString().trim().isNotEmpty)return x;}return null;}
 Map<dynamic,dynamic> hoursMap(){
  dynamic raw=rawValue(['hours','opening_hours','openingHours','openingstijden']);
  if(raw is String&&raw.trim().isNotEmpty){try{raw=jsonDecode(raw);}catch(_){}}
  if(raw is Map){
   for(final k in ['hours','opening_hours','openingHours','days','week']){final nested=raw[k];if(nested is Map)raw=nested;}
   return raw;
  }
  if(raw is List){
   final out=<dynamic,dynamic>{};
   for(final row in raw){if(row is Map){final day=(row['day']??row['name']??row['weekday']??'').toString().toLowerCase();if(day.isNotEmpty)out[day]=row;}}
   return out;
  }
  return <dynamic,dynamic>{};
 }
 @override Widget build(BuildContext context){
  final img=v('image'),web=v('website'),phone=v('phone'),content=v('content'),email=v('email'),facebook=v('facebook'),instagram=v('instagram'),linkedin=v('linkedin'),socials=v('socials');
  final additional=(rawValue(['additional_info','additionalInfo','extra_info','pro_info'])??'').toString();
  final isPro=_businessIsPro(item);
  final hours=hoursMap();
  const days={'monday':'Maandag','tuesday':'Dinsdag','wednesday':'Woensdag','thursday':'Donderdag','friday':'Vrijdag','saturday':'Zaterdag','sunday':'Zondag'};
  final hourRows=<Widget>[];
  days.forEach((key,label){
   final aliases=<String,List<String>>{'monday':['maandag','mon'],'tuesday':['dinsdag','tue'],'wednesday':['woensdag','wed'],'thursday':['donderdag','thu'],'friday':['vrijdag','fri'],'saturday':['zaterdag','sat'],'sunday':['zondag','sun']};
   dynamic d=hours[key]??hours[label.toLowerCase()]??hours[label];
   for(final a in aliases[key]??const <String>[]){d??=hours[a];}
   var text='Niet opgegeven';
   if(d is Map){
    final closed=d['closed']==1||d['closed']==true||d['closed']=='1';
    final open=(d['open']??d['from']??d['start']??d['opens']??'').toString().trim(),close=(d['close']??d['to']??d['end']??d['closes']??'').toString().trim();
    if(closed){text='Gesloten';}else if(open.isNotEmpty||close.isNotEmpty){text=[open,close].where((z)=>z.isNotEmpty).join(' – ');}
   }else if(d!=null&&d.toString().trim().isNotEmpty){text=d.toString().trim();}
   hourRows.add(Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[SizedBox(width:105,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w700))),Expanded(child:Text(text))])));
  });
  return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(v('title')),actions:[PageFeedbackButton(page:'Bedrijvengids',detail:v('title'))]),body:ListView(children:[
   if(img.isNotEmpty)Image.network(img,height:220,width:double.infinity,fit:BoxFit.cover),
   Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(crossAxisAlignment:CrossAxisAlignment.center,children:[Expanded(child:Text(v('title'),style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy))),if(isPro)const Padding(padding:EdgeInsets.only(left:8),child:Text('PRO',style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:navy))) ]),
    if(v('address').isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined),title:Text(v('address'))),
    if(phone.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.phone_outlined),title:Text(phone),onTap:()=>launchUrl(Uri(scheme:'tel',path:phone))),
    if(isPro&&email.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.email_outlined),title:Text(email),onTap:()=>launchUrl(Uri(scheme:'mailto',path:email))),
    if(isPro&&(web.isNotEmpty||facebook.isNotEmpty||instagram.isNotEmpty||linkedin.isNotEmpty))Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Wrap(spacing:14,runSpacing:10,children:[
      if(web.isNotEmpty)_BusinessLinkIcon(icon:Icons.language,color:const Color(0xFF0A66C2),tooltip:'Website',url:web),
      if(facebook.isNotEmpty)_BusinessLinkIcon(icon:Icons.facebook,color:const Color(0xFF1877F2),tooltip:'Facebook',url:facebook),
      if(instagram.isNotEmpty)_BusinessLinkIcon(icon:Icons.camera_alt_outlined,color:const Color(0xFFE4405F),tooltip:'Instagram',url:instagram),
      if(linkedin.isNotEmpty)_BusinessLinkIcon(text:'in',color:const Color(0xFF0A66C2),tooltip:'LinkedIn',url:linkedin),
    ])),
    if(isPro&&socials.isNotEmpty)Padding(padding:const EdgeInsets.only(top:4,bottom:8),child:Text(socials)),
    const SizedBox(height:12),const Text('Openingstijden',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:8),...hourRows,
    if(content.isNotEmpty)...[const SizedBox(height:18),Html(data:cleanArticleHtml(content))],
    if(isPro&&additional.isNotEmpty)...[const SizedBox(height:18),const Text('Aanvullende informatie',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),Html(data:cleanArticleHtml(additional))],
    
   ]))
  ]));
 }
}
Future<Map<String,dynamic>> _editorialCapabilities()async{try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/editorial/capabilities'),headers:await authHeaders());if(r.statusCode==200)return Map<String,dynamic>.from(jsonDecode(r.body));}catch(_){}return{};}

class TipPage extends StatefulWidget{const TipPage({super.key});@override State<TipPage> createState()=>_TipPageState();}
class _TipPageState extends State<TipPage>{final subject=TextEditingController(),place=TextEditingController(),body=TextEditingController(),name=TextEditingController(),email=TextEditingController();final photos=<XFile>[];XFile? video;bool busy=false,logged=false,rights=false;@override void initState(){super.initState();loadUser();}Future<void>loadUser()async{try{final h=await authHeaders();if(h.containsKey('Authorization')){final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/me'),headers:h);if(r.statusCode==200){final u=Map<String,dynamic>.from(jsonDecode(r.body)['user']??{});name.text=u['name']?.toString()??'';email.text=u['email']?.toString()??'';if(mounted)setState(()=>logged=true);}}}catch(_){}}
Future<void>pick()async{if(photos.length>=5)return;final x=await ImagePicker().pickMultiImage(imageQuality:88);if(!mounted)return;setState((){for(final f in x){if(photos.length<5){photos.add(f);}}});}
Future<void>camera()async{if(photos.length>=5)return;final x=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:88);if(x!=null&&mounted)setState(()=>photos.add(x));}
Future<void>pickVideo()async{final x=await ImagePicker().pickVideo(source:ImageSource.gallery,maxDuration:const Duration(minutes:2));if(x!=null&&mounted)setState(()=>video=x);}
Future<void>send()async{final s=subject.text.trim(),b=body.text.trim();if(s.isEmpty||b.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul een onderwerp in en omschrijf wat er gaande is.')));return;}if(!logged&&(name.text.trim().isEmpty||email.text.trim().isEmpty)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul je naam en e-mailadres in.')));return;}if((photos.isNotEmpty||video!=null)&&!rights){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bevestig eerst dat je de rechten op de foto’s bezit.')));return;}setState(()=>busy=true);try{final req=http.MultipartRequest('POST',Uri.parse('$site/wp-json/rvaz-app/v1/tip'));req.headers.addAll(await authHeaders());req.fields.addAll({'subject':s,'place':place.text.trim(),'text':b,'name':name.text.trim(),'email':email.text.trim(),'photo_rights':rights?'1':'0'});for(var i=0;i<photos.length;i++){req.files.add(await http.MultipartFile.fromPath('photo_$i',photos[i].path));}if(video!=null){req.files.add(await http.MultipartFile.fromPath('video_0',video!.path));}final r=await req.send().timeout(const Duration(seconds:30));if(!mounted)return;setState(()=>busy=false);if(r.statusCode>=200&&r.statusCode<300){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bedankt! Je tip is ontvangen. Je krijgt een bevestiging per e-mail.')));Navigator.pop(context);}else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Versturen mislukt (${r.statusCode}). Probeer opnieuw.')));}}catch(_){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding. Je tip is niet verstuurd.')));}}}
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Tip de redactie')),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Iets gezien of gebeurt er iets?',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),const Text('Vertel de redactie wat er gaande is. Voeg eventueel foto’s of een korte video toe van bijvoorbeeld een brand, ongeval of gebeurtenis.'),const SizedBox(height:16),if(!logged)...[TextField(controller:name,decoration:const InputDecoration(labelText:'Naam')),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mailadres')),const SizedBox(height:8)]else const Text('Je naam en e-mailadres worden automatisch uit je RVAZ-account gebruikt.',style:TextStyle(color:Colors.black54)),TextField(controller:subject,decoration:const InputDecoration(labelText:'Onderwerp *')),TextField(controller:place,decoration:const InputDecoration(labelText:'Plaats / locatie')),const SizedBox(height:12),TextField(controller:body,minLines:7,maxLines:14,decoration:const InputDecoration(labelText:'Wat is er gaande / gebeurd? *',border:OutlineInputBorder())),const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:photos.length>=5?null:pick,icon:const Icon(Icons.photo_library_outlined),label:const Text('Foto’s kiezen'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:photos.length>=5?null:camera,icon:const Icon(Icons.photo_camera_outlined),label:const Text('Foto maken')))]),if(photos.isNotEmpty)...[const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[for(var i=0;i<photos.length;i++)Chip(label:Text('Foto ${i+1}'),onDeleted:()=>setState(()=>photos.removeAt(i)))])],const SizedBox(height:8),Text('${photos.length}/5 foto’s',style:const TextStyle(color:Colors.black54)),const SizedBox(height:8),OutlinedButton.icon(onPressed:video==null?pickVideo:null,icon:const Icon(Icons.videocam_outlined),label:Text(video==null?'Video kiezen (max. 2 min.)':'Video gekozen')),if(video!=null)Align(alignment:Alignment.centerLeft,child:Chip(label:const Text('Video'),onDeleted:()=>setState(()=>video=null))),CheckboxListTile(contentPadding:EdgeInsets.zero,value:rights,onChanged:(photos.isEmpty&&video==null)?null:(v)=>setState(()=>rights=v??false),title:const Text('Ik heb deze foto’s/video zelf gemaakt en bezit de rechten.'),subtitle:const Text('Door het materiaal te versturen geef ik Regio Voorne aan Zee toestemming het redactioneel te gebruiken.')),const SizedBox(height:12),FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.send),label:Text(busy?'Versturen…':'Tip versturen'))]));}

class EditorialSubmitPage extends StatefulWidget{const EditorialSubmitPage({super.key});@override State<EditorialSubmitPage> createState()=>_EditorialSubmitPageState();}
class _EditorialSubmitPageState extends State<EditorialSubmitPage>{final title=TextEditingController(),content=TextEditingController();List<dynamic> cats=[];int? cat;XFile? featured;final gallery=<XFile>[];bool membersOnly=false,push=false,busy=false;@override void initState(){super.initState();load();}Future<void>load()async{try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/editorial/categories'),headers:await authHeaders());if(r.statusCode==200&&mounted)setState(()=>cats=List<dynamic>.from(jsonDecode(r.body)));}catch(_){}}
Future<void>pickFeatured()async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:90);if(x!=null&&mounted)setState(()=>featured=x);}
Future<void>pickGallery()async{final x=await ImagePicker().pickMultiImage(imageQuality:88);if(mounted)setState((){for(final f in x){if(gallery.length<10){gallery.add(f);}}});}
Future<void>send()async{if(title.text.trim().isEmpty||content.text.trim().isEmpty||cat==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Titel, categorie en bericht zijn verplicht.')));return;}setState(()=>busy=true);try{final req=http.MultipartRequest('POST',Uri.parse('$site/wp-json/rvaz-app/v1/editorial/submit'));req.headers.addAll(await authHeaders());req.fields.addAll({'title':title.text.trim(),'content':content.text.trim(),'category':cat.toString(),'members_only':membersOnly?'1':'','push':push?'1':''});if(featured!=null){req.files.add(await http.MultipartFile.fromPath('featured',featured!.path));}for(var i=0;i<gallery.length;i++){req.files.add(await http.MultipartFile.fromPath('gallery_$i',gallery[i].path));}final r=await req.send().timeout(const Duration(seconds:45));if(!mounted)return;setState(()=>busy=false);if(r.statusCode>=200&&r.statusCode<300){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nieuwsbericht is ingediend en wacht op goedkeuring.')));Navigator.pop(context);}else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Indienen mislukt (${r.statusCode}).')));}}catch(_){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding. Bericht is niet ingediend.')));}}}
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Nieuws insturen')),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Voor redactieleden',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),const Text('Je bericht wordt eerst ter goedkeuring aan de eindredactie aangeboden.'),const SizedBox(height:16),TextField(controller:title,decoration:const InputDecoration(labelText:'Titel *')),const SizedBox(height:10),DropdownButtonFormField<int>(initialValue:cat,decoration:const InputDecoration(labelText:'Categorie *'),items:cats.map<DropdownMenuItem<int>>((e)=>DropdownMenuItem(value:int.tryParse(e['id'].toString()),child:Text(e['name'].toString()))).toList(),onChanged:(v)=>setState(()=>cat=v)),const SizedBox(height:12),TextField(controller:content,minLines:10,maxLines:24,decoration:const InputDecoration(labelText:'Nieuwsbericht *',border:OutlineInputBorder())),const SizedBox(height:14),OutlinedButton.icon(onPressed:pickFeatured,icon:const Icon(Icons.image_outlined),label:Text(featured==null?'Uitgelichte foto kiezen':'Uitgelichte foto gekozen')),OutlinedButton.icon(onPressed:gallery.length>=10?null:pickGallery,icon:const Icon(Icons.collections_outlined),label:Text('Foto’s onder bericht (${gallery.length})')),if(gallery.isNotEmpty)Wrap(spacing:8,children:[for(var i=0;i<gallery.length;i++)Chip(label:Text('Foto ${i+1}'),onDeleted:()=>setState(()=>gallery.removeAt(i)))]),SwitchListTile(contentPadding:EdgeInsets.zero,value:membersOnly,onChanged:(v)=>setState(()=>membersOnly=v),title:const Text('Alleen voor geregistreerde gebruikers'),subtitle:const Text('Ja: volledig bericht alleen na inloggen')),SwitchListTile(contentPadding:EdgeInsets.zero,value:push,onChanged:(v)=>setState(()=>push=v),title:const Text('Push via de app na goedkeuring'),subtitle:const Text('De push wordt pas verstuurd wanneer het bericht is goedgekeurd en gepubliceerd.')),const SizedBox(height:10),FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.upload),label:Text(busy?'Indienen…':'Ter goedkeuring indienen'))]));}

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
 Map<String,bool> p={'breaking':true,'news':true,'emergency112':false,'traffic':true,'agenda':true,'weekblad':true};Map<String,bool> p2000={'hellevoetsluis':false,'rockanje':false,'brielle':false,'oostvoorne':false,'voorne-aan-zee':false};bool busy=true,streetEnabled=false;
 final streetPlace=TextEditingController(),streetName=TextEditingController();
 static const labels={'hellevoetsluis':'Hellevoetsluis','rockanje':'Rockanje','brielle':'Brielle','oostvoorne':'Oostvoorne','voorne-aan-zee':'Voorne aan Zee'};
 @override void initState(){super.initState();load();}
 @override void dispose(){streetPlace.dispose();streetName.dispose();super.dispose();}
 Future<void>load()async{const st=FlutterSecureStorage();final local=await st.read(key:'rvaz_push_112');if(local!=null)p['emergency112']=local=='1';for(final k in p2000.keys){p2000[k]=(await st.read(key:'rvaz_p2000_$k'))=='1';}streetEnabled=(await st.read(key:'rvaz_p2000_street_enabled'))=='1';streetPlace.text=await st.read(key:'rvaz_p2000_street_place')??'';streetName.text=await st.read(key:'rvaz_p2000_street_name')??'';try{final h=await authHeaders();if(h.containsKey('Authorization')){final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/preferences'),headers:h);if(r.statusCode==200){final d=Map<String,dynamic>.from(jsonDecode(r.body));for(final k in p.keys){if(d.containsKey(k))p[k]=d[k]==true;}}}}catch(_){}if(mounted)setState(()=>busy=false);}
 Future<void>save(String k,bool v)async{setState(()=>p[k]=v);try{if(k=='emergency112'){await const FlutterSecureStorage().write(key:'rvaz_push_112',value:v?'1':'0');if(v){await disableStreet();for(final place in p2000.keys){await FirebaseMessaging.instance.unsubscribeFromTopic('p2000-$place');}}}final h=await authHeaders();if(h.containsKey('Authorization'))await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/preferences'),headers:{...h,'Content-Type':'application/json'},body:jsonEncode(p));final topic=k=='emergency112'?'112':(k=='traffic'?'verkeer':k);if(v){await FirebaseMessaging.instance.subscribeToTopic(topic);}else{await FirebaseMessaging.instance.unsubscribeFromTopic(topic);}await registerDeviceToken();}catch(_){}}
 Future<void>saveP2000(String place,bool v)async{setState(()=>p2000[place]=v);try{if(v)await disableStreet();await const FlutterSecureStorage().write(key:'rvaz_p2000_$place',value:v?'1':'0');final topic='p2000-$place';if(v){await FirebaseMessaging.instance.subscribeToTopic(topic);}else{await FirebaseMessaging.instance.unsubscribeFromTopic(topic);}await registerDeviceToken();}catch(_){}}
 Future<void>disableStreet()async{streetEnabled=false;await const FlutterSecureStorage().write(key:'rvaz_p2000_street_enabled',value:'0');if(mounted)setState((){});}
 Future<void>saveStreet()async{final place=streetPlace.text.trim(),street=streetName.text.trim();if(place.isEmpty||street.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul zowel een plaats als straatnaam in.')));return;}const st=FlutterSecureStorage();setState(()=>streetEnabled=true);await st.write(key:'rvaz_p2000_street_enabled',value:'1');await st.write(key:'rvaz_p2000_street_place',value:place);await st.write(key:'rvaz_p2000_street_name',value:street);p['emergency112']=false;await st.write(key:'rvaz_push_112',value:'0');try{await FirebaseMessaging.instance.unsubscribeFromTopic('112');}catch(_){}for(final k in p2000.keys){p2000[k]=false;await st.write(key:'rvaz_p2000_$k',value:'0');try{await FirebaseMessaging.instance.unsubscribeFromTopic('p2000-$k');}catch(_){}}await registerDeviceToken();if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Straatfilter opgeslagen: $street, $place')));}}
 Future<void>removeStreet()async{await disableStreet();await registerDeviceToken();}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Meldingen'),backgroundColor:Colors.white,foregroundColor:navy),body:busy?const Center(child:CircularProgressIndicator()):ListView(children:[
 SwitchListTile(value:p['emergency112']??false,onChanged:(v)=>save('emergency112',v),title:const Text('Heel Rotterdam-Rijnmond'),subtitle:const Text('Alle nieuwe P2000-meldingen uit de regio')),
 const Padding(padding:EdgeInsets.fromLTRB(16,12,16,4),child:Text('P2000 per plaats',style:TextStyle(fontWeight:FontWeight.w800,color:navy))),
 for(final e in labels.entries)SwitchListTile(value:p2000[e.key]??false,onChanged:(v)=>saveP2000(e.key,v),title:Text(e.value),subtitle:const Text('Alleen P2000-meldingen voor deze plaats')),
 const Divider(height:1),
 SwitchListTile(value:streetEnabled,onChanged:(v)=>v?saveStreet():removeStreet(),title:const Text('Alleen een bepaalde straat'),subtitle:Text(streetEnabled?'Straatfilter is actief':'Ontvang alleen P2000 als plaats én straatnaam in de melding staan')),
 Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Column(children:[
  TextField(controller:streetPlace,decoration:const InputDecoration(labelText:'Plaats',hintText:'Bijv. Hellevoetsluis')),
  const SizedBox(height:8),
  TextField(controller:streetName,decoration:const InputDecoration(labelText:'Straatnaam',hintText:'Bijv. Rijksstraatweg')),
  const SizedBox(height:10),
  SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saveStreet,icon:const Icon(Icons.notifications_active_outlined),label:const Text('Straatfilter opslaan'))),
  const SizedBox(height:4),
  const Text('Werkt alleen wanneer de plaats en straatnaam in het oorspronkelijke P2000-bericht staan.',style:TextStyle(fontSize:12,color:Colors.black54))
 ])),
 const Divider(height:1),
 for(final e in {'breaking':'Breaking nieuws','news':'Nieuws','traffic':'Verkeer','agenda':'Agenda','weekblad':'Weekblad'}.entries)SwitchListTile(value:p[e.key]??true,onChanged:(v)=>save(e.key,v),title:Text(e.value))
 ]));}
