import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart';
import 'package:app_links/app_links.dart';
import 'vouchers_business.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const site = 'https://regiovoorneaanzee.nl';

const admobBannerId='ca-app-pub-1599023671130671/1026724281';
final adConsentReady=ValueNotifier<bool>(false);
Future<void> initializeAdMob() async {
  // iOS: do not start Google Mobile Ads until its native App ID is configured.
  // Starting the SDK without GADApplicationIdentifier terminates the iOS app.
  if (Platform.isIOS) return;
  await MobileAds.instance.initialize();
  final params=ConsentRequestParameters();
  ConsentInformation.instance.requestConsentInfoUpdate(params,() {
    ConsentForm.loadAndShowConsentFormIfRequired((_) async {
      adConsentReady.value=await ConsentInformation.instance.canRequestAds();
    });
  },(_) async {
    adConsentReady.value=await ConsentInformation.instance.canRequestAds();
  });
}
class RvazAdBanner extends StatefulWidget{const RvazAdBanner({super.key});@override State<RvazAdBanner> createState()=>_RvazAdBannerState();}
class _RvazAdBannerState extends State<RvazAdBanner>{
 BannerAd? ad;
 @override void initState(){super.initState();adConsentReady.addListener(_sync);_sync();}
 void _sync(){if(adConsentReady.value&&ad==null){final a=BannerAd(adUnitId:admobBannerId,size:AdSize.banner,request:const AdRequest(),listener:BannerAdListener(onAdLoaded:(x){if(mounted)setState(()=>ad=x as BannerAd);},onAdFailedToLoad:(x,_){x.dispose();}));a.load();}}
 @override void dispose(){adConsentReady.removeListener(_sync);ad?.dispose();super.dispose();}
 @override Widget build(BuildContext context){final a=ad;if(a==null)return const SizedBox.shrink();return SizedBox(width:a.size.width.toDouble(),height:a.size.height.toDouble(),child:AdWidget(ad:a));}
}

const admobArticleNativeId='ca-app-pub-1599023671130671/4325473914';
class RvazArticleNativeAd extends StatefulWidget{const RvazArticleNativeAd({super.key});@override State<RvazArticleNativeAd> createState()=>_RvazArticleNativeAdState();}
class _RvazArticleNativeAdState extends State<RvazArticleNativeAd>{
 NativeAd? ad;
 @override void initState(){super.initState();adConsentReady.addListener(_sync);_sync();}
 void _sync(){if(adConsentReady.value&&ad==null){final a=NativeAd(adUnitId:admobArticleNativeId,request:const AdRequest(),nativeTemplateStyle:NativeTemplateStyle(templateType:TemplateType.medium),listener:NativeAdListener(onAdLoaded:(x){if(mounted)setState(()=>ad=x as NativeAd);},onAdFailedToLoad:(x,_){x.dispose();}));a.load();}}
 @override void dispose(){adConsentReady.removeListener(_sync);ad?.dispose();super.dispose();}
 @override Widget build(BuildContext context){final a=ad;if(a==null)return const SizedBox.shrink();return SizedBox(width:double.infinity,height:320,child:AdWidget(ad:a));}
}

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
final _voucherLinks=AppLinks();
void _openVoucherUri(Uri uri){final t=(uri.queryParameters['token']??uri.queryParameters['rvaz_voucher_scan']??'').trim();if(t.isNotEmpty)navigatorKey.currentState?.push(MaterialPageRoute(builder:(_)=>VoucherRedeemPage(token:t)));}
Future<void> setupVoucherAppLinks() async {try{final u=await _voucherLinks.getInitialLink();if(u!=null)WidgetsBinding.instance.addPostFrameCallback((_)=>_openVoucherUri(u));}catch(_){} _voucherLinks.uriLinkStream.listen(_openVoucherUri,onError:(_){});}

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
    final wastePush=(await storage.read(key:'rvaz_waste_push'))=='1';
    final wasteBagId=(await storage.read(key:'rvaz_waste_bagid')??'').trim();
    final wastePostcode=(await storage.read(key:'rvaz_waste_postcode')??'').trim();
    final wasteHouse=(await storage.read(key:'rvaz_waste_house')??'').trim();
    final wasteAddition=(await storage.read(key:'rvaz_waste_addition')??'').trim();
    final topics=<String>['all','news','breaking','hellevoetsluis','brielle','rockanje','oostvoorne','verkeer','agenda','weekblad'];
    if(wastePush){topics.add('afval');try{await m.subscribeToTopic('afval');}catch(_){}}else{try{await m.unsubscribeFromTopic('afval');}catch(_){}}
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
    final payload = jsonEncode({'token':token,'device_token':token,'fcm_token':token,'platform':'android','topics':topics,'p2000_street':{'enabled':p2000StreetEnabled&&p2000StreetPlace.isNotEmpty&&p2000StreetName.isNotEmpty,'place':p2000StreetPlace,'street':p2000StreetName},'waste':{'enabled':wastePush&&wasteBagId.isNotEmpty,'bag_id':wasteBagId,'postcode':wastePostcode,'house_number':wasteHouse,'addition':wasteAddition,'reminder':'evening_before'}});
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
  final pushText = [
    data['type'], data['kind'], data['screen'], data['topic'], data['category'],
    data['service'], data['discipline'], data['title'], data['message'],
    message.notification?.title, message.notification?.body,
  ].where((v) => v != null).join(' ').toLowerCase();
  final isP2000 = pushText.contains('p2000') ||
      pushText.contains('112') ||
      data.containsKey('p2000_id') ||
      data.containsKey('p2000');

  if (isP2000) {
    final item = <String,dynamic>{
      ...data,
      'title': data['title'] ?? message.notification?.title ?? data['message'] ?? 'P2000-melding',
      'message': data['message'] ?? message.notification?.body ?? data['title'] ?? '',
      'description': data['description'] ?? message.notification?.body ?? '',
      'incident': data['incident'] ?? data['incident_type'] ?? data['incidentType'] ?? '',
      'melding': data['melding'] ?? data['meldingstekst'] ?? '',
      'original_message': data['original_message'] ?? data['originalMessage'] ?? data['raw_message'] ?? data['rawMessage'] ?? data['cap_message'] ?? data['p2000_message'] ?? '',
      'date': data['date'] ?? data['datetime'] ?? data['published'] ?? data['time'] ?? '',
      'place': data['place'] ?? data['location'] ?? data['city'] ?? '',
      'address': data['address'] ?? data['adres'] ?? data['street'] ?? data['straat'] ?? '',
      'service': data['service'] ?? data['discipline'] ?? data['dienst'] ?? data['agency'] ?? '',
      'unit': data['unit'] ?? data['units'] ?? data['eenheid'] ?? data['eenheden'] ?? data['post'] ?? data['station'] ?? data['kazerne'] ?? data['alarm_receiver'] ?? data['alarmReceiver'] ?? data['receiver'] ?? data['cap_description'] ?? data['capDescription'] ?? data['capcodes'] ?? data['capcode_description'] ?? data['capcodeDescription'] ?? '',
      'capcodes': data['capcodes'] ?? data['capcode'] ?? data['cap_codes'] ?? '',
      'priority': data['priority'] ?? data['prio'] ?? '',
      'body': data['body'] ?? data['details'] ?? data['description'] ?? message.notification?.body ?? '',
    };
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => P2000DetailPage(item: item, traffic: false)));
    return;
  }

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
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final messaging = FirebaseMessaging.instance;
  final initialMessage = await messaging.getInitialMessage();

  // Render eerst de app (en een eventuele P2000-push) en doe netwerk/configuratie daarna.
  // Zo blokkeert een cold start niet op config, topic-abonnementen of tokenregistratie.
  runApp(const RvazApp());
  unawaited(initializeAdMob());
  unawaited(setupVoucherAppLinks());
  FirebaseMessaging.onMessageOpenedApp.listen(openPushMessage);
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => openPushMessage(initialMessage));
  }
  messaging.onTokenRefresh.listen((_) { unawaited(registerDeviceToken()); });

  unawaited(() async {
    await loadConfig();
    final permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (permission.authorizationStatus != AuthorizationStatus.denied) {
      for (final topic in ['all','news','breaking','hellevoetsluis','brielle','rockanje','oostvoorne','verkeer','agenda','weekblad']) {
        try { await messaging.subscribeToTopic(topic); } catch (_) {}
      }
      await registerDeviceToken();
    }
  }());
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
        builder:(context,child)=>SafeArea(top:false,child:child??const SizedBox.shrink()),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class ShellTabController {
  static void Function(String)? _select;
  static void select(String key)=>_select?.call(key);
}
class _ShellState extends State<Shell> {
  int index = 0;
  @override void initState(){super.initState();ShellTabController._select=(key){const keys=['home','news','emergency','agenda','account'];final i=keys.indexOf(key);if(i>=0&&mounted)setState(()=>index=i);};WidgetsBinding.instance.addPostFrameCallback((_)=>maybeAskTesterFeedback(context));}
  @override void dispose(){if(ShellTabController._select!=null)ShellTabController._select=null;super.dispose();}
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
  static const labelMap = <String,String>{'home':'Home','news':'Nieuws','emergency':'112','agenda':'Agenda','account':'Mijn Voorne'};

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
  // WordPress may store literal HTML entities or escaped HTML (for example
  // &lt;div&gt;...&lt;/div&gt;) when editors paste code in a post. Decode
  // those entities before flutter_html renders the article.
  var out = decodeHtmlEntities(html);
  if (RegExp(r'&lt;/?[a-z][^&]*&gt;', caseSensitive:false).hasMatch(out)) {
    out = decodeHtmlEntities(out);
  }
  final markers = <String>['voorlees','responsivevoice','text-to-speech','tts-control'];
  for (final marker in markers) {
    out = out.replaceAll(RegExp('<[^>]*(?:class|id)=[^>]*$marker[^>]*>.*?</(?:div|section|aside|button)>', caseSensitive: false, dotAll: true), '');
  }
  // Strip inline desktop layout styles so WordPress content always fits mobile width.
  out = out.replaceAll(RegExp(r'''\sstyle=("[^"]*"|'[^']*')''', caseSensitive: false), '');
  // Preserve YouTube position as an app marker; ArticlePage renders a real inline player.
  out = out.replaceAllMapped(RegExp(r'''<iframe[^>]+src=["']([^"']*(?:youtube\.com/embed/|youtube-nocookie\.com/embed/)[^"']+)["'][^>]*>\s*</iframe>''',caseSensitive:false,dotAll:true),(m){
    final src=decodeHtmlEntities(m.group(1)??'');
    final uri=Uri.tryParse(src.startsWith('//')?'https:$src':src);
    final parts=uri?.pathSegments??const <String>[];
    final idx=parts.indexOf('embed');
    final id=(idx>=0&&idx+1<parts.length)?parts[idx+1].split('?').first:'';
    return id.isEmpty?'':'<p>[[RVAZ_YOUTUBE:$id]]</p>';
  });
  out = out.replaceAll(RegExp(r'<(?:script|style|iframe|form)[^>]*>.*?</(?:script|style|iframe|form)>', caseSensitive: false, dotAll: true), '');
  out = out.replaceAll(RegExp(r'''\s(?:width|height|align|cellpadding|cellspacing)=("[^"]*"|'[^']*'|[^\s>]+)''', caseSensitive:false), '');
  out = out.replaceAll(RegExp(r'<\/?(?:main|article|section)[^>]*>',caseSensitive:false),'');
  // Let flutter_html size article images from their intrinsic dimensions.
  // Percentage widths collapse to zero in flutter_html 3.x, making images invisible.
  out = out.replaceAll(RegExp(r'<img\b',caseSensitive:false),'<img');
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
        initialData: const <AppAd>[],
        builder: (context, adSnapshot) {
          final ads=adSnapshot.data??[];
          final content=<Widget>[];
          if(blocks.isEmpty){
            content.add(SizedBox(width:double.infinity,child:Html(data:bodyHtml,onLinkTap:(url,attributes,element)async{if(url!=null&&url.trim().isNotEmpty){final u=Uri.tryParse(url.trim());if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);}},style:{'body':Style(margin:Margins.zero,padding:HtmlPaddings.zero,fontSize:FontSize(17),lineHeight:LineHeight(1.55),color:const Color(0xFF202A33)),'figure':Style(margin:Margins.zero),'h1':Style(fontSize:FontSize(28),fontWeight:FontWeight.w900,color:navy),'h2':Style(fontSize:FontSize(24),fontWeight:FontWeight.w900,color:navy),'h3':Style(fontSize:FontSize(20),fontWeight:FontWeight.w800,color:navy)})));
          }else{
            // Korte artikelen: maximaal één advertentie. Langere artikelen krijgen
            // advertenties verspreid door de tekst, met minimaal drie tekstblokken ertussen.
            final adEvery=blocks.length>=10?4:(blocks.length>=6?3:blocks.length);
            var adIndex=0;
            for(var i=0;i<blocks.length;i++){
              final ym=RegExp(r'\[\[RVAZ_YOUTUBE:([A-Za-z0-9_-]+)\]\]').firstMatch(blocks[i]);
              if(ym!=null){content.add(Padding(padding:const EdgeInsets.symmetric(vertical:10),child:RvazYoutubePlayer(videoId:ym.group(1)!)));}
              else{content.add(SizedBox(width:double.infinity,child:Html(data:blocks[i],onLinkTap:(url,attributes,element)async{if(url!=null&&url.trim().isNotEmpty){final u=Uri.tryParse(url.trim());if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);}},style:{'body':Style(margin:Margins.zero,padding:HtmlPaddings.zero,fontSize:FontSize(17),lineHeight:LineHeight(1.55),color:const Color(0xFF202A33)),'figure':Style(margin:Margins.zero),'h1':Style(fontSize:FontSize(28),fontWeight:FontWeight.w900,color:navy),'h2':Style(fontSize:FontSize(24),fontWeight:FontWeight.w900,color:navy),'h3':Style(fontSize:FontSize(20),fontWeight:FontWeight.w800,color:navy)})));}
              final after=i+1;
              final nativePoints=<int>{(blocks.length/2).ceil(),if(blocks.length>=10)(blocks.length*3/4).ceil()};
              if(after<blocks.length&&nativePoints.contains(after)){
                content.add(const SizedBox(height:14));
                content.add(const RvazArticleNativeAd());
                content.add(const SizedBox(height:14));
              }
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
                if(blocks.length<=1)...[
                  const SizedBox(height:14),
                  const RvazArticleNativeAd(),
                ],
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

class RvazYoutubePlayer extends StatefulWidget{final String videoId;const RvazYoutubePlayer({super.key,required this.videoId});@override State<RvazYoutubePlayer> createState()=>_RvazYoutubePlayerState();}
class _RvazYoutubePlayerState extends State<RvazYoutubePlayer>{late final YoutubePlayerController controller;@override void initState(){super.initState();controller=YoutubePlayerController.fromVideoId(videoId:widget.videoId,autoPlay:false,params:const YoutubePlayerParams(showControls:true,showFullscreenButton:true,origin:'https://www.youtube-nocookie.com'));}@override void dispose(){controller.close();super.dispose();}@override Widget build(BuildContext context)=>ClipRRect(borderRadius:BorderRadius.circular(8),child:AspectRatio(aspectRatio:16/9,child:YoutubePlayer(controller:controller)));}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage>{
  late Future<List<dynamic>> posts;
  late Future<List<dynamic>> events;
  late Future<List<AppAd>> ads;
  late Future<List<dynamic>> businesses;
  late Future<Map<String,dynamic>> weather;
  int visibleNews=8;
  @override void initState(){super.initState();_reload();}
  void _reload(){visibleNews=8;posts=_posts();events=_events();ads=loadAppAds(placement:'home');businesses=loadBusinesses();weather=_weather();}
  Future<Map<String,dynamic>> _weather() async {
    try{
      final r=await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=51.8333&longitude=4.1333&current=temperature_2m,weather_code&timezone=Europe%2FAmsterdam')).timeout(const Duration(seconds:8));
      if(r.statusCode==200){final d=jsonDecode(r.body);if(d is Map&&d['current'] is Map)return Map<String,dynamic>.from(d['current']);}
    }catch(_){}
    return <String,dynamic>{};
  }
  String _weatherLabel(int code){if(code==0)return'Helder';if(code<=3)return'Bewolkt';if(code<=48)return'Mist';if(code<=67)return'Regen';if(code<=77)return'Sneeuw';if(code<=82)return'Buien';if(code<=99)return'Onweer';return'Weer';}
  IconData _weatherIcon(int code){if(code==0)return Icons.wb_sunny_outlined;if(code<=3)return Icons.cloud_outlined;if(code<=67)return Icons.grain;if(code<=77)return Icons.ac_unit;if(code<=82)return Icons.umbrella_outlined;if(code<=99)return Icons.thunderstorm_outlined;return Icons.cloud_outlined;}
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
  String clean(dynamic v)=>decodeHtmlEntities('$v'.replaceAll(RegExp(r'<[^>]*>'),''));
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(_reload);await Future.wait([posts,events,ads,businesses,weather]);},child:ListView(padding:EdgeInsets.zero,children:[
    if(appConfig.breakingBanner.trim().isNotEmpty)Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),child:Row(children:[const Icon(Icons.flash_on,size:18,color:Colors.red),const SizedBox(width:7),const Text('BREAKING',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:Colors.red)),const SizedBox(width:8),Expanded(child:Text(appConfig.breakingBanner,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)))])),
    FutureBuilder<Map<String,dynamic>>(future:weather,builder:(context,s){final w=s.data??{};if(w.isEmpty)return const SizedBox.shrink();final temp=(w['temperature_2m'] as num?)?.round(),code=(w['weather_code'] as num?)?.toInt()??0;if(temp==null)return const SizedBox.shrink();return Container(margin:const EdgeInsets.fromLTRB(16,12,16,0),padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),boxShadow:const [BoxShadow(color:Color(0x12000000),blurRadius:8,offset:Offset(0,2))]),child:Row(children:[Icon(_weatherIcon(code),size:28,color:Colors.orange),const SizedBox(width:9),Text('$temp°',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:navy)),const SizedBox(width:8),Expanded(child:Text(_weatherLabel(code),style:const TextStyle(fontSize:12,color:Colors.black54))),const VerticalDivider(),const Icon(Icons.location_on_outlined,size:17,color:cyan),const SizedBox(width:4),const Text('Voorne aan Zee',style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:navy))]));}),
    InkWell(
      onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TodayPage())),
      child:Container(
        width:MediaQuery.sizeOf(context).width,
        height:116,
        margin:const EdgeInsets.only(top:8,bottom:4),
        decoration:BoxDecoration(
          color:const Color(0xFF073B63),
          image:DecorationImage(
            image:NetworkImage(appConfig.homeHeroUrl.trim().isEmpty?defaultRVAZHero:appConfig.homeHeroUrl.trim()),
            fit:BoxFit.cover,
            colorFilter:const ColorFilter.mode(Color(0x66000000),BlendMode.darken),
          ),
        ),
        child:Padding(
          padding:const EdgeInsets.fromLTRB(18,12,18,12),
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            mainAxisAlignment:MainAxisAlignment.center,
            children:[
              const Text('Voorne Vandaag',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
              const SizedBox(height:2),
              const Text('Het laatste nieuws uit de regio',style:TextStyle(color:Colors.white,fontSize:13)),
              const SizedBox(height:8),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:11,vertical:5),
                decoration:BoxDecoration(color:Colors.blue,borderRadius:BorderRadius.circular(16)),
                child:const Row(mainAxisSize:MainAxisSize.min,children:[
                  Text('Bekijk al het nieuws',style:TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700)),
                  SizedBox(width:3),
                  Icon(Icons.chevron_right,color:Colors.white,size:15),
                ]),
              ),
            ],
          ),
        ),
      ),
    ),
    Container(padding:const EdgeInsets.fromLTRB(14,8,14,0),child:GridView.count(crossAxisCount:4,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:4,crossAxisSpacing:6,childAspectRatio:.90,children:[
      _HomeShortcut(icon:Icons.article_outlined,color:Colors.blue,label:'Nieuws',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Nieuws'),backgroundColor:Colors.white,foregroundColor:navy),body:const NewsPage())))),
      _HomeShortcut(icon:Icons.today,color:const Color(0xFF19A84A),label:'Voorne Vandaag',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TodayPage()))),
      _HomeShortcut(icon:Icons.warning_amber_rounded,color:Colors.red,label:'P2000',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EmergencyTrafficPage(initialTraffic:false)))),
      _HomeShortcut(icon:Icons.calendar_month,color:Colors.deepPurple,label:'Agenda',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Agenda'),backgroundColor:Colors.white,foregroundColor:navy),body:const AgendaPage())))),
    ])),
    Padding(
      padding:const EdgeInsets.fromLTRB(16,4,16,8),
      child:Material(
        color:const Color(0xFFEAF4FF),
        borderRadius:BorderRadius.circular(14),
        child:InkWell(
          borderRadius:BorderRadius.circular(14),
          onTap:()=>showModalBottomSheet(context:context,showDragHandle:true,builder:(sheet)=>SafeArea(child:ListView(shrinkWrap:true,children:[
      const ListTile(title:Text('Meer functies',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:navy))),
      ListTile(leading:const Icon(Icons.directions_car,color:Colors.orange),title:const Text('112 & Verkeer'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const EmergencyTrafficPage()));}),
      ListTile(leading:const Icon(Icons.calendar_today,color:Color(0xFF19A84A)),title:const Text('Afvalkalender'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage()));}),
      ListTile(leading:const Icon(Icons.location_on,color:Colors.blue),title:const Text('Plaatsen'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const PlacesPage()));}),
      ListTile(leading:const Icon(Icons.local_parking,color:Colors.blue),title:const Text('Parkeren'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const ParkingPage()));}),
      ListTile(leading:const Icon(Icons.park_outlined,color:Colors.green),title:const Text('Natuur & recreatie'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const RecreationPage()));}),
      ListTile(leading:const Icon(Icons.waves,color:Colors.lightBlue),title:const Text('Strand & kust'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const CoastPage()));}),
      ListTile(leading:const Icon(Icons.star,color:Colors.amber),title:const Text('Favorieten'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const SavedPage()));}),
      ListTile(leading:const Icon(Icons.storefront,color:Colors.deepPurple),title:const Text('Bedrijven'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessesPage()));}),
      ListTile(leading:const Icon(Icons.percent,color:Colors.red),title:const Text('Vouchers'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const MyVouchersPage()));}),
      ListTile(leading:const Icon(Icons.person,color:Colors.blueGrey),title:const Text('Mijn Voorne'),onTap:(){Navigator.pop(sheet);ShellTabController.select('account');}),
      ListTile(leading:const Icon(Icons.campaign,color:Colors.blue),title:const Text('Tip de redactie'),onTap:(){Navigator.pop(sheet);Navigator.push(context,MaterialPageRoute(builder:(_)=>const TipPage()));}),
    ])))
          ,
          child:const Padding(
            padding:EdgeInsets.symmetric(horizontal:16,vertical:13),
            child:Row(children:[
              Icon(Icons.apps,color:navy),
              SizedBox(width:10),
              Expanded(child:Text('Meer functies',style:TextStyle(color:navy,fontSize:16,fontWeight:FontWeight.w900))),
              Icon(Icons.chevron_right,color:navy),
            ]),
          ),
        ),
      ),
    ),
    const Center(child:RvazAdBanner()),
    FutureBuilder<Map<String,dynamic>>(future:_editorialCapabilities(),builder:(context,s){if(s.data?['can_submit_news']!=true)return const SizedBox.shrink();return Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.edit_note)),title:const Text('Nieuws insturen',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Voor redactieleden · ter goedkeuring door de eindredactie'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EditorialSubmitPage())))));}),
    Padding(padding:const EdgeInsets.fromLTRB(16,12,16,0),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('Laatste nieuws uit Voorne aan Zee',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:navy))),TextButton(style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:4),minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Nieuws'),backgroundColor:Colors.white,foregroundColor:navy),body:const NewsPage()))),child:const Row(mainAxisSize:MainAxisSize.min,children:[Text('Meer laden',style:TextStyle(fontSize:11)),Icon(Icons.chevron_right,size:15)]))]),
      FutureBuilder<List<dynamic>>(future:posts,builder:(context,s){final all=s.data??[];if(all.isEmpty)return const SizedBox.shrink();final x=all.take(visibleNews).toList();final p=x.first;return Column(children:[
        Card(clipBehavior:Clip.antiAlias,margin:EdgeInsets.zero,child:InkWell(onTap:()=>openArticle(context,p),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(postImage(p).isNotEmpty)Image.network(postImage(p),height:150,width:double.infinity,fit:BoxFit.cover),Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(clean(p['title'] is Map?p['title']['rendered']:p['title']??''),style:const TextStyle(color:navy,fontSize:17,height:1.15,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(formatPostDate(p),style:const TextStyle(fontSize:10,color:Colors.black54))]))]))),
        const SizedBox(height:8),...x.skip(1).map((p)=>Card(margin:const EdgeInsets.only(bottom:7),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:3),leading:postImage(p).isEmpty?null:ClipRRect(borderRadius:BorderRadius.circular(5),child:Image.network(postImage(p),width:76,height:56,fit:BoxFit.cover)),title:Text(clean(p['title'] is Map?p['title']['rendered']:p['title']??''),maxLines:2,style:const TextStyle(fontWeight:FontWeight.w800,color:navy,fontSize:13)),subtitle:Text(formatPostDate(p),style:const TextStyle(fontSize:10)),trailing:const Icon(Icons.chevron_right,color:navy),onTap:()=>openArticle(context,p)))),
        if(visibleNews<all.length)OutlinedButton.icon(onPressed:()=>setState(()=>visibleNews=(visibleNews+8).clamp(1,all.length)),icon:const Icon(Icons.expand_more),label:const Text('Meer laden')),
      ]);}),
    ])),
    FutureBuilder<List<dynamic>>(future:businesses,builder:(context,s){final pros=(s.data??[]).where(_businessIsPro).take(3).toList();if(pros.isEmpty)return const SizedBox.shrink();return Padding(padding:const EdgeInsets.fromLTRB(16,14,16,4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Uitgelichte PRO-bedrijven',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy)),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessesPage())),child:const Text('Bekijk alle →'))]),
      SizedBox(height:142,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:pros.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,i){final e=pros[i];String bv(String k)=>e is Map?(e[k]?.toString()??''):'';final img=bv('image');return SizedBox(width:145,child:Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessDetailPage(item:e))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Stack(fit:StackFit.expand,children:[img.isEmpty?const Center(child:Icon(Icons.storefront,size:36)):Image.network(img,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.storefront,size:36))),Positioned(top:5,right:5,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:Colors.blue,borderRadius:BorderRadius.circular(5)),child:const Text('PRO',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))))])),Padding(padding:const EdgeInsets.all(7),child:Text(clean(bv('title')),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:navy)))]))));})),
    ]));}),
    Padding(padding:const EdgeInsets.fromLTRB(16,10,16,22),child:Column(children:[RotatingAppAd(future:ads),const SizedBox(height:10),Card(child:ListTile(leading:const Icon(Icons.photo_camera_outlined,color:navy),title:const Text('Tip de redactie',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TipPage()))))]))
  ]));
}
class _HomeShortcut extends StatelessWidget{
  final IconData icon;final Color color;final String label;final VoidCallback? onTap;
  const _HomeShortcut({required this.icon,required this.color,required this.label,this.onTap});
  @override Widget build(BuildContext context)=>Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.symmetric(vertical:7,horizontal:2),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:42,height:42,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(8)),child:Icon(icon,color:Colors.white,size:24)),const SizedBox(height:7),Text(label,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,height:1.05,fontWeight:FontWeight.w800,color:navy))]))));
}

Future<void> _openExternal(String url)async{final u=Uri.tryParse(url);if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);}
Future<void> _mapSearch(String query)=>_openExternal('https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(query)}');
class ParkingPage extends StatelessWidget {
 const ParkingPage({super.key});
 static const areas=<List<String>>[['Hellevoetsluis','Vesting, centrum en winkelgebieden'],['Brielle','Vesting en centrum'],['Rockanje','Centrum en strand'],['Oostvoorne','Centrum, strand en natuur']];
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Parkeren'),backgroundColor:Colors.white,foregroundColor:navy,actions:const [PageFeedbackButton(page:'Parkeren')]),body:ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFEAF4FF),borderRadius:BorderRadius.circular(18)),child:const Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Parkeren op Voorne',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),SizedBox(height:5),Text('Kies een plaats voor parkeerlocaties en route.',style:TextStyle(color:Colors.black54))])),Icon(Icons.local_parking,color:navy,size:42)])),const SizedBox(height:12),
  ...areas.map((s)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.local_parking)),title:Text(s[0],style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text(s[1]),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ParkingAreaPage(place:s[0])))))),
  const Center(child:RvazAdBanner()),
 ]));
}
class ParkingAreaPage extends StatelessWidget {
 final String place; const ParkingAreaPage({super.key,required this.place});
 static const locations=<String,List<List<String>>>{
  'Hellevoetsluis':[['Struytse Hoeck','Winkelcentrum'],['Kanaalweg Westzijde','Vesting en haven'],['Zuidfront','Vesting'],['Woordbouwerplein','Centrum'],['Veerhaven','Havengebied']],
  'Brielle':[['Centrum / vesting','Historisch centrum'],['Thoelaverweg','Rand van de vesting']],
  'Rockanje':[['Eerste Slag','Strand'],['Tweede Slag','Strand'],['Centrum Rockanje','Centrum']],
  'Oostvoorne':[['Oostvoornse Meer','Recreatie'],['Strand Oostvoorne','Strand en natuur'],['Centrum Oostvoorne','Centrum']],
 };
 @override Widget build(BuildContext context){final list=locations[place]??const <List<String>>[];return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text('Parkeren $place'),backgroundColor:Colors.white,foregroundColor:navy),body:ListView(padding:const EdgeInsets.all(16),children:[
  Text('Parkeren in $place',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),const Text('Bekijk parkeerplaatsen en open alleen voor de route Google Maps.'),const SizedBox(height:12),
  ...list.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.local_parking)),title:Text(p[0],style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text(p[1]),trailing:OutlinedButton.icon(icon:const Icon(Icons.directions,size:18),label:const Text('Route'),onPressed:()=>_mapSearch('${p[0]}, ${place}, Nederland'))))),
  const Center(child:RvazAdBanner()),
 ]));}
}
class RecreationPage extends StatelessWidget {
 const RecreationPage({super.key});
 static const places=<List<String>>[['Rockanje','Duinen, strand en wandelroutes'],['Oostvoorne','Duinen, meer en natuur'],['Hellevoetsluis','Natuur, kust en recreatie'],['Brielle','Meer, groen en fietsroutes']];
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Natuur & recreatie'),backgroundColor:Colors.white,foregroundColor:navy,actions:const [PageFeedbackButton(page:'Natuur & recreatie')]),body:ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFEAF4FF),borderRadius:BorderRadius.circular(18)),child:const Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Natuur & routes',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),SizedBox(height:5),Text('Kies eerst een plaats en ontdek wat er te doen is.',style:TextStyle(color:Colors.black54))])),Icon(Icons.park_outlined,color:navy,size:42)])),const SizedBox(height:12),
  ...places.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.park_outlined)),title:Text(p[0],style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text(p[1]),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>RecreationAreaPage(place:p[0])))))),
  const Center(child:RvazAdBanner()),
 ]));
}
class RecreationAreaPage extends StatelessWidget {
 final String place; const RecreationAreaPage({super.key,required this.place});
 static const data=<String,List<List<String>>>{
  'Rockanje':[['Voornes Duin','Natuurgebied','Duinen, bos en wandelpaden.'],['Tenellaplas','Natuurgebied','Wandelen rond duinmeer en bezoekerscentrum.'],['De Pan','Wandelroute · ca. 2,9 km','Wandelroute door Voornes Duin.'],['Breede Water','Wandelroute · ca. 3 km','Route door duinlandschap rond het Breede Water.'],['Strypemonde','Wandelroute · ca. 5 km','Bos- en duinroute bij Rockanje.']],
  'Oostvoorne':[['Voornes Duin','Natuurgebied','Duinen, bos en kustnatuur.'],['Oostvoornse Meer','Recreatiegebied','Wandelen, fietsen en watersport rond het meer.'],['Groene Strand','Natuurgebied','Bijzonder kust- en natuurgebied.']],
  'Hellevoetsluis':[['Quackjeswater','Natuurgebied','Bos en water met wandelmogelijkheden.'],['Quackjeswaterroute','Wandelroute · ca. 3 km','Wandeling door het natuurgebied.'],['Haringvliet','Kust & recreatie','Wandelen en fietsen langs het water.']],
  'Brielle':[['Brielse Meer','Recreatiegebied','Fietsen en wandelen langs het meer.'],['Vestingroute','Wandel- en fietsgebied','Routes rond de vesting en het buitengebied.']],
 };
 @override Widget build(BuildContext context){final items=data[place]??const <List<String>>[];return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text('Natuur in $place'),backgroundColor:Colors.white,foregroundColor:navy),body:ListView(padding:const EdgeInsets.all(16),children:[
  Text(place,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:5),const Text('Natuurgebieden en routes. Open Maps alleen wanneer je erheen wilt.'),const SizedBox(height:12),
  ...items.map((e)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Row(children:[
            const Icon(Icons.park_outlined,color:navy),
            const SizedBox(width:10),
            Expanded(child:Text(e[0],style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:navy))),
          ]),
          const SizedBox(height:6),
          Text(e[1],style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:4),
          Text(e[2]),
          const SizedBox(height:10),
          Align(
            alignment:Alignment.centerRight,
            child:OutlinedButton.icon(
              onPressed:()=>_mapSearch('${e[0]}, ${place}, Nederland'),
              icon:const Icon(Icons.directions),
              label:const Text('Route'),
            ),
          ),
        ],
      ),
    ),
  )),
  const Center(child:RvazAdBanner()),
 ]));}
}
class CoastPage extends StatefulWidget {const CoastPage({super.key});@override State<CoastPage> createState()=>_CoastPageState();}
class _CoastPageState extends State<CoastPage> {
  late Future<Map<String,dynamic>> future;
  @override void initState(){super.initState();future=load();}
  Future<Map<String,dynamic>> load()async{
    final out=<String,dynamic>{};
    try{final r=await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=51.87&longitude=4.06&current=temperature_2m,wind_speed_10m,wind_direction_10m,weather_code&wind_speed_unit=kmh&timezone=Europe%2FAmsterdam')).timeout(const Duration(seconds:12));if(r.statusCode==200)out['weather']=jsonDecode(r.body)['current'];}catch(_){}
    try{final r=await http.get(Uri.parse('https://marine-api.open-meteo.com/v1/marine?latitude=51.87&longitude=4.06&current=wave_height,wave_direction,wave_period,sea_surface_temperature&timezone=Europe%2FAmsterdam')).timeout(const Duration(seconds:12));if(r.statusCode==200)out['marine']=jsonDecode(r.body)['current'];}catch(_){}
    return out;
  }
  String value(dynamic x,[String unit=''])=>x==null?'—':'$x$unit';
  Widget stat(IconData icon,String label,String value)=>SizedBox(width:130,child:Row(children:[Icon(icon,color:navy),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:12,color:Colors.black54)),Text(value,style:const TextStyle(fontWeight:FontWeight.w900,color:navy))]))]));
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFFF7F9FB),
    appBar:AppBar(title:const Text('Strand & kust'),backgroundColor:Colors.white,foregroundColor:navy,actions:const [PageFeedbackButton(page:'Strand & kust')]),
    body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      final d=snapshot.data??<String,dynamic>{};
      final w=d['weather'] is Map?Map<String,dynamic>.from(d['weather'] as Map):<String,dynamic>{};
      final m=d['marine'] is Map?Map<String,dynamic>.from(d['marine'] as Map):<String,dynamic>{};
      return RefreshIndicator(onRefresh:()async{setState(()=>future=load());await future;},child:ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFEAF4FF),borderRadius:BorderRadius.circular(18)),child:const Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Strand & kust',style:TextStyle(color:navy,fontSize:24,fontWeight:FontWeight.w900)),SizedBox(height:5),Text('Actuele omstandigheden bij de kust van Rockanje.',style:TextStyle(color:Colors.black54))])),Icon(Icons.waves,color:navy,size:42)])),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Wrap(spacing:24,runSpacing:16,children:[stat(Icons.thermostat,'Lucht',value(w['temperature_2m'],' °C')),stat(Icons.air,'Wind',value(w['wind_speed_10m'],' km/u')),stat(Icons.water,'Zeewater',value(m['sea_surface_temperature'],' °C')),stat(Icons.waves,'Golven',value(m['wave_height'],' m'))]))),
        Card(child:ListTile(leading:const Icon(Icons.water_outlined,color:navy),title:const Text('Kustcondities',style:TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:Text('Golven: ${value(m['wave_height'],' m')}  •  periode: ${value(m['wave_period'],' s')}  •  richting: ${value(m['wave_direction'],'°')}'))),
        Card(child:ListTile(leading:const Icon(Icons.info_outline,color:navy),title:const Text('Strandinformatie',style:TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:const Text('Actuele lucht-, wind-, zee- en golfgegevens staan hierboven direct in RVAZ. Officiële waarschuwingen en getijden worden pas getoond zodra die betrouwbaar als data in de app beschikbaar zijn.'))),
        const Center(child:RvazAdBanner()),
      ]));
    }),
  );
}
class MyVoornePage extends StatefulWidget{const MyVoornePage({super.key});@override State<MyVoornePage> createState()=>_MyVoornePageState();}
class _MyVoornePageState extends State<MyVoornePage>{String place='',street='';@override void initState(){super.initState();load();}Future<void> load()async{const st=FlutterSecureStorage();final p=await st.read(key:'rvaz_neighborhood_place')??'';final s=await st.read(key:'rvaz_neighborhood_street')??'';if(mounted)setState((){place=p;street=s;});}@override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Mijn Voorne')),body:ListView(padding:const EdgeInsets.all(16),children:[Text(place.isEmpty?'Mijn Voorne':place,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),if(street.isNotEmpty)Text(street,style:const TextStyle(color:Colors.black54)),const SizedBox(height:12),Card(child:ListTile(leading:const Icon(Icons.home_outlined,color:navy),title:const Text('Mijn adres',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(place.isEmpty?'Nog geen adres ingesteld':'$street${street.isNotEmpty?', ':''}$place'),trailing:const Icon(Icons.edit),onTap:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage()));await load();})),Card(child:ListTile(leading:const Icon(Icons.newspaper,color:navy),title:const Text('Nieuws uit mijn plaats'),trailing:const Icon(Icons.chevron_right),onTap:place.isEmpty?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PlaceNewsPage(place:place))))),Card(child:ListTile(leading:const Icon(Icons.bookmark_outline,color:navy),title:const Text('Mijn favorieten'),subtitle:const Text('Opgeslagen nieuwsberichten'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SavedPage())))),Card(child:ListTile(leading:const Icon(Icons.event_outlined,color:navy),title:const Text('Agenda'),subtitle:Text(place.isEmpty?'Activiteiten op Voorne':'Activiteiten rond $place'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AgendaPage())))),Card(child:ListTile(leading:const Icon(Icons.delete_outline,color:navy),title:const Text('Afval & adres'),subtitle:const Text('Ophaalmomenten en adres wijzigen'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage())))),Card(child:ListTile(leading:const Icon(Icons.notifications_outlined,color:navy),title:const Text('Meldingsvoorkeuren'),subtitle:const Text('Beheer meldingen via Mijn RVAZ'),trailing:const Icon(Icons.chevron_right),onTap:(){Navigator.pop(context);ShellTabController.select('account');})),const Center(child:RvazAdBanner())]));}

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

String formatP2000Date(dynamic raw) {
  final value='${raw??''}'.trim();
  final parsed=DateTime.tryParse(value)?.toLocal();
  if(parsed==null)return value;
  final d=parsed;
  const months=['','jan','feb','mrt','apr','mei','jun','jul','aug','sep','okt','nov','dec'];
  final now=DateTime.now();
  final today=DateTime(now.year,now.month,now.day),day=DateTime(d.year,d.month,d.day);
  final diff=today.difference(day).inDays;
  final hh=d.hour.toString().padLeft(2,'0'),mm=d.minute.toString().padLeft(2,'0');
  if(diff==0)return 'Vandaag · $hh:$mm';
  if(diff==1)return 'Gisteren · $hh:$mm';
  return '${d.day} ${months[d.month]} · $hh:$mm';
}

String p2000PriorityLabel(dynamic item) {
  if (item is! Map) return '';
  final raw = [item['priority'],item['prio'],item['incident'],item['incident_type'],item['melding'],item['meldingstekst'],item['original_message'],item['raw_message'],item['cap_message'],item['p2000_message'],item['title'],item['message'],item['description'],item['body']].where((v)=>v!=null).join(' ').toUpperCase();
  final code=RegExp(r'\\b(P[12]|A[12])\\b').firstMatch(raw)?.group(1)??'';
  if(code=='P1'||code=='A1')return '$code · SPOED';
  if(code=='P2'||code=='A2')return '$code · Geen spoed';
  return code;
}

String p2000DisplayTitle(dynamic item) {
  if(item is! Map)return 'Melding';

  String text(dynamic value) {
    if(value==null)return '';
    if(value is Map){
      for(final key in ['rendered','text','message','description','title','name']){
        final nested=value[key];
        if(nested!=null&&'$nested'.trim().isNotEmpty)return '$nested'.trim().replaceAll(RegExp(r'<[^>]*>'),'');
      }
      return '';
    }
    if(value is List)return value.map(text).where((x)=>x.isNotEmpty).join(' · ');
    return '$value'.trim().replaceAll(RegExp(r'<[^>]*>'),'');
  }

  // Prefer the actual incident/P2000 text over a generic app-generated title.
  for(final key in [
    'incident','incident_type','incidentType','event','event_type','eventType',
    'melding','meldingstekst','incident_description','incidentDescription',
    'original_message','originalMessage','raw_message','rawMessage','cap_message',
    'p2000_message','p2000Message','text','body','details','description','message'
  ]){
    final value=text(item[key]);
    if(value.isNotEmpty)return value;
  }

  final title=text(item['title']);
  return title.isEmpty?'Melding':title;
}

Widget p2000ServiceIcon(dynamic item,{double size=24}) {
  if(item is! Map)return Icon(Icons.warning_amber_rounded,color:Colors.red,size:size);
  final text=[
    item['service'],item['discipline'],item['dienst'],item['agency'],
    item['incident'],item['incident_type'],item['incidentType'],
    item['melding'],item['meldingstekst'],item['original_message'],item['originalMessage'],
    item['raw_message'],item['rawMessage'],item['cap_message'],item['p2000_message'],
    item['title'],item['message'],item['description'],item['body']
  ].where((v)=>v!=null).join(' ').toLowerCase();
  if(text.contains('lifeliner')||text.contains('traumaheli')||text.contains('traumahelikopter')||text.contains('mobiel medisch team')||RegExp(r'\\bmmt\\b').hasMatch(text))return Text('🚁',style:TextStyle(fontSize:size));
  if(text.contains('brandweer')||RegExp(r'\\bbrw\\b').hasMatch(text)||RegExp(r'\\bbrt(?:-\\d+)?\\b').hasMatch(text))return Text('🚒',style:TextStyle(fontSize:size));
  if(text.contains('ambulance')||RegExp(r'\\bambu\\b').hasMatch(text))return Text('🚑',style:TextStyle(fontSize:size));
  if(text.contains('politie'))return Text('🚓',style:TextStyle(fontSize:size));
  return Icon(Icons.warning_amber_rounded,color:Colors.red,size:size);
}

String _ndwXmlText(String raw)=>raw.replaceAll(RegExp(r'<[^>]+>'),' ').replaceAll('&amp;','&').replaceAll('&quot;','"').replaceAll('&apos;',"'").replaceAll(RegExp(r'\s+'),' ').trim();

String _ndwTag(String block,List<String> names){
  for(final name in names){
    final escaped=RegExp.escape(name);
    final m=RegExp('<(?:[A-Za-z0-9_]+:)?$escaped[^>]*>([\\s\\S]*?)</(?:[A-Za-z0-9_]+:)?$escaped>',caseSensitive:false).firstMatch(block);
    if(m!=null){final v=_ndwXmlText(m.group(1)??'');if(v.isNotEmpty)return v;}
  }
  return '';
}

String _ndwElementBlock(String block,String name){
  final e=RegExp.escape(name);
  return RegExp('<(?:[A-Za-z0-9_]+:)?$e[^>]*>[\\\\s\\\\S]*?</(?:[A-Za-z0-9_]+:)?$e>',caseSensitive:false).firstMatch(block)?.group(0)??'';
}

String _ndwHuman(String raw)=>raw
    .replaceFirst(RegExp(r'^[A-Za-z0-9_]+:'),'')
    .replaceAll(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'),' ')
    .replaceAll('_',' ')
    .trim();

String _ndwRecordType(String block){
  final open=RegExp(r'<(?:[A-Za-z0-9_]+:)?situationRecord\b[^>]*>',caseSensitive:false).firstMatch(block)?.group(0)??'';
  final type=RegExp(r'(?:xsi:)?type\s*=\s*"([^"]+)"',caseSensitive:false).firstMatch(open)?.group(1)??'';
  return _ndwHuman(type);
}

String _ndwNl(String raw){
  const m=<String,String>{'slow Traffic':'Langzaam rijdend verkeer','stationary Traffic':'Stilstaand verkeer','bridge Swing In Operation':'Brug geopend voor scheepvaart','Road Or Carriageway Or Lane Management':'Rijbaan- of rijstrookmaatregel','other':'Overige verkeersmelding'};
  return m[raw]??raw;
}


Future<List<dynamic>> loadNdwTraffic()async{
  final r=await http.get(Uri.parse('https://opendata.ndw.nu/actueel_beeld.xml.gz'),headers:const {'Accept':'application/gzip, application/xml'}).timeout(const Duration(seconds:20));
  if(r.statusCode!=200)throw Exception('NDW HTTP ${r.statusCode}');
  final xml=utf8.decode(gzip.decode(r.bodyBytes),allowMalformed:true);
  final situations=RegExp(r'<(?:[A-Za-z0-9_]+:)?situation\b[\s\S]*?</(?:[A-Za-z0-9_]+:)?situation>',caseSensitive:false).allMatches(xml);
  final out=<dynamic>[];
  const localWords=['n57','n218','hellevoetsluis','rockanje','brielle','oostvoorne','oudenhoorn','nieuwenhoorn','tinte','vierpolders','zwartewaal','abbenbroek','heenvliet','geervliet','zuidland','simonshaven','voorne','haringvlietdam','hartelbrug','spijkenisserbrug','spijkenisse','botlek','europoort','maasvlakte'];
  for(final sm in situations){
    final situationBlock=sm.group(0)??'';
    final recordMatches=RegExp(r'<(?:[A-Za-z0-9_]+:)?situationRecord\b[\s\S]*?</(?:[A-Za-z0-9_]+:)?situationRecord>',caseSensitive:false).allMatches(situationBlock).toList();
    final recordBlocks=recordMatches.isEmpty?<String>[situationBlock]:recordMatches.map((m)=>m.group(0)??'').where((b)=>b.isNotEmpty).toList();
    for(final block in recordBlocks){
    final plain=_ndwXmlText(block),lower=plain.toLowerCase();
    final lats=RegExp(r'<(?:[A-Za-z0-9_]+:)?latitude[^>]*>\s*([0-9.]+)',caseSensitive:false).allMatches(block).map((m)=>double.tryParse(m.group(1)??'')).whereType<double>().toList();
    final lons=RegExp(r'<(?:[A-Za-z0-9_]+:)?longitude[^>]*>\s*([0-9.]+)',caseSensitive:false).allMatches(block).map((m)=>double.tryParse(m.group(1)??'')).whereType<double>().toList();
    if(lats.isEmpty||lons.isEmpty){
      final pos=RegExp(r'<(?:[A-Za-z0-9_]+:)?posList[^>]*>([^<]+)',caseSensitive:false).firstMatch(block)?.group(1)??'';
      final coords=pos.trim().split(RegExp(r'\s+')).map(double.tryParse).whereType<double>().toList();
      if(coords.length>=2){lats.add(coords[0]);lons.add(coords[1]);}
    }
    var local=localWords.any(lower.contains);
    for(var i=0;!local&&i<lats.length&&i<lons.length;i++){if(lats[i]>=51.72&&lats[i]<=52.08&&lons[i]>=3.82&&lons[i]<=4.62)local=true;}
    if(!local)continue;
    final roadTag=_ndwTag(block,['roadNumber','roadName','roadIdentifier']);
    final road=roadTag.isNotEmpty?roadTag:RegExp(r'\b(?:[AN]\d{1,3})\b',caseSensitive:false).firstMatch(plain)?.group(0)?.toUpperCase()??'';
    final comment=_ndwTag(block,['comment','situationRecordDescription','description','causeDescription']);
    final codedType=_ndwTag(block,['accidentType','obstructionType','roadMaintenanceType','maintenanceWorksType','constructionWorkType','generalNetworkManagementType','trafficConstrictionType','abnormalTrafficType','vehicleObstructionType','environmentalObstructionType','poorEnvironmentType','animalPresenceType','disturbanceActivityType','publicEventType']);
    final recordType=_ndwRecordType(block);
    final type=_ndwNl(_ndwHuman(codedType.isNotEmpty?codedType:recordType));
    final location=_ndwTag(block,['alertCLocationName','locationName','roadName','fromPointName','toPointName','tpegAreaDescriptor','tpegPointDescriptor','descriptor']);
    final primaryBlock=_ndwElementBlock(block,'alertCMethod4PrimaryPointLocation');
    final secondaryBlock=_ndwElementBlock(block,'alertCMethod4SecondaryPointLocation');
    final primaryLocation=_ndwTag(primaryBlock,['alertCLocationName']);
    final secondaryLocation=_ndwTag(secondaryBlock,['alertCLocationName']);
    final alertCLocations=<String>[primaryLocation,secondaryLocation].where((v)=>v.isNotEmpty).toSet().toList();
    final resolvedLocation=alertCLocations.isEmpty?location:alertCLocations.join(' – ');
    final direction=_ndwNl(_ndwHuman(_ndwTag(block,['alertCDirectionCoded','alertCAffectedDirection','directionBoundOnLinearSection','directionRelativeOnLinearSection','directionRelativeAtPoint'])));
    final delay=_ndwTag(block,['delayTimeValue','minimumDelay','maximumDelay']);
    final queue=_ndwTag(block,['queueLength','trafficStatusValue']);
    final start=_ndwTag(block,['overallStartTime','situationRecordCreationTime']);
    final end=_ndwTag(block,['overallEndTime']);
    final place=resolvedLocation.isNotEmpty?resolvedLocation:localWords.firstWhere((x)=>lower.contains(x),orElse:()=>road.toLowerCase());
    final label=comment.isNotEmpty?comment:(type.isNotEmpty?type:'Actuele verkeersmelding');
    final details=<String>[
      if(type.isNotEmpty&&type.toLowerCase()!=label.toLowerCase())'Type: $type',
      if(road.isNotEmpty)'Weg: $road',
      if(resolvedLocation.isNotEmpty&&resolvedLocation.toLowerCase()!=road.toLowerCase())'Locatie: $resolvedLocation',
      if(direction.isNotEmpty)'Richting: $direction',
      if(delay.isNotEmpty)'Vertraging: ${double.tryParse(delay)==null?delay:'${(double.parse(delay)/60).round()} minuten'}',
      if(queue.isNotEmpty&&!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(queue))'Verkeer: ${_ndwNl(_ndwHuman(queue))}',
      if(end.isNotEmpty)'Eindtijd: ${DateTime.tryParse(end)?.toLocal().toString().substring(0,16).replaceFirst('T',' ')??end}',
    ];
    final body=details.join('\n');
    out.add(<String,dynamic>{'title':road.isEmpty?label:'$road · $label','description':body.isEmpty?label:body,'message':label,'body':body,'date':start,'end':end,'place':place,'source':'NDW','latitude':lats.isEmpty?null:lats.first,'longitude':lons.isEmpty?null:lons.first});
    }
  }
  out.sort((a,b)=>'${b['date']??''}'.compareTo('${a['date']??''}'));
  return out;
}

class EmergencyTrafficPage extends StatefulWidget{final bool initialTraffic;final String initialPlace;const EmergencyTrafficPage({super.key,this.initialTraffic=false,this.initialPlace=''});@override State<EmergencyTrafficPage> createState()=>_EmergencyTrafficPageState();}
class _EmergencyTrafficPageState extends State<EmergencyTrafficPage>{
 String place='Voorne aan Zee';bool traffic=false;late Future<List<dynamic>> items;
 static const p2000Places=['Voorne aan Zee','Hellevoetsluis','Rockanje','Brielle','Oostvoorne','Oudenhoorn','Nieuwenhoorn','Tinte','Vierpolders','Zwartewaal','Abbenbroek','Heenvliet','Geervliet','Zuidland','Simonshaven','Rotterdam-Rijnmond'];
 @override void initState(){super.initState();traffic=widget.initialTraffic;if(widget.initialPlace.isNotEmpty&&p2000Places.contains(widget.initialPlace))place=widget.initialPlace;items=load();}
 String hay(dynamic e)=>[e is Map?e['title']:'',e is Map?e['description']:'',e is Map?e['message']:'',e is Map?e['body']:'',e is Map?e['place']:'',e is Map?e['location']:'',e is Map?e['city']:''].join(' ').toLowerCase();
 Future<List<dynamic>>load()async{
   if(traffic){try{return await loadNdwTraffic();}catch(e){debugPrint('NDW verkeer: $e');return <dynamic>[];}}
   final region=Uri.encodeQueryComponent('Rotterdam-Rijnmond');
   final primary=await RvazApi.firstList(
     ['p2000?region=$region&per_page=250','112?region=$region&per_page=250','meldingen?region=$region&per_page=250'],
     keys:const ['meldingen','p2000','112','items','data'],
   );
   if(primary.isNotEmpty)return primary;
   for(final type in ['rvaz_p2000','rvaz_112','p2000']){try{final r=await http.get(Uri.parse('$site/wp-json/wp/v2/$type?per_page=100&_embed=1')).timeout(const Duration(seconds:10));if(r.statusCode==200){final x=RvazApi.list(jsonDecode(r.body));if(x.isNotEmpty)return x;}}catch(_){}}
   return <dynamic>[];
 }
 bool trafficNearPlace(dynamic e,String selected){
   if(e is! Map)return false;
   final lat=(e['latitude'] as num?)?.toDouble(),lon=(e['longitude'] as num?)?.toDouble();
   if(lat==null||lon==null)return false;
   const centers=<String,LatLng>{
     'Hellevoetsluis':LatLng(51.8333,4.1333),'Rockanje':LatLng(51.8717,4.0708),'Brielle':LatLng(51.9017,4.1625),
     'Oostvoorne':LatLng(51.9125,4.0986),'Oudenhoorn':LatLng(51.8270,4.1910),'Nieuwenhoorn':LatLng(51.8540,4.1430),
     'Tinte':LatLng(51.8860,4.1360),'Vierpolders':LatLng(51.8790,4.1790),'Zwartewaal':LatLng(51.8830,4.2200),
     'Abbenbroek':LatLng(51.8490,4.2430),'Heenvliet':LatLng(51.8640,4.2440),'Geervliet':LatLng(51.8610,4.2640),
     'Zuidland':LatLng(51.8220,4.2590),'Simonshaven':LatLng(51.8230,4.2880),
   };
   final center=centers[selected];if(center==null)return false;
   return const Distance().as(LengthUnit.Kilometer,center,LatLng(lat,lon))<=8;
 }
 List<dynamic> filtered(List<dynamic> all){if(place=='Rotterdam-Rijnmond')return all;if(place=='Voorne aan Zee'){if(traffic)return all;const places=['hellevoetsluis','brielle','rockanje','oostvoorne','oudenhoorn','nieuwenhoorn','tinte','vierpolders','zwartewaal','abbenbroek','heenvliet','geervliet','zuidland','simonshaven'];return all.where((e){final h=hay(e);return places.any(h.contains);}).toList();}final q=place.toLowerCase();return all.where((e)=>hay(e).contains(q)||(traffic&&trafficNearPlace(e,place))).toList();}
 void refresh(){setState(()=>items=load());}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('112 & Verkeer'),backgroundColor:Colors.white,foregroundColor:navy,actions:[
   if(!traffic)IconButton(tooltip:'P2000 pushmeldingen',icon:const Icon(Icons.notifications_active_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationPreferencesPage()))),
   const PageFeedbackButton(page:'112 & Verkeer')
 ]),body:Column(children:[
   Padding(padding:const EdgeInsets.all(16),child:Column(children:[
     DropdownButtonFormField<String>(initialValue:place,decoration:InputDecoration(labelText:traffic?'Plaats':'P2000-regio / plaats',border:const OutlineInputBorder()),items:(traffic?['Rotterdam-Rijnmond',...appConfig.places.where((x)=>x!='Voorne aan Zee')]:p2000Places).map((x)=>DropdownMenuItem(value:x,child:Text(x=='Voorne aan Zee'?'Heel Voorne aan Zee':x))).toList(),onChanged:(v){setState(()=>place=v??'Voorne aan Zee');refresh();}),
     const SizedBox(height:12),
     SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('112 / P2000'),icon:Icon(Icons.warning_amber)),ButtonSegment(value:true,label:Text('Verkeer'),icon:Icon(Icons.traffic))],selected:{traffic},onSelectionChanged:(v){setState(()=>traffic=v.first);refresh();})
   ])),
   Expanded(child:FutureBuilder<List<dynamic>>(future:items,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final x=filtered(s.data??[]);if(x.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(traffic?'Geen actuele verkeersmeldingen voor deze selectie.':'Geen P2000-meldingen gevonden in de aangeleverde Rijnmond-feed.')));return RefreshIndicator(onRefresh:()async{refresh();await items;},child:ListView.separated(padding:const EdgeInsets.fromLTRB(16,0,16,20),itemCount:x.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(c,i){final e=x[i];final title=traffic?'${e['message']??e['title']??e['description']??'Verkeersmelding'}':p2000DisplayTitle(e);final date='${e['date']??e['datetime']??e['published']??''}';return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:5),leading:traffic?const Icon(Icons.traffic,color:navy):p2000ServiceIcon(e),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:traffic?Text([if('${e['place']??''}'.trim().isNotEmpty)'${e['place']}',if('${e['body']??''}'.trim().isNotEmpty)'${e['body']}'.replaceAll('\n',' · '),if(date.isNotEmpty)formatP2000Date(date)].join(' • '),maxLines:3,overflow:TextOverflow.ellipsis):date.isEmpty?null:Row(children:[const Icon(Icons.schedule,size:15,color:Colors.black54),const SizedBox(width:5),Text(formatP2000Date(date),style:const TextStyle(fontWeight:FontWeight.w600,color:Colors.black54))]),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>P2000DetailPage(item:e,traffic:traffic))));}));}))
 ]));}

class P2000MapCard extends StatefulWidget{
  final List<String> queries;
  const P2000MapCard({super.key,required this.queries});
  @override State<P2000MapCard> createState()=>_P2000MapCardState();
}
class _P2000MapCardState extends State<P2000MapCard>{
  late Future<LatLng?> point;
  @override void initState(){super.initState();point=locate();}
  Future<LatLng?> locate()async{
    for(final query in widget.queries.map((q)=>q.trim()).where((q)=>q.isNotEmpty)){
      try{
        final u=Uri.https('nominatim.openstreetmap.org','/search',{'q':query,'format':'jsonv2','limit':'1','countrycodes':'nl'});
        final r=await http.get(u,headers:const {'Accept':'application/json','User-Agent':'RVAZ-Android/1.0 (regiovoorneaanzee.nl)'}).timeout(const Duration(seconds:8));
        if(r.statusCode!=200)continue;
        final d=jsonDecode(r.body);
        if(d is List&&d.isNotEmpty){
          final a=double.tryParse(d.first['lat'].toString()),b=double.tryParse(d.first['lon'].toString());
          if(a!=null&&b!=null)return LatLng(a,b);
        }
      }catch(_){}
    }
    return null;
  }
  @override Widget build(BuildContext context)=>FutureBuilder<LatLng?>(
    future:point,
    builder:(context,s){
      final p=s.data;
      if(s.connectionState!=ConnectionState.done)return const SizedBox(height:70,child:Center(child:CircularProgressIndicator()));
      if(p==null)return const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.location_off_outlined),title:Text('Locatie kon niet op de kaart worden gevonden'));
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Locatie op de kaart',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:navy)),
        const SizedBox(height:8),
        ClipRRect(borderRadius:BorderRadius.circular(14),child:SizedBox(height:220,child:fmap.FlutterMap(
          options:fmap.MapOptions(initialCenter:p,initialZoom:16),
          children:[
            fmap.TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'nl.regiovoorneaanzee.app'),
            fmap.MarkerLayer(markers:[fmap.Marker(point:p,width:46,height:46,child:const Icon(Icons.location_pin,size:44,color:Colors.red))])
          ]
        )))
      ]);
    }
  );
}

class TrafficMapCard extends StatelessWidget{final double latitude,longitude;const TrafficMapCard({super.key,required this.latitude,required this.longitude});@override Widget build(BuildContext context){final p=LatLng(latitude,longitude);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Locatie op de kaart',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(14),child:SizedBox(height:220,child:fmap.FlutterMap(options:fmap.MapOptions(initialCenter:p,initialZoom:14),children:[fmap.TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'nl.regiovoorneaanzee.app'),fmap.MarkerLayer(markers:[fmap.Marker(point:p,width:46,height:46,child:const Icon(Icons.location_pin,size:44,color:Colors.red))])])))]);}}

class P2000DetailPage extends StatelessWidget {
  final dynamic item; final bool traffic;
  const P2000DetailPage({super.key,required this.item,required this.traffic});
  String value(List<String> keys){if(item is! Map)return '';for(final k in keys){final v=item[k];if(v!=null&&'$v'.trim().isNotEmpty)return '$v'.trim();}return '';}
  @override Widget build(BuildContext context){
    final title=traffic?(value(['title','message','description']).isEmpty?'Melding':value(['title','message','description'])):p2000DisplayTitle(item);
    final date=value(['date','datetime','published','time']);
    final place=value(['place','location','city']);
    final address=value(['address','adres','street','straat']);
    final service=value(['service','discipline','dienst','agency']);
    final priority=p2000PriorityLabel(item).isNotEmpty?p2000PriorityLabel(item):value(['priority','prio']);
    final unit=value(['unit','units','eenheid','eenheden','post','station','kazerne','alarm_receiver','alarmReceiver','receiver','cap_description','capDescription']);
    final capcodes=value(['capcodes','capcode','cap_codes','capcode_description','capcodeDescription']);
    final body=value(['body','description','details','content']);
    final source=value(['source']);
    final detailAds=loadAppAds(placement:'p2000');
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(traffic?'Verkeersmelding':'P2000-melding'),backgroundColor:Colors.white,foregroundColor:navy),body:ListView(padding:const EdgeInsets.all(18),children:[
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        traffic?const Icon(Icons.traffic,color:navy,size:34):p2000ServiceIcon(item,size:34),const SizedBox(height:12),
        Text(title,style:const TextStyle(fontSize:22,height:1.2,fontWeight:FontWeight.w900,color:navy)),
        if(date.isNotEmpty)...[const SizedBox(height:14),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.schedule,color:navy),title:Text(formatP2000Date(date),style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:const Text('Tijdstip van de melding'))],
        if(place.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined),title:Text(place)),
        if(service.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.emergency_outlined),title:Text(service)),
        if(!traffic&&unit.isNotEmpty&&unit.toLowerCase()!=service.toLowerCase())ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.badge_outlined),title:Text(unit),subtitle:const Text('Post / eenheid')),
        if(!traffic&&capcodes.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.numbers_outlined),title:Text(capcodes),subtitle:const Text('Capcode / eenheid')),
        if(priority.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.priority_high),title:Text(priority)),
        if(traffic&&source.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.source_outlined),title:Text(source),subtitle:const Text('Bron verkeersinformatie')),
        if(body.isNotEmpty&&body!=title)...[const Divider(height:28),Text(body,style:const TextStyle(fontSize:16,height:1.5))],
        if(traffic&&item is Map&&item['latitude'] is num&&item['longitude'] is num)...[const SizedBox(height:14),TrafficMapCard(latitude:(item['latitude'] as num).toDouble(),longitude:(item['longitude'] as num).toDouble())],
        if(!traffic&&(address.isNotEmpty||title.contains(',')))...[const SizedBox(height:14),P2000MapCard(queries:[
          if(address.isNotEmpty)[address,place].where((x)=>x.isNotEmpty).join(', '),
          if(address.isNotEmpty)address,
          if(address.isEmpty&&title.contains(','))title.split('·').last.trim(),
        ])],
      ]))),
      if(!traffic)...[
        const SizedBox(height:14),
        OutlinedButton.icon(
          onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TipPage(p2000Reference:[title,if(date.isNotEmpty)formatP2000Date(date),place,service,priority].where((x)=>x.trim().isNotEmpty).join(' · ')))),
          icon:const Icon(Icons.campaign_outlined),
          label:const Text('Weet je hier meer van? Tip de redactie'),
        ),
      ],
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


class TodayPage extends StatefulWidget{const TodayPage({super.key});@override State<TodayPage> createState()=>_TodayPageState();}
class _TodayPageState extends State<TodayPage>{
 late Future<Map<String,dynamic>> future; String place='',street='';
 @override void initState(){super.initState();future=load();}
 Future<Map<String,dynamic>> load()async{
   const st=FlutterSecureStorage();
   final saved=(await st.read(key:'rvaz_neighborhood_place')??'').trim();
   final savedStreet=(await st.read(key:'rvaz_neighborhood_street')??'').trim();
   final pushStreet=(await st.read(key:'rvaz_p2000_street_name')??'').trim();
   place=saved.isEmpty?'Voorne aan Zee':saved;street=savedStreet.isNotEmpty?savedStreet:pushStreet;
   try{
     final d=await RvazApi.get('today',query:{'place':place});
     if(d is Map){
       final out=Map<String,dynamic>.from(d);
       if(RvazApi.list(out['agenda']).isEmpty&&place!='Voorne aan Zee'){
         final all=await RvazApi.firstList(['agenda?per_page=250','events?per_page=250'],keys:const ['events','agenda']);
         out['agenda']=all.where((e){if(e is! Map)return false;final p='${e['place']??e['city']??e['town']??e['plaats']??e['event_place']??''}'.trim().toLowerCase();return p==place.toLowerCase();}).toList();
       }
       return out;
     }
   }catch(_){}
   return{};
 }
 Future<void> openAddress()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage()));setState(()=>future=load());}
 List<dynamic> section(Map<String,dynamic>d,String key)=>RvazApi.list(d[key]);
 Future<Map<String,dynamic>> todayExtras()async{
   const st=FlutterSecureStorage();
   final result=<String,dynamic>{};
   try{
     final wr=await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=51.8333&longitude=4.1333&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m&timezone=Europe%2FAmsterdam')).timeout(const Duration(seconds:8));
     if(wr.statusCode==200){final wd=jsonDecode(wr.body);if(wd is Map&&wd['current'] is Map)result['weather']=Map<String,dynamic>.from(wd['current']);}
   }catch(_){}
   final bag=(await st.read(key:'rvaz_waste_bagid')??'').trim();
   if(bag.isNotEmpty){
     try{
       final now=DateTime.now(),today=DateTime(now.year,now.month,now.day);Map? best;DateTime? bestDate;
       for(final md in [DateTime(now.year,now.month,1),DateTime(now.year,now.month+1,1)]){
         final rr=await http.get(Uri.parse('https://reinis.nl/rest/waste-calendar/dates?bagId=${Uri.encodeQueryComponent(bag)}&month=${md.month}&year=${md.year}')).timeout(const Duration(seconds:8));
         if(rr.statusCode==200){final x=jsonDecode(rr.body);if(x is List)for(final e in x){if(e is Map){final dt=DateTime.tryParse('${e['ophaaldatum']??''}');if(dt!=null&&!dt.isBefore(today)&&(bestDate==null||dt.isBefore(bestDate))){best=e;bestDate=dt;}}}}
       }
       if(best!=null&&bestDate!=null)result['waste']={'item':best,'date':bestDate.toIso8601String()};
     }catch(_){}
   }
   return result;
 }
 String weatherLabel(int code){if(code==0)return'Helder';if(code<=3)return'Bewolkt';if(code<=48)return'Mist';if(code<=67)return'Regen';if(code<=77)return'Sneeuw';if(code<=82)return'Buien';if(code<=99)return'Onweer';return'Weer';}
 String wasteLabel(Map item){const names=<int,String>{2:'GFT+e',3:'PMD',4:'Oud papier en karton',25:'Restafval'};final id=int.tryParse('${item['afvalstroom_id']??item['afvalstroomId']??item['id']??''}');return names[id]??'${item['afvalstroom']??item['name']??'Afval'}';}

 DateTime? eventDate(dynamic e){if(e is! Map)return null;for(final k in ['start_date','event_start_date','event_date','start','date','datum','datetime']){final raw='${e[k]??''}'.trim();if(raw.isEmpty)continue;final parsed=DateTime.tryParse(raw);if(parsed!=null)return parsed.toLocal();final m=RegExp(r'^(\\d{1,2})[-/](\\d{1,2})[-/](\\d{4})').firstMatch(raw);if(m!=null)return DateTime(int.parse(m.group(3)!),int.parse(m.group(2)!),int.parse(m.group(1)!));}return null;}
 bool isTodayEvent(dynamic e){final d=eventDate(e);if(d==null)return false;final now=DateTime.now();return d.year==now.year&&d.month==now.month&&d.day==now.day;}
 String text(dynamic e,String key){if(e is! Map)return'';final v=e[key];if(v is Map)return decodeHtmlEntities('${v['rendered']??''}'.replaceAll(RegExp(r'<[^>]*>'),''));return decodeHtmlEntities('${v??''}'.replaceAll(RegExp(r'<[^>]*>'),''));}
 String greeting(){final h=DateTime.now().hour;if(h<12)return'Goedemorgen 👋';if(h<18)return'Goedemiddag 👋';return'Goedenavond 👋';}
 void openItem(String kind,dynamic e){if(kind=='news'){openArticle(context,e);return;}if(kind=='agenda'){Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDetailPage(event:e)));return;}Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyTrafficPage(initialTraffic:kind=='traffic',initialPlace:place)));}
 Widget sectionCard(String kind,String title,IconData icon,Color color,List<dynamic> items){
   if(items.isEmpty)return const SizedBox.shrink();
   return Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.fromLTRB(14,14,14,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[CircleAvatar(radius:18,backgroundColor:color.withValues(alpha:.10),child:Icon(icon,color:color,size:20)),const SizedBox(width:10),Expanded(child:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)))]),
     const SizedBox(height:8),...items.take(5).map((e)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text(text(e,'title').isNotEmpty?text(e,'title'):text(e,'message'),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),subtitle:text(e,'place').isEmpty?null:Text(text(e,'place')),trailing:const Icon(Icons.chevron_right,color:navy),onTap:()=>openItem(kind,e)))
   ])));
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Voorne Vandaag')),body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){
   if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
   final d=s.data??{},news=section(d,'news'),p2000=section(d,'p2000'),traffic=section(d,'traffic'),agenda=section(d,'agenda').where(isTodayEvent).toList();
   return RefreshIndicator(onRefresh:()async{setState(()=>future=load());await future;},child:ListView(padding:const EdgeInsets.all(16),children:[
     Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF073B63),Color(0xFF0B6FA4)]),borderRadius:BorderRadius.circular(18),image:DecorationImage(image:NetworkImage(appConfig.homeHeroUrl.trim().isEmpty?defaultRVAZHero:appConfig.homeHeroUrl),fit:BoxFit.cover,colorFilter:const ColorFilter.mode(Color(0x77073B63),BlendMode.darken))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(greeting(),style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w700)),const SizedBox(height:4),const Text('Voorne Vandaag',style:TextStyle(color:Colors.white,fontSize:29,fontWeight:FontWeight.w900)),const SizedBox(height:5),
       Text(place=='Voorne aan Zee'?'Stel je adres in voor informatie uit jouw buurt.':'Jouw buurt: $place${street.isEmpty?'':' · $street'}',style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w600))
     ])),
     const SizedBox(height:10),
     Card(child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFEAF4FF),child:Icon(Icons.edit_location_alt_outlined,color:navy)),title:const Text('Adres wijzigen',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:Text(street.isEmpty?(place=='Voorne aan Zee'?'Postcode, huisnummer en toevoeging instellen':'Adres voor $place instellen'):'$street · $place'),trailing:const Icon(Icons.chevron_right,color:navy),onTap:openAddress)),
     FutureBuilder<Map<String,dynamic>>(future:todayExtras(),builder:(context,x){final ex=x.data??{},w=ex['weather'] is Map?Map<String,dynamic>.from(ex['weather']):<String,dynamic>{},wa=ex['waste'] is Map?Map<String,dynamic>.from(ex['waste']):<String,dynamic>{};final temp=(w['temperature_2m'] as num?)?.round(),feels=(w['apparent_temperature'] as num?)?.round(),wind=(w['wind_speed_10m'] as num?)?.round(),code=(w['weather_code'] as num?)?.toInt()??0;final wi=wa['item'] is Map?Map<String,dynamic>.from(wa['item']):<String,dynamic>{};final wd=DateTime.tryParse('${wa['date']??''}');String when='';if(wd!=null){final now=DateTime.now(),today=DateTime(now.year,now.month,now.day),diff=DateTime(wd.year,wd.month,wd.day).difference(today).inDays;when=diff==0?'Vandaag':diff==1?'Morgen':'Over $diff dagen';}return Column(children:[
       Row(children:[
         Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.cloud_outlined,color:cyan),SizedBox(width:7),Text('Weer vandaag',style:TextStyle(fontWeight:FontWeight.w900,color:navy))]),const SizedBox(height:8),Text(temp==null?'Niet beschikbaar':'$temp° · ${weatherLabel(code)}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),if(feels!=null||wind!=null)Text([if(feels!=null)'Voelt als $feels°',if(wind!=null)'Wind $wind km/u'].join(' · '),style:const TextStyle(fontSize:11,color:Colors.black54))])))),
         const SizedBox(width:8),
         Expanded(child:Card(child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage())),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.recycling,color:Color(0xFF16834B)),SizedBox(width:7),Expanded(child:Text('Volgende inzameling',style:TextStyle(fontWeight:FontWeight.w900,color:navy)))]),const SizedBox(height:8),Text(wi.isEmpty?'Stel je adres in':wasteLabel(wi),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:navy)),if(when.isNotEmpty)Text(when,style:const TextStyle(fontSize:12,color:Colors.black54))]))))),
       ]),
       const SizedBox(height:4),
     ]);}),
     Row(children:[
       Expanded(child:Card(child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage())),child:const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Column(children:[Icon(Icons.recycling,color:Color(0xFF16834B)),SizedBox(height:5),Text('Afval',style:TextStyle(fontWeight:FontWeight.w800))]))))),const SizedBox(width:6),
       Expanded(child:Card(child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyTrafficPage(initialTraffic:true,initialPlace:place))),child:const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Column(children:[Icon(Icons.traffic,color:Colors.deepOrange),SizedBox(height:5),Text('Verkeer',style:TextStyle(fontWeight:FontWeight.w800))]))))),const SizedBox(width:6),
       Expanded(child:Card(child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationPreferencesPage())),child:const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Column(children:[Icon(Icons.notifications_active_outlined,color:Color(0xFF16834B)),SizedBox(height:5),Text('Meldingen',style:TextStyle(fontWeight:FontWeight.w800))])))))
     ]),
     const SizedBox(height:8),
     Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[const Icon(Icons.today_outlined,color:navy),const SizedBox(width:10),Expanded(child:Text(place=='Voorne aan Zee'?'Dit speelt er vandaag op Voorne':'Dit speelt er vandaag in $place',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:navy))),Text('${news.length} nieuws · ${agenda.length} agenda',style:const TextStyle(fontSize:11,color:Colors.black54))]))),
     const SizedBox(height:4),
     if(d.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Het dagoverzicht is momenteel niet beschikbaar.'))),
     sectionCard('news',place=='Voorne aan Zee'?'Vandaag in het nieuws':'Nieuws uit $place',Icons.article_outlined,cyan,news),
     sectionCard('p2000',place=='Voorne aan Zee'?'112 / P2000':'112 / P2000 in $place',Icons.warning_amber_rounded,Colors.red,p2000),
     sectionCard('agenda','Vandaag te doen',Icons.event_outlined,const Color(0xFF16834B),agenda),
     sectionCard('traffic',place=='Voorne aan Zee'?'Verkeer in de regio':'Verkeer rond $place',Icons.traffic,Colors.deepOrange,traffic),
     Card(child:ListTile(leading:const Icon(Icons.location_on_outlined,color:cyan),title:Text(place=='Voorne aan Zee'?'Plaatsen':'Meer uit $place',style:const TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Bekijk lokaal nieuws en informatie'),trailing:const Icon(Icons.chevron_right,color:navy),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>place=='Voorne aan Zee'?const PlacesPage():PlaceNewsPage(place:place))))),
   ]));
 }));
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
 String clean(dynamic v)=>decodeHtmlEntities('$v'.replaceAll(RegExp(r'<[^>]*>'),'').replaceAll('&#8211;','–'));
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
 String? userName; bool busy=false; bool advertiser=false; bool businessLinked=false; Map<String,dynamic> userInfo={};
 @override void initState(){super.initState();restore();}
 Future<bool> _hasLinkedBusiness()async{try{final t=await const FlutterSecureStorage().read(key:'rvaz_token');final r=await http.get(Uri.parse('$site/wp-json/rvaz-business/v1/mine'),headers:{'Accept':'application/json',if(t!=null&&t.isNotEmpty)...{'Authorization':'Bearer $t','X-RVAZ-Token':t}}).timeout(const Duration(seconds:10));return r.statusCode==200;}catch(_){return false;}}
 Future<void> restore()async{final t=await const FlutterSecureStorage().read(key:'rvaz_token');if(t==null)return;try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/me'),headers:{'Authorization':'Bearer $t'});if(r.statusCode==200){final d=jsonDecode(r.body);if(mounted)setState((){userInfo=Map<String,dynamic>.from(d['user']??{});userName=userInfo['name']?.toString();advertiser=userInfo['advertiser']==true;});final linked=await _hasLinkedBusiness();if(mounted)setState(()=>businessLinked=linked);}}catch(_){}}
 Future<void> auth(bool reg)async{final n=TextEditingController(),e=TextEditingController(),p=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(reg?'Account aanmaken':'Inloggen'),content:Column(mainAxisSize:MainAxisSize.min,children:[if(reg)TextField(controller:n,decoration:const InputDecoration(labelText:'Naam')),TextField(controller:e,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mailadres')),TextField(controller:p,obscureText:true,decoration:InputDecoration(labelText:'Wachtwoord',helperText:reg?'Minimaal 8 tekens':null))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Annuleren')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(reg?'Account aanmaken':'Inloggen'))]));if(ok!=true)return;if(reg&&(n.text.trim().isEmpty||p.text.length<8)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Naam en minimaal 8 tekens voor het wachtwoord zijn nodig.')));return;}setState(()=>busy=true);try{final body=reg?{'name':n.text.trim(),'email':e.text.trim(),'password':p.text}:{'login':e.text.trim(),'password':p.text};final endpoint=reg?'register':'login';final r=await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/$endpoint'),headers:{'Content-Type':'application/json','Accept':'application/json'},body:jsonEncode(body));if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body),t=d['token']?.toString()??'';if(t.isNotEmpty)await const FlutterSecureStorage().write(key:'rvaz_token',value:t);if(mounted){final u=Map<String,dynamic>.from(d['user']??{});setState((){userInfo=u;userName=u['name']?.toString()??n.text.trim();advertiser=u['advertiser']==true;});final linked=await _hasLinkedBusiness();if(mounted)setState(()=>businessLinked=linked);}}else{String m='Inloggen of registreren mislukt.';try{m=jsonDecode(r.body)['message']?.toString()??m;}catch(_){}if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));}}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding met RVAZ.')));}if(mounted)setState(()=>busy=false);}
 Future<void> logout()async{final t=await const FlutterSecureStorage().read(key:'rvaz_token');if(t!=null){try{await http.post(Uri.parse('$site/wp-json/rvaz-app/v1/logout'),headers:{'Authorization':'Bearer $t'});}catch(_){}}await const FlutterSecureStorage().delete(key:'rvaz_token');if(mounted)setState((){userName=null;advertiser=false;businessLinked=false;userInfo={};});}
  Widget _sectionHeader(IconData icon,String title,String subtitle)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
    decoration:const BoxDecoration(color:Color(0xFFEAF4FF),borderRadius:BorderRadius.vertical(top:Radius.circular(14))),
    child:Row(children:[Icon(icon,color:navy),const SizedBox(width:12),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const Spacer(),Flexible(child:Text(subtitle,textAlign:TextAlign.right,style:const TextStyle(fontSize:12,color:Colors.black54)))]),
  );
  Widget _menuIcon(IconData icon)=>CircleAvatar(backgroundColor:const Color(0xFFEAF4FF),child:Icon(icon,color:navy));
  @override
  Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.all(18),
    children:[
      const Text('Mijn Voorne',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
        _menuIcon(Icons.person),const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('RVAZ-account',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:5),
          Text(userName==null?'Hetzelfde account werkt op website en app':'Ingelogd als $userName'),
          if(busy)const Padding(padding:EdgeInsets.only(top:8),child:LinearProgressIndicator()),
        ])),
        const SizedBox(width:10),
        if(userName==null)OutlinedButton.icon(onPressed:busy?null:()=>auth(false),icon:const Icon(Icons.login),label:const Text('Inloggen'))
        else OutlinedButton.icon(onPressed:logout,icon:const Icon(Icons.logout),label:const Text('Uitloggen')),
      ]))),
      const SizedBox(height:14),
      if(userName!=null)Card(clipBehavior:Clip.antiAlias,child:Column(children:[
        _sectionHeader(Icons.person,'Mijn Voorne','Jouw instellingen en voorkeuren'),
        ListTile(leading:_menuIcon(Icons.home_outlined),title:const Text('Mijn Voorne',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Jouw adres, lokaal nieuws, agenda en afval'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MyVoornePage()))),
        const Divider(height:1,indent:72),
        ListTile(leading:_menuIcon(Icons.settings_outlined),title:const Text('Mijn profiel',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Beheer je gegevens en voorkeuren'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProfilePage(user:userInfo)))),
        const Divider(height:1,indent:72),
        ListTile(leading:_menuIcon(Icons.notifications_outlined),title:const Text('Meldingen',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Kies welke pushmeldingen je wilt ontvangen'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationPreferencesPage()))),
        const Divider(height:1,indent:72),
        ListTile(leading:_menuIcon(Icons.local_offer_outlined),title:const Text('Mijn vouchers',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Bekijk je persoonlijke QR-codes en status'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MyVouchersPage()))),
        if(businessLinked)...[
          const Divider(height:1,indent:72),
          ListTile(leading:_menuIcon(Icons.storefront_outlined),title:const Text('Mijn bedrijf',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Beheer je bedrijfsprofiel, openingstijden en vouchers'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessManagePage()))),
          const Divider(height:1,indent:72),
          ListTile(leading:_menuIcon(Icons.qr_code_scanner),title:const Text('Voucher scannen',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Controleer en wissel een voucher in'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessVoucherScannerPage()))),
        ],
      ])),
      if(userName!=null)const SizedBox(height:14),
      Card(clipBehavior:Clip.antiAlias,child:Column(children:[
        _sectionHeader(Icons.chat_bubble_outline,'Contact & bijdragen','Help mee en blijf in contact'),
        ListTile(leading:_menuIcon(Icons.feedback_outlined),title:const Text('Feedback over de app',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Meld een fout of geef een suggestie'),trailing:const Icon(Icons.chevron_right),onTap:()=>sendPageFeedback(context,'Algemene app-feedback')),
        const Divider(height:1,indent:72),
        ListTile(leading:_menuIcon(Icons.campaign_outlined),title:const Text('Tip de redactie',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:Text(userName==null?'Log in om een tip te versturen':'Stuur nieuws rechtstreeks naar de redactie'),trailing:const Icon(Icons.chevron_right),onTap:()=>userName==null?auth(false):Navigator.push(context,MaterialPageRoute(builder:(_)=>const TipPage()))),
      ])),
    ],
  );
}

class MyNeighborhoodPage extends StatefulWidget {
  const MyNeighborhoodPage({super.key});
  @override State<MyNeighborhoodPage> createState()=>_MyNeighborhoodPageState();
}
class _MyNeighborhoodPageState extends State<MyNeighborhoodPage> {
  String place='',street='';
  @override void initState(){super.initState();_loadPlace();}
  Future<void> _loadPlace()async{
    const st=FlutterSecureStorage();
    final p=(await st.read(key:'rvaz_neighborhood_place')??'').trim();
    final savedStreet=(await st.read(key:'rvaz_neighborhood_street')??'').trim();
    final pushStreet=(await st.read(key:'rvaz_p2000_street_name')??'').trim();
    if(mounted)setState((){place=p;street=savedStreet.isNotEmpty?savedStreet:pushStreet;});
  }
  Future<void> _openWaste()async{
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>const WasteCalendarPage()));
    await _loadPlace();
  }
  Future<Map<String,String>> _streetLive()async{
    if(place.isEmpty)return const {'waste':'Stel eerst je adres in','works':'Adres nodig voor werkzaamheden','traffic':'Adres nodig voor verkeer','p2000':'Adres nodig voor 112-meldingen','agenda':'Adres nodig voor activiteiten'};
    const st=FlutterSecureStorage();final bag=(await st.read(key:'rvaz_waste_bagid')??'').trim(),pc=(await st.read(key:'rvaz_waste_postcode')??'').trim(),nr=(await st.read(key:'rvaz_waste_house')??'').trim(),addition=(await st.read(key:'rvaz_waste_addition')??'').trim();
    LatLng? home;try{final r=await http.get(Uri.parse('https://api.pdok.nl/bzk/locatieserver/search/v3_1/free?q=${Uri.encodeQueryComponent('$pc $nr$addition')}&fq=type:adres&rows=1')).timeout(const Duration(seconds:8));final d=jsonDecode(r.body),docs=d is Map&&d['response'] is Map?(d['response']['docs'] as List? ?? const []):const[];if(docs.isNotEmpty){final m=RegExp(r'POINT\\(([-0-9.]+)\\s+([-0-9.]+)\\)').firstMatch('${docs.first['centroide_ll']??''}');if(m!=null){final lon=double.tryParse(m.group(1)??''),lat=double.tryParse(m.group(2)??'');if(lat!=null&&lon!=null)home=LatLng(lat,lon);}}}catch(_){}
    String waste='Afvalkalender niet beschikbaar';if(bag.isNotEmpty)try{final now=DateTime.now(),today=DateTime(now.year,now.month,now.day);Map? best;DateTime? bd;for(final md in [DateTime(now.year,now.month,1),DateTime(now.year,now.month+1,1)]){final r=await http.get(Uri.parse('https://reinis.nl/rest/waste-calendar/dates?bagId=${Uri.encodeQueryComponent(bag)}&month=${md.month}&year=${md.year}')).timeout(const Duration(seconds:8));if(r.statusCode==200){final x=jsonDecode(r.body);if(x is List)for(final e in x){if(e is Map){final d=DateTime.tryParse('${e['ophaaldatum']??''}');if(d!=null&&!d.isBefore(today)&&(bd==null||d.isBefore(bd))){best=e;bd=d;}}}}}if(best!=null&&bd!=null){const names=<int,String>{2:'GFT+e',3:'PMD',4:'Oud papier en karton',25:'Restafval'};final id=int.tryParse('${best['afvalstroom_id']??best['afvalstroomId']??best['id']??''}'),name=names[id]??'Afval',diff=DateTime(bd.year,bd.month,bd.day).difference(today).inDays;waste=diff==0?'Vandaag: $name':diff==1?'Morgen: $name':'Over $diff dagen: $name';}}catch(_){}
    List<dynamic> traffic=<dynamic>[];try{traffic=await loadNdwTraffic();}catch(_){}final nearby=<MapEntry<dynamic,double>>[],distance=const Distance();if(home!=null)for(final e in traffic){if(e is Map){final lat=(e['latitude'] as num?)?.toDouble(),lon=(e['longitude'] as num?)?.toDouble();if(lat!=null&&lon!=null){final km=distance.as(LengthUnit.Kilometer,home,LatLng(lat,lon));if(km<=8)nearby.add(MapEntry(e,km));}}}nearby.sort((a,b)=>a.value.compareTo(b.value));final works=nearby.where((x){final h='${x.key['title']??''} ${x.key['description']??''} ${x.key['message']??''}'.toLowerCase();return h.contains('work')||h.contains('maintenance')||h.contains('construction')||h.contains('afsluit');}).toList();final placeTraffic=traffic.where((e)=>'${e is Map?e['place']??'':''} ${e is Map?e['title']??'':''}'.toLowerCase().contains(place.toLowerCase())).length,count=home!=null?nearby.length:placeTraffic;final trafficText=count==0?'Geen actuele verkeersmeldingen in de buurt':'$count actuele verkeersmelding${count==1?'':'en'} in de buurt';final worksText=works.isEmpty?(home==null?'Geen actuele werkzaamheden gevonden in $place':'Geen actuele werkzaamheden in de buurt'):'Werkzaamheden op ${works.first.value<1?'${(works.first.value*1000).round()} meter':'${works.first.value.toStringAsFixed(1).replaceAll('.',',')} km'}';
    final region=Uri.encodeQueryComponent('Rotterdam-Rijnmond');List<dynamic> incidents=<dynamic>[];try{incidents=await RvazApi.firstList(['p2000?region=$region&per_page=250','112?region=$region&per_page=250','meldingen?region=$region&per_page=250'],keys:const ['meldingen','p2000','112','items','data']);}catch(_){}final needle=place.toLowerCase(),ic=incidents.where((e)=>'$e'.toLowerCase().contains(needle)).length;final incidentText=ic==0?'Geen recente 112-meldingen in $place':'$ic recente 112-melding${ic==1?'':'en'} in $place';
    final events=<dynamic>[];for(final path in ['agenda?per_page=250','events?per_page=250']){try{final p=path.split('?'),d=await RvazApi.get(p.first,query:Uri.splitQueryString(p[1]));events.addAll(RvazApi.list(d,const ['events','agenda']));}catch(_){}}final now=DateTime.now(),today=DateTime(now.year,now.month,now.day);var ec=0;for(final e in events){if(e is! Map)continue;String v(List<String> ks){for(final k in ks){if(e[k]!=null&&'${e[k]}'.trim().isNotEmpty)return'${e[k]}';}return'';}final d=DateTime.tryParse(v(['start_date','event_start_date','event_date','start','date','datum','datetime'])),p=v(['place','city','town','plaats','event_place']).toLowerCase();if(d!=null&&DateTime(d.year,d.month,d.day)==today&&d.hour>=17&&p.contains(place.toLowerCase()))ec++;}
    return {'waste':waste,'works':worksText,'traffic':trafficText,'p2000':incidentText,'agenda':ec==0?'Vanavond: geen activiteit gevonden in $place':'Vanavond: $ec activiteit${ec==1?'':'en'} in $place'};
  }
  @override Widget build(BuildContext context){
    Widget shortcut(IconData icon,String label,Color tint,VoidCallback onTap)=>Expanded(child:Card(child:InkWell(borderRadius:BorderRadius.circular(14),onTap:onTap,child:Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:13),child:Column(children:[CircleAvatar(radius:19,backgroundColor:tint.withValues(alpha:.11),child:Icon(icon,color:tint,size:21)),const SizedBox(height:7),Text(label,textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:11,height:1.15,fontWeight:FontWeight.w800,color:navy))])))));
    Widget neighborhoodTile(IconData icon,Color tint,String title,String subtitle,VoidCallback onTap)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:3),leading:CircleAvatar(backgroundColor:tint.withValues(alpha:.11),child:Icon(icon,color:tint)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right,color:navy),onTap:onTap));
    return Scaffold(
      backgroundColor:const Color(0xFFF7F9FB),
      appBar:AppBar(title:const Text('Mijn Buurt')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF073B63),Color(0xFF0B6FA4)]),borderRadius:BorderRadius.circular(20)),child:Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Mijn Buurt',style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),
            const SizedBox(height:4),Text(place.isEmpty?'Stel je adres in voor informatie dichtbij.':place,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w700)),
            if(street.isNotEmpty)...[const SizedBox(height:3),Text(street,style:const TextStyle(color:Colors.white70))]
          ])),
          const Icon(Icons.home_work_outlined,color:Colors.white,size:46)
        ])),
        const SizedBox(height:12),
        Row(children:[
          shortcut(Icons.traffic,'Verkeer',Colors.deepOrange,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyTrafficPage(initialTraffic:true,initialPlace:place)))),const SizedBox(width:7),
          shortcut(Icons.warning_amber_rounded,'112 / P2000',Colors.red,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyTrafficPage(initialTraffic:false,initialPlace:place)))),const SizedBox(width:7),
          shortcut(Icons.notifications_active_outlined,'Buurtmeldingen',const Color(0xFF16834B),()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationPreferencesPage())))
        ]),
        const SizedBox(height:10),
        neighborhoodTile(Icons.edit_location_alt_outlined,navy,'Adres wijzigen',street.isEmpty?(place.isEmpty?'Postcode, huisnummer en toevoeging instellen':'Wijzig het adres voor $place'):'$street${place.isEmpty?'':' · $place'}',_openWaste),
        const SizedBox(height:12),
        const Text('Rond mijn straat',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy)),
        const SizedBox(height:8),
        Card(child:FutureBuilder<Map<String,String>>(future:_streetLive(),builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator()));final d=s.data??const <String,String>{};Widget row(IconData icon,Color tint,String key)=>Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),child:Row(children:[CircleAvatar(radius:16,backgroundColor:tint.withValues(alpha:.10),child:Icon(icon,size:17,color:tint)),const SizedBox(width:10),Expanded(child:Text(d[key]??'Niet beschikbaar',style:const TextStyle(fontWeight:FontWeight.w600)))]));return Column(children:[
          ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFEAF4FF),child:Icon(Icons.near_me_outlined,color:navy)),title:Text(street.isEmpty?'Rond jouw straat':street,style:const TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:Text(street.isEmpty?(place.isEmpty?'Stel je adres in via de afvalkalender':'Actuele informatie voor $place'):'Actuele informatie rond $street${place.isEmpty?'':' · $place'}')),
          const Divider(height:1),row(Icons.recycling,const Color(0xFF16834B),'waste'),row(Icons.construction,Colors.deepOrange,'works'),row(Icons.traffic,Colors.deepOrange,'traffic'),row(Icons.warning_amber_rounded,Colors.red,'p2000'),row(Icons.event_outlined,cyan,'agenda'),
        ]);})),
        const SizedBox(height:16),
        const Text('Voor jouw buurt',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy)),
        const SizedBox(height:8),
        neighborhoodTile(Icons.recycling,const Color(0xFF16834B),'Afvalkalender',place.isEmpty?'Stel je adres in en bekijk wanneer Reinis jouw afval ophaalt':'Afvalkalender voor $place',_openWaste),
        neighborhoodTile(Icons.notifications_active_outlined,Colors.deepOrange,'Buurtmeldingen','Stel P2000 en andere lokale meldingen in',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationPreferencesPage()))),
        neighborhoodTile(Icons.location_on_outlined,cyan,place.isEmpty?'Nieuws uit jouw plaats':'Nieuws uit $place',place.isEmpty?'Kies een plaats voor lokaal nieuws':'Bekijk nieuws uit jouw eigen plaats',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>place.isEmpty?const PlacesPage():PlaceNewsPage(place:place)))),
        neighborhoodTile(Icons.traffic,Colors.deepOrange,'Verkeer in de regio',place.isEmpty?'Bekijk actuele verkeersmeldingen':'Start met $place als selectie',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyTrafficPage(initialTraffic:true,initialPlace:place)))),
        neighborhoodTile(Icons.warning_amber_rounded,Colors.red,'Actuele incidenten',place.isEmpty?'Bekijk de actuele 112- en P2000-meldingen':'Start met meldingen voor $place',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyTrafficPage(initialTraffic:false,initialPlace:place)))),
        const SizedBox(height:6),
        const Padding(padding:EdgeInsets.symmetric(horizontal:4),child:Text('Je buurt wordt bepaald via het adres dat je bij de afvalkalender instelt. Deze voorkeur blijft op je toestel.',style:TextStyle(fontSize:12,color:Colors.black54,height:1.4)))
      ])
    );
  }
}

class WasteCalendarPage extends StatefulWidget {
  const WasteCalendarPage({super.key});
  @override State<WasteCalendarPage> createState()=>_WasteCalendarPageState();
}
class _WasteCalendarPageState extends State<WasteCalendarPage> {
  final postcode=TextEditingController(), house=TextEditingController(), addition=TextEditingController();
  bool busy=false,wastePush=false; String error='', address=''; List<Map<String,dynamic>> dates=[];
  static const names=<int,String>{2:'GFT+e',3:'PMD',4:'Oud papier en karton',25:'Restafval'};
  static const icons=<int,IconData>{2:Icons.eco_outlined,3:Icons.recycling,4:Icons.description_outlined,25:Icons.delete_outline};
  @override void initState(){super.initState();_restore();}
  @override void dispose(){postcode.dispose();house.dispose();addition.dispose();super.dispose();}
  Future<void> _restore() async {
    const st=FlutterSecureStorage();
    postcode.text=await st.read(key:'rvaz_waste_postcode')??'';
    house.text=await st.read(key:'rvaz_waste_house')??'';
    addition.text=await st.read(key:'rvaz_waste_addition')??'';
    wastePush=(await st.read(key:'rvaz_waste_push'))=='1';
    if(postcode.text.isNotEmpty&&house.text.isNotEmpty)await load();
  }
  Future<void> load() async {
    final pc=postcode.text.replaceAll(' ','').toUpperCase(), nr=house.text.trim(), add=addition.text.trim();
    if(pc.isEmpty||nr.isEmpty){setState(()=>error='Vul je postcode en huisnummer in.');return;}
    setState((){busy=true;error='';});
    try{
      final suffix='$nr$add';
      final ar=await http.get(Uri.parse('https://reinis.nl/adressen/${Uri.encodeComponent('$pc:$suffix')}'),headers:const {'Accept':'application/json'}).timeout(const Duration(seconds:12));
      if(ar.statusCode!=200)throw Exception('Adres niet gevonden');
      dynamic ad=jsonDecode(ar.body); if(ad is List&&ad.isNotEmpty)ad=ad.first;
      if(ad is! Map)throw Exception('Adres niet gevonden');
      final bag=(ad['bagid']??ad['bagId']??'').toString();
      if(bag.isEmpty)throw Exception('Geen afvalkalender voor dit adres');
      final now=DateTime.now();
      final dr=await http.get(Uri.parse('https://reinis.nl/rest/waste-calendar/dates?bagId=${Uri.encodeQueryComponent(bag)}&month=${now.month}&year=${now.year}'),headers:const {'Accept':'application/json'}).timeout(const Duration(seconds:12));
      if(dr.statusCode!=200)throw Exception('Afvalkalender niet beschikbaar');
      final raw=jsonDecode(dr.body);
      final list=raw is List?raw:<dynamic>[];
      final today=DateTime(now.year,now.month,now.day);
      final upcoming=<Map<String,dynamic>>[];
      for(final x in list){
        if(x is! Map)continue;
        final d=DateTime.tryParse((x['ophaaldatum']??'').toString());
        if(d==null||d.isBefore(today))continue;
        upcoming.add(Map<String,dynamic>.from(x));
      }
      upcoming.sort((a,b)=>(a['ophaaldatum']??'').toString().compareTo((b['ophaaldatum']??'').toString()));
      const st=FlutterSecureStorage();
      await st.write(key:'rvaz_waste_postcode',value:pc);await st.write(key:'rvaz_waste_house',value:nr);await st.write(key:'rvaz_waste_addition',value:add);await st.write(key:'rvaz_waste_bagid',value:bag);await st.write(key:'rvaz_neighborhood_place',value:(ad['woonplaats']??'').toString().trim());await st.write(key:'rvaz_neighborhood_street',value:(ad['straat']??'').toString().trim());
      if(wastePush)await registerDeviceToken();
      if(mounted)setState((){address=(ad['description']??[ad['straat'],ad['huisnummer'],ad['woonplaats']].where((x)=>x!=null&&x.toString().isNotEmpty).join(' ')).toString();dates=upcoming;});
    }catch(_){if(mounted)setState(()=>error='Dit adres of de afvalkalender kon niet worden geladen. Controleer je gegevens en probeer opnieuw.');}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> setWastePush(bool value) async {
    if(value&&address.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul eerst je adres in en laad je afvalkalender.')));return;}
    final permission=await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);
    if(value&&permission.authorizationStatus==AuthorizationStatus.denied){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sta meldingen toe om afvalherinneringen te ontvangen.')));return;}
    await const FlutterSecureStorage().write(key:'rvaz_waste_push',value:value?'1':'0');
    if(value){try{await FirebaseMessaging.instance.subscribeToTopic('afval');}catch(_){}}else{try{await FirebaseMessaging.instance.unsubscribeFromTopic('afval');}catch(_){}}
    if(mounted)setState(()=>wastePush=value);
    await registerDeviceToken();
  }
  String dateLabel(String raw){
    final d=DateTime.tryParse(raw);if(d==null)return raw;
    const days=['maandag','dinsdag','woensdag','donderdag','vrijdag','zaterdag','zondag'];
    const months=['','januari','februari','maart','april','mei','juni','juli','augustus','september','oktober','november','december'];
    final now=DateTime.now(),today=DateTime(now.year,now.month,now.day),target=DateTime(d.year,d.month,d.day);
    final diff=target.difference(today).inDays;
    if(diff==0)return'Vandaag';if(diff==1)return'Morgen';
    return '${days[d.weekday-1]} ${d.day} ${months[d.month]}';
  }
  @override Widget build(BuildContext context){
    final shown=dates.take(12).toList();
    return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Mijn afval')),body:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0C6B4E),Color(0xFF15A66F)]),borderRadius:BorderRadius.circular(18)),child:const Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Wanneer zet jij de bak buiten?',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('Vul één keer je adres in. RVAZ toont daarna jouw eerstvolgende ophaalmomenten.',style:TextStyle(color:Colors.white,height:1.35))])),SizedBox(width:12),Icon(Icons.recycling,color:Colors.white,size:46)])),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
        Row(children:[Expanded(flex:2,child:TextField(controller:postcode,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Postcode',hintText:'3235SJ'))),const SizedBox(width:8),Expanded(child:TextField(controller:house,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nr.'))),const SizedBox(width:8),Expanded(child:TextField(controller:addition,decoration:const InputDecoration(labelText:'Toev.')))]),
        const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:load,icon:const Icon(Icons.search),label:Text(busy?'Ophalen…':'Toon mijn afvalkalender')))
      ]))),
      if(busy)const Padding(padding:EdgeInsets.only(top:12),child:LinearProgressIndicator()),
      if(error.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Card(child:ListTile(leading:const Icon(Icons.info_outline,color:Colors.orange),title:Text(error)))),
      if(address.isNotEmpty)...[const SizedBox(height:16),Text(address,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:navy)),const SizedBox(height:8)],
      if(address.isNotEmpty)Card(child:SwitchListTile(value:wastePush,onChanged:setWastePush,secondary:const Icon(Icons.notifications_active_outlined,color:Color(0xFF16834B)),title:const Text('Afvalherinnering',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:const Text('Ontvang een pushmelding de avond vóór de ophaaldag'))),
      if(!busy&&address.isNotEmpty&&shown.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Er zijn geen komende ophaalmomenten gevonden.'))),
      ...shown.map((e){final id=int.tryParse('${e['afvalstroom_id']??''}')??0;final name=names[id]??'Afval';final raw=(e['ophaaldatum']??'').toString();return Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE8F7EE),child:Icon(icons[id]??Icons.delete_outline,color:const Color(0xFF16834B))),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w900,color:navy)),subtitle:Text(dateLabel(raw)),trailing:dateLabel(raw)=='Morgen'?const Chip(label:Text('MORGEN',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900))):null));}),
      if(address.isNotEmpty)const Padding(padding:EdgeInsets.fromLTRB(4,8,4,20),child:Text('Afvalgegevens worden opgehaald bij Reinis. Je adresvoorkeur wordt alleen op dit toestel bewaard.',style:TextStyle(fontSize:11,color:Colors.black54)))
    ]));
  }
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
 String displayText(dynamic x)=>decodeHtmlEntities('${x??''}'.replaceAll(RegExp(r'<[^>]*>'),''));
 List<String> vals(dynamic e,String plural,String single){final x=e is Map?e[plural]:null;if(x is List)return x.map((z)=>displayText(z)).where((z)=>z.isNotEmpty).toList();final one=displayText(v(e,single));return one.isEmpty?[]:[one];}
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
class BusinessDetailPage extends StatelessWidget{
 final dynamic item;const BusinessDetailPage({super.key,required this.item});
 String v(String k)=>item is Map?item[k]?.toString()??'':'';
 dynamic rawValue(List<String> keys){if(item is! Map)return null;for(final k in keys){final x=item[k];if(x!=null&&x.toString().trim().isNotEmpty)return x;}return null;}
 List<String> listValue(String key){final x=item is Map?item[key]:null;return x is List?x.map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():const[];}
 Map<dynamic,dynamic> hoursMap(){
  dynamic raw=rawValue(['hours','opening_hours','openingHours','openingstijden']);
  if(raw is String&&raw.trim().isNotEmpty){try{raw=jsonDecode(raw);}catch(_){}}
  if(raw is Map){for(final k in ['hours','opening_hours','openingHours','days','week']){final nested=raw[k];if(nested is Map)raw=nested;}return raw;}
  if(raw is List){final out=<dynamic,dynamic>{};for(final row in raw){if(row is Map){final day=(row['day']??row['name']??row['weekday']??'').toString().toLowerCase();if(day.isNotEmpty)out[day]=row;}}return out;}
  return <dynamic,dynamic>{};
 }
 Widget card(String title,Widget child)=>Card(margin:const EdgeInsets.only(bottom:14),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:10),child])));
 @override Widget build(BuildContext context){
  final logo=(rawValue(['logo','image'])??'').toString(),cover=v('cover'),web=v('website'),phone=v('phone'),content=(rawValue(['content','description'])??'').toString(),email=v('email'),facebook=v('facebook'),instagram=v('instagram'),linkedin=v('linkedin'),socials=v('socials');
  final additional=(rawValue(['additional_info','additionalInfo','extra_info','pro_info'])??'').toString(),category=v('category').replaceAll('&amp;','&').replaceAll('&#038;','&').replaceAll('&#38;','&'),place=v('place'),address=v('address');
  final gallery=listValue('gallery'),lat=double.tryParse(v('latitude')),lng=double.tryParse(v('longitude')),isPro=_businessIsPro(item),hours=hoursMap();
  const days={'monday':'Maandag','tuesday':'Dinsdag','wednesday':'Woensdag','thursday':'Donderdag','friday':'Vrijdag','saturday':'Zaterdag','sunday':'Zondag'};
  final hourRows=<Widget>[];
  days.forEach((key,label){final aliases=<String,List<String>>{'monday':['maandag','mon'],'tuesday':['dinsdag','tue'],'wednesday':['woensdag','wed'],'thursday':['donderdag','thu'],'friday':['vrijdag','fri'],'saturday':['zaterdag','sat'],'sunday':['zondag','sun']};dynamic d=hours[key]??hours[label.toLowerCase()]??hours[label];for(final a in aliases[key]??const <String>[]){d??=hours[a];}var text='Niet opgegeven';if(d is Map){final closed=d['closed']==1||d['closed']==true||d['closed']=='1';final open=(d['open']??d['from']??d['start']??d['opens']??'').toString().trim(),close=(d['close']??d['to']??d['end']??d['closes']??'').toString().trim();if(closed){text='Gesloten';}else if(open.isNotEmpty||close.isNotEmpty){text=[open,close].where((z)=>z.isNotEmpty).join(' – ');}}else if(d!=null&&d.toString().trim().isNotEmpty){text=d.toString().trim();}hourRows.add(Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[SizedBox(width:105,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w700))),Expanded(child:Text(text))])));});
  final contact=<Widget>[
   if(phone.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.phone_outlined),title:Text(phone),onTap:()=>launchUrl(Uri(scheme:'tel',path:phone))),
   if(isPro&&email.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.email_outlined),title:Text(email),onTap:()=>launchUrl(Uri(scheme:'mailto',path:email))),
   if(isPro&&web.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.language),title:const Text('Website'),subtitle:Text(web),onTap:()=>launchUrl(Uri.parse(web),mode:LaunchMode.externalApplication)),
   if(isPro&&facebook.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.facebook),title:const Text('Facebook'),onTap:()=>launchUrl(Uri.parse(facebook),mode:LaunchMode.externalApplication)),
   if(isPro&&instagram.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.camera_alt_outlined),title:const Text('Instagram'),onTap:()=>launchUrl(Uri.parse(instagram),mode:LaunchMode.externalApplication)),
   if(isPro&&linkedin.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.link),title:const Text('LinkedIn'),onTap:()=>launchUrl(Uri.parse(linkedin),mode:LaunchMode.externalApplication)),
   if(isPro&&socials.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text(socials)),
  ];
  return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(v('title')),actions:[PageFeedbackButton(page:'Bedrijvengids',detail:v('title'))]),body:ListView(children:[
   SizedBox(height:245,child:Stack(fit:StackFit.expand,children:[
    if(cover.isNotEmpty)Image.network(cover,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF073B63),Color(0xFF0B6FA4)]))))else Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF073B63),Color(0xFF0B6FA4)]))),
    Container(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black.withValues(alpha:.58)]))),
    Positioned(left:18,right:18,bottom:18,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
     Container(width:78,height:78,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(39),border:Border.all(color:Colors.white,width:3)),clipBehavior:Clip.antiAlias,child:logo.isEmpty?const Icon(Icons.storefront,size:38,color:navy):Image.network(logo,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.storefront,size:38,color:navy))),
     const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(spacing:6,runSpacing:5,children:[if(isPro)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:const Color(0xFFFFD54F),borderRadius:BorderRadius.circular(5)),child:const Text('PRO',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:navy))),if(category.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.92),borderRadius:BorderRadius.circular(5)),child:Text(category,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:navy)))]),
      const SizedBox(height:6),Text(v('title'),style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),if(place.isNotEmpty)Text(place,style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w600))
     ]))
    ]))
   ])),
   Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(content.isNotEmpty)card('Over ${v('title')}',Html(data:cleanArticleHtml(content))),
    if(contact.isNotEmpty)card('Contact',Column(children:contact)),
    if(isPro&&int.tryParse(v('id'))!=null)Card(margin:const EdgeInsets.only(bottom:14),child:Padding(padding:const EdgeInsets.all(16),child:BusinessVoucherSection(businessId:int.parse(v('id'))))),
    if(address.isNotEmpty||lat!=null&&lng!=null)card('Locatie',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     if(address.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.location_on_outlined),const SizedBox(width:8),Expanded(child:Text(address))])),
     if(lat!=null&&lng!=null)ClipRRect(borderRadius:BorderRadius.circular(12),child:SizedBox(height:220,child:fmap.FlutterMap(options:fmap.MapOptions(initialCenter:LatLng(lat,lng),initialZoom:15),children:[fmap.TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'nl.regiovoorneaanzee.app'),fmap.MarkerLayer(markers:[fmap.Marker(point:LatLng(lat,lng),width:44,height:44,child:const Icon(Icons.location_pin,color:navy,size:42))])])))
    ])),
    card('Openingstijden',Column(children:hourRows)),
    if(gallery.isNotEmpty)card("Foto's",Wrap(spacing:8,runSpacing:8,children:gallery.take(3).map((url)=>ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network(url,width:(MediaQuery.sizeOf(context).width-64)/2,height:125,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()))).toList())),
    if(isPro&&additional.isNotEmpty)card('Extra informatie',Html(data:cleanArticleHtml(additional))),
   ]))
  ]));
 }
}
Future<Map<String,dynamic>> _editorialCapabilities()async{try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/editorial/capabilities'),headers:await authHeaders());if(r.statusCode==200)return Map<String,dynamic>.from(jsonDecode(r.body));}catch(_){}return{};}

class TipPage extends StatefulWidget{final String? p2000Reference;const TipPage({super.key,this.p2000Reference});@override State<TipPage> createState()=>_TipPageState();}
class _TipPageState extends State<TipPage>{final subject=TextEditingController(),place=TextEditingController(),body=TextEditingController(),name=TextEditingController(),email=TextEditingController();final photos=<XFile>[];XFile? video;bool busy=false,logged=false,rights=false;@override void initState(){super.initState();loadUser();}Future<void>loadUser()async{try{final h=await authHeaders();if(h.containsKey('Authorization')){final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/me'),headers:h);if(r.statusCode==200){final u=Map<String,dynamic>.from(jsonDecode(r.body)['user']??{});name.text=u['name']?.toString()??'';email.text=u['email']?.toString()??'';if(mounted)setState(()=>logged=true);}}}catch(_){}}
Future<void>pick()async{if(photos.length>=5)return;final x=await ImagePicker().pickMultiImage(imageQuality:88);if(!mounted)return;setState((){for(final f in x){if(photos.length<5){photos.add(f);}}});}
Future<void>camera()async{if(photos.length>=5)return;final x=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:88);if(x!=null&&mounted)setState(()=>photos.add(x));}
Future<void>pickVideo()async{final x=await ImagePicker().pickVideo(source:ImageSource.gallery,maxDuration:const Duration(minutes:2));if(x!=null&&mounted)setState(()=>video=x);}
Future<void>send()async{final s=subject.text.trim(),b=body.text.trim();if(s.isEmpty||b.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul een onderwerp in en omschrijf wat er gaande is.')));return;}if(!logged&&(name.text.trim().isEmpty||email.text.trim().isEmpty)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vul je naam en e-mailadres in.')));return;}if((photos.isNotEmpty||video!=null)&&!rights){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bevestig eerst dat je de rechten op de foto’s bezit.')));return;}setState(()=>busy=true);try{final req=http.MultipartRequest('POST',Uri.parse('$site/wp-json/rvaz-app/v1/tip'));req.headers.addAll(await authHeaders());req.fields.addAll({'subject':s,'place':place.text.trim(),'text':b,'name':name.text.trim(),'email':email.text.trim(),'photo_rights':rights?'1':'0','submitted_at':DateTime.now().toIso8601String(),if(widget.p2000Reference!=null&&widget.p2000Reference!.isNotEmpty)'p2000_reference':widget.p2000Reference!});for(var i=0;i<photos.length;i++){req.files.add(await http.MultipartFile.fromPath('photo_$i',photos[i].path));}if(video!=null){req.files.add(await http.MultipartFile.fromPath('video_0',video!.path));}final r=await req.send().timeout(const Duration(seconds:30));if(!mounted)return;setState(()=>busy=false);if(r.statusCode>=200&&r.statusCode<300){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bedankt! Je tip is ontvangen. Je krijgt een bevestiging per e-mail.')));Navigator.pop(context);}else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Versturen mislukt (${r.statusCode}). Probeer opnieuw.')));}}catch(_){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding. Je tip is niet verstuurd.')));}}}
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Tip de redactie')),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Iets gezien of gebeurt er iets?',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),const Text('Vertel de redactie wat er gaande is. Voeg eventueel foto’s of een korte video toe van bijvoorbeeld een brand, ongeval of gebeurtenis.'),const SizedBox(height:10),const Row(children:[Icon(Icons.schedule,size:17,color:Colors.black54),SizedBox(width:6),Expanded(child:Text('Datum en tijd worden automatisch met je tip meegestuurd.',style:TextStyle(fontSize:12,color:Colors.black54)))]),const SizedBox(height:16),if(widget.p2000Reference!=null&&widget.p2000Reference!.isNotEmpty)...[Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Deze tip gaat over deze P2000-melding:',style:TextStyle(fontWeight:FontWeight.w800,color:navy)),const SizedBox(height:6),Text(widget.p2000Reference!),const SizedBox(height:6),const Text('Deze melding wordt automatisch met je tip meegestuurd.',style:TextStyle(fontSize:12,color:Colors.black54))]))),const SizedBox(height:12)],if(!logged)...[TextField(controller:name,decoration:const InputDecoration(labelText:'Naam')),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mailadres')),const SizedBox(height:8)]else const Text('Je naam en e-mailadres worden automatisch uit je RVAZ-account gebruikt.',style:TextStyle(color:Colors.black54)),TextField(controller:subject,decoration:const InputDecoration(labelText:'Onderwerp *')),TextField(controller:place,decoration:const InputDecoration(labelText:'Plaats / locatie')),const SizedBox(height:12),TextField(controller:body,minLines:7,maxLines:14,decoration:const InputDecoration(labelText:'Wat is er gaande / gebeurd? *',border:OutlineInputBorder())),const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:photos.length>=5?null:pick,icon:const Icon(Icons.photo_library_outlined),label:const Text('Foto’s kiezen'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:photos.length>=5?null:camera,icon:const Icon(Icons.photo_camera_outlined),label:const Text('Foto maken')))]),if(photos.isNotEmpty)...[const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[for(var i=0;i<photos.length;i++)Chip(label:Text('Foto ${i+1}'),onDeleted:()=>setState(()=>photos.removeAt(i)))])],const SizedBox(height:8),Text('${photos.length}/5 foto’s',style:const TextStyle(color:Colors.black54)),const SizedBox(height:8),OutlinedButton.icon(onPressed:video==null?pickVideo:null,icon:const Icon(Icons.videocam_outlined),label:Text(video==null?'Video kiezen (max. 2 min.)':'Video gekozen')),if(video!=null)Align(alignment:Alignment.centerLeft,child:Chip(label:const Text('Video'),onDeleted:()=>setState(()=>video=null))),CheckboxListTile(contentPadding:EdgeInsets.zero,value:rights,onChanged:(photos.isEmpty&&video==null)?null:(v)=>setState(()=>rights=v??false),title:const Text('Ik heb deze foto’s/video zelf gemaakt en bezit de rechten.'),subtitle:const Text('Door het materiaal te versturen geef ik Regio Voorne aan Zee toestemming het redactioneel te gebruiken.')),const SizedBox(height:12),FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.send),label:Text(busy?'Versturen…':'Tip versturen'))]));}

class EditorialSubmitPage extends StatefulWidget{const EditorialSubmitPage({super.key});@override State<EditorialSubmitPage> createState()=>_EditorialSubmitPageState();}
class _EditorialSubmitPageState extends State<EditorialSubmitPage>{final title=TextEditingController(),content=TextEditingController();List<dynamic> cats=[];int? cat;XFile? featured;final gallery=<XFile>[];bool membersOnly=false,push=false,busy=false;@override void initState(){super.initState();load();}Future<void>load()async{try{final r=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/editorial/categories'),headers:await authHeaders());if(r.statusCode==200&&mounted)setState(()=>cats=List<dynamic>.from(jsonDecode(r.body)));}catch(_){}}
Future<void>pickFeatured()async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:90);if(x!=null&&mounted)setState(()=>featured=x);}
Future<void>pickGallery()async{final x=await ImagePicker().pickMultiImage(imageQuality:88);if(mounted)setState((){for(final f in x){if(gallery.length<10){gallery.add(f);}}});}
Future<void>send()async{if(title.text.trim().isEmpty||content.text.trim().isEmpty||cat==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Titel, categorie en bericht zijn verplicht.')));return;}setState(()=>busy=true);try{final req=http.MultipartRequest('POST',Uri.parse('$site/wp-json/rvaz-app/v1/editorial/submit'));req.headers.addAll(await authHeaders());req.fields.addAll({'title':title.text.trim(),'content':content.text.trim(),'category':cat.toString(),'members_only':membersOnly?'1':'','push':push?'1':''});if(featured!=null){req.files.add(await http.MultipartFile.fromPath('featured',featured!.path));}for(var i=0;i<gallery.length;i++){req.files.add(await http.MultipartFile.fromPath('gallery_$i',gallery[i].path));}final r=await req.send().timeout(const Duration(seconds:45));if(!mounted)return;setState(()=>busy=false);if(r.statusCode>=200&&r.statusCode<300){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nieuwsbericht is ingediend en wacht op goedkeuring.')));Navigator.pop(context);}else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Indienen mislukt (${r.statusCode}).')));}}catch(_){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geen verbinding. Bericht is niet ingediend.')));}}}
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Nieuws insturen (redactieleden)'),backgroundColor:const Color(0xFF073B63),foregroundColor:Colors.white),body:ListView(padding:const EdgeInsets.all(16),children:[
_editorialField(Icons.title,'Titel','Geef je artikel een duidelijke titel',TextField(controller:title,decoration:const InputDecoration(hintText:'Titel van het nieuwsbericht'))),const SizedBox(height:10),
_editorialField(Icons.category_outlined,'Categorie','Kies een categorie',DropdownButtonFormField<int>(initialValue:cat,isExpanded:true,decoration:const InputDecoration(hintText:'Kies categorie'),items:cats.map<DropdownMenuItem<int>>((e)=>DropdownMenuItem(value:int.tryParse(e['id'].toString()),child:Text(decodeHtmlEntities(e['name'].toString())))).toList(),onChanged:(v)=>setState(()=>cat=v))),const SizedBox(height:10),
_editorialField(Icons.article_outlined,'Tekst','Schrijf je nieuwsbericht',TextField(controller:content,minLines:8,maxLines:24,decoration:const InputDecoration(hintText:'Nieuwsbericht'))),const SizedBox(height:10),
_editorialField(Icons.photo_library_outlined,'Foto’s','Voeg foto’s toe',Column(children:[SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:pickFeatured,icon:const Icon(Icons.image_outlined),label:Text(featured==null?'Uitgelichte foto kiezen':'Uitgelichte foto gekozen'))),const SizedBox(height:6),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:gallery.length>=10?null:pickGallery,icon:const Icon(Icons.collections_outlined),label:Text('Foto’s onder bericht (${gallery.length})'))),if(gallery.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Wrap(spacing:8,children:[for(var i=0;i<gallery.length;i++)Chip(label:Text('Foto ${i+1}'),onDeleted:()=>setState(()=>gallery.removeAt(i)))]))])),const SizedBox(height:10),
_editorialField(Icons.lock_outline,'Zichtbaarheid','Bepaal wie het volledige bericht kan lezen',SwitchListTile(contentPadding:EdgeInsets.zero,value:membersOnly,onChanged:(v)=>setState(()=>membersOnly=v),title:const Text('Alleen voor geregistreerde gebruikers'),subtitle:const Text('Volledig bericht alleen na inloggen'))),const SizedBox(height:10),
_editorialField(Icons.notifications_none,'Publicatie','Opties na goedkeuring',SwitchListTile(contentPadding:EdgeInsets.zero,value:push,onChanged:(v)=>setState(()=>push=v),title:const Text('Push via de app na goedkeuring'),subtitle:const Text('Wordt pas verstuurd wanneer het bericht is goedgekeurd en gepubliceerd.'))),const SizedBox(height:14),
SizedBox(height:50,width:double.infinity,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.blue,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),onPressed:busy?null:send,icon:const Icon(Icons.send_outlined),label:Text(busy?'Versturen…':'Versturen naar redactie',style:const TextStyle(fontWeight:FontWeight.w800)))),const SizedBox(height:12),
const Text('Voor redactieleden blijft ‘Nieuws insturen’ beschikbaar. Je bericht wordt eerst ter goedkeuring aan de eindredactie aangeboden.',style:TextStyle(color:Colors.black54,height:1.35)),
]));
Widget _editorialField(IconData icon,String titleText,String subtitle,Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFFEAF2FF),borderRadius:BorderRadius.circular(9)),child:Icon(icon,color:navy,size:21)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(titleText,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(fontSize:12,color:Colors.black54))]))]),const SizedBox(height:12),child])));
}
class InAppWebPage extends StatelessWidget{final String title,url;const InAppWebPage({super.key,required this.title,required this.url});@override Widget build(BuildContext c)=>Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:Text(title)),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.ads_click,size:44,color:navy),const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:10),const Text('Advertentielink. Je verlaat de app alleen wanneer je hieronder kiest om de bestemming te openen.'),const SizedBox(height:16),FilledButton(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),child:const Text('Open bestemming'))]))));}


String decodeHtmlEntities(String value) {
  var out=value.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'),(m){
    final raw=m.group(1)!;
    final code=raw.toLowerCase().startsWith('x')?int.tryParse(raw.substring(1),radix:16):int.tryParse(raw);
    return code==null?m.group(0)!:String.fromCharCode(code);
  });
  const named={'&amp;':'&','&quot;':'"','&apos;':"'",'&#39;':"'",'&lt;':'<','&gt;':'>'};
  named.forEach((k,v)=>out=out.replaceAll(k,v));
  return out;
}

class EventDetailPage extends StatelessWidget{final dynamic event;const EventDetailPage({super.key,required this.event});String v(List<String> keys){for(final k in keys){final x=event[k];if(x!=null&&'$x'.trim().isNotEmpty)return '$x';}return'';}String title(){final x=event['title'];return decodeHtmlEntities(x is Map?'${x['rendered']??''}':'${x??''}');}String category(){final x=event['category']??event['categories']??event['event_category'];String raw;if(x is List){raw=x.map((e)=>e is Map?(e['name']??e['title']??''):'$e').where((e)=>'$e'.isNotEmpty).join(', ');}else if(x is Map){raw='${x['name']??x['title']??''}';}else{raw=x?.toString()??'';}return decodeHtmlEntities(raw);}String address(){final full=v(['full_address','address']);if(full.isNotEmpty)return full;final street=v(['street','straat','location']),nr=v(['house_number','number','huisnummer']),zip=v(['postcode','postal_code']),city=v(['place','city','town','plaats']);final first=[street,nr].where((x)=>x.isNotEmpty).join(' '),second=[zip,city].where((x)=>x.isNotEmpty).join(' ');return[first,second].where((x)=>x.isNotEmpty).join('\n');}
DateTime? eventStart(){final raw=v(['start_date','event_start_date','event_date','start','date','datum','datetime']);return DateTime.tryParse(raw);}
DateTime? eventEnd(){final raw=v(['end_date','event_end_date','end']);return DateTime.tryParse(raw);}
Future<void> addToCalendar(BuildContext context)async{final start=eventStart();if(start==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Voor dit evenement ontbreekt een geldige datum.')));return;}final end=eventEnd()??start.add(const Duration(hours:2));final event=Event(title:title(),description:v(['excerpt','description']),location:[v(['venue','location_name']),address()].where((x)=>x.isNotEmpty).join(', '),startDate:start,endDate:end);await Add2Calendar.addEvent2Cal(event);}
@override Widget build(BuildContext context){final image=v(['image','featured_image']),html=v(['content','description']),venue=v(['venue','location_name']),addr=address(),cat=category();return Scaffold(backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(backgroundColor:Colors.white,foregroundColor:navy,title:const LogoMark()),body:ListView(children:[if(image.isNotEmpty)Image.network(image,height:230,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('AGENDA',style:TextStyle(color:cyan,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(title(),style:const TextStyle(fontSize:28,height:1.1,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:16),if(v(['display_date','start_date','date']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month,color:navy),title:Text(v(['display_date','start_date','date'])),subtitle:v(['time','start_time']).isNotEmpty?Text(v(['time','start_time'])):null),if(cat.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.category_outlined,color:navy),title:Text(cat)),if(venue.isNotEmpty||addr.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined,color:navy),title:Text(venue.isNotEmpty?venue:addr),subtitle:venue.isNotEmpty&&addr.isNotEmpty?Text(addr):null),if(v(['organizer','organisation','organisatie']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.groups_outlined,color:navy),title:Text(v(['organizer','organisation','organisatie']))),if(v(['price','kosten']).isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.euro_outlined,color:navy),title:Text(v(['price','kosten']))),const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>addToCalendar(context),icon:const Icon(Icons.event_available_outlined),label:const Text('Toevoegen aan agenda'))),const Divider(height:28),if(html.isNotEmpty)Html(data:html,style:{'body':Style(fontSize:FontSize(16),lineHeight:const LineHeight(1.5),margin:Margins.zero)}),if(html.isEmpty&&v(['excerpt']).isNotEmpty)Text(v(['excerpt']),style:const TextStyle(fontSize:16,height:1.5))]))]));}}


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