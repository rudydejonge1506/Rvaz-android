part of 'main.dart';

const newsroomPale = Color(0xFFE5F4FB);
const newsroomLine = Color(0xFFD9E5ED);
const newsroomHeading = RvazTypography.heading;

class NewsroomHeading extends StatelessWidget {
 final String title; final String? action; final VoidCallback? onTap;
 const NewsroomHeading(this.title,{super.key,this.action,this.onTap});
 @override Widget build(BuildContext context)=>Container(
  color:newsroomPale,child:Row(children:[Expanded(child:Padding(
   padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
   child:Text(title,style:newsroomHeading.copyWith(fontSize:MediaQuery.sizeOf(context).width<=760?22:23)))),
   if(action!=null)TextButton(onPressed:onTap,child:Text(action!))]));
}

class NewsroomBatch {
 final List<dynamic> posts; final bool hasMore;
 const NewsroomBatch(this.posts,this.hasMore);
}
typedef NewsroomLoader=Future<NewsroomBatch> Function(int page,String before);

Future<NewsroomBatch> loadNewsroomBatch(int page,String before,{int? categoryId,http.Client? client}) async {
 // Request only public listing metadata. Full article content is obtained via
 // the existing protected App API when the reader opens an article.
 // Keep list separators literal: the production site's redirect path encodes
 // percent-escaped separators a second time, producing empty metadata fields.
 final cursor=before.isEmpty?'':DateTime.parse(before).toUtc().toIso8601String();
 final uri=Uri.parse('https://www.regiovoorneaanzee.nl/wp-json/wp/v2/posts?per_page=15&page=$page&orderby=date&order=desc&_embed=wp:featuredmedia,wp:term&_fields=id,title,date,date_gmt,link,_links,_embedded${cursor.isEmpty?'':'&before=$cursor'}${categoryId==null?'':'&categories=$categoryId'}');
 final request=client==null?http.get(uri,headers:const {'Accept':'application/json'}):client.get(uri,headers:const {'Accept':'application/json'});
 final r=await request.timeout(const Duration(seconds:20));
 if(r.statusCode==400){final d=jsonDecode(r.body);if(d is Map&&d['code']=='rest_post_invalid_page_number')return const NewsroomBatch([],false);}
 if(r.statusCode!=200)throw Exception('Nieuws ophalen: HTTP ${r.statusCode}');
 final raw=List<dynamic>.from(jsonDecode(r.body));
 final posts=raw.map((item){
  if(item is! Map||item['id']==null)throw const FormatException('Ongeldige nieuwsmetadata ontvangen');
  final p=Map<String,dynamic>.from(item);
  final embed=p['_embedded'];
  final media=embed is Map?embed['wp:featuredmedia']:null;
  if(media is List&&media.isNotEmpty&&media.first is Map){
   final m=media.first as Map;final details=m['media_details'];
   final sizes=details is Map?details['sizes']:null;
   final large=sizes is Map?sizes['large']:null;
   p['image']=(large is Map?large['source_url']:null)??m['source_url']??'';
  }
  final terms=embed is Map?embed['wp:term']:null;
  if(terms is List){for(final group in terms){if(group is List&&group.isNotEmpty&&group.first is Map){p['place']=group.first['name'];break;}}}
  p['needs_fetch']=true;
  return p;
 }).toList();
 final total=int.tryParse(r.headers['x-wp-totalpages']??'');
 return NewsroomBatch(posts,total==null?raw.length==15:page<total);
}

class NewsroomFeed extends StatefulWidget {
 final NewsroomLoader? loader; final bool showPromotions,showTopics; final String heading,emptyText;
 const NewsroomFeed({super.key,this.loader,this.showPromotions=true,this.showTopics=true,this.heading='Laatste nieuws',this.emptyText='Er zijn nog geen nieuwsberichten.'});
 @override State<NewsroomFeed> createState()=>_NewsroomFeedState();
}
class _NewsroomFeedState extends State<NewsroomFeed> with AutomaticKeepAliveClientMixin {
 final posts=<dynamic>[];
 final scroll=ScrollController();
 int page=0; bool busy=false,more=true; String error='',before='';
 late final Future<List<dynamic>> businesses=widget.showPromotions?loadBusinesses():Future.value([]);
 late final Future<Map<String,dynamic>> editorial=widget.showPromotions?_editorialCapabilities():Future.value({});
 late final Future<List<AppAd>> ads=widget.showPromotions?loadAppAds(placement:'home'):Future.value([]);
 @override bool get wantKeepAlive=>true;
 @override void initState(){super.initState();load();}
 @override void dispose(){scroll.dispose();super.dispose();}
 Future<void> load({bool refresh=false}) async {
  if(busy)return;
  setState((){busy=true;error='';});
  final next=refresh?1:page+1;
  // A fixed upper date keeps pagination stable while new stories are published.
  final cursor=refresh||before.isEmpty?DateTime.now().toUtc().toIso8601String():before;
  try{
   final batch=await(widget.loader??loadNewsroomBatch)(next,cursor);
   if(!mounted)return;
   setState((){
    if(refresh)posts.clear();
    final ids=posts.map((p)=>'${p['id']}').toSet();
    posts.addAll(batch.posts.where((p)=>ids.add('${p['id']}')));
    page=next;before=cursor;more=batch.hasMore;
   });
  }catch(e){debugPrint('RVAZ news list: $e');if(mounted)setState(()=>error='Nieuws laden is niet gelukt. Probeer het opnieuw.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
  super.build(context);
  return RefreshIndicator(onRefresh:()=>load(refresh:true),child:ListView(
   key:PageStorageKey('newsroom-feed-${widget.heading}'),controller:scroll,
   physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,8,16,24),
   children:[
    if(widget.showTopics)SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
     _topic('Alles',()=>load(refresh:true),active:true),
     _topic('Plaatsen',()=>ShellTabController.select('places')),
     _topic('112 & P2000',()=>ShellTabController.select('emergency')),
     _topic('Wonen',()=>ShellTabController.select('wonen')),
     _topic('Vouchers',()=>ShellTabController.select('vouchers')),
    ])),
    if(widget.showPromotions)FutureBuilder<Map<String,dynamic>>(future:editorial,builder:(context,s)=>s.data?['can_submit_news']==true?ListTile(leading:const Icon(Icons.edit_note),title:const Text('Nieuws insturen'),subtitle:const Text('Voor redactieleden'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EditorialSubmitPage()))):const SizedBox.shrink()),
    const SizedBox(height:12),NewsroomHeading(widget.heading),
    if(posts.isNotEmpty)...[
     NewsroomArticleTile(post:posts.first,lead:true),
     for(var i=1;i<posts.length;i++)...[
      NewsroomArticleTile(post:posts[i]),
      if(i==3&&widget.showPromotions)NewsroomProBusinesses(items:businesses),
      if(widget.showPromotions&&i%6==0)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:RotatingAppAd(future:ads)),
      if(widget.showPromotions&&i==8)const Center(child:RvazAdBanner()),
     ],
     if(posts.length<4&&widget.showPromotions)NewsroomProBusinesses(items:businesses),
    ],
    if(error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Text(error)),
    if(busy)const Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator())),
    if(!busy&&(more||error.isNotEmpty))Padding(padding:const EdgeInsets.symmetric(vertical:18),child:SizedBox(width:double.infinity,
     child:FilledButton.icon(key:const ValueKey('newsroom-load-more'),onPressed:()=>load(),
      icon:const Icon(Icons.expand_more),label:Text(error.isNotEmpty?'Opnieuw proberen':'Meer laden')))),
    if(!busy&&!more&&posts.isNotEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Text('Je hebt alle nieuwsberichten bekeken.',textAlign:TextAlign.center)),
    if(!busy&&posts.isEmpty&&error.isEmpty)Padding(padding:const EdgeInsets.all(24),child:Text(widget.emptyText)),
    if(widget.showPromotions)...[
     const SizedBox(height:12),
     NewsroomHeading('Wonen',action:'Alle woningen →',onTap:()=>ShellTabController.select('wonen')),
     const FeaturedHomes(),
     ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.home_outlined,color:navy),title:const Text('Ontdek het woningaanbod in de regio'),trailing:const Icon(Icons.chevron_right),onTap:()=>ShellTabController.select('wonen')),
     const SizedBox(height:16),
     NewsroomHeading('Familieberichten',action:'Bekijken →',onTap:()=>ShellTabController.select('family')),
     const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Text('De momenten die ertoe doen. Bekijk familieberichten of maak je eigen kaart.')),
     OutlinedButton.icon(onPressed:()=>ShellTabController.select('family'),icon:const Icon(Icons.favorite_border),label:const Text('Naar familieberichten')),
     const SizedBox(height:16),RotatingAppAd(future:ads),
    ],
   ]));
 }
 Widget _topic(String text,VoidCallback onTap,{bool active=false})=>Padding(padding:const EdgeInsets.only(right:8),child:TextButton(
  onPressed:onTap,style:TextButton.styleFrom(foregroundColor:active?cyan:navy,minimumSize:const Size(48,48),
   shape:const RoundedRectangleBorder(),side:active?const BorderSide(color:cyan):null),child:Text(text)));
}

class NewsroomArticleTile extends StatelessWidget {
 final dynamic post; final bool lead;
 const NewsroomArticleTile({super.key,required this.post,this.lead=false});
 @override Widget build(BuildContext context){
  final raw=post['title'];final title=decodeHtmlEntities('${raw is Map?raw['rendered']??'':raw??''}'.replaceAll(RegExp(r'<[^>]*>'),''));
  final image=postImage(post);
  Widget photo()=>image.isEmpty?const ColoredBox(color:newsroomPale,child:Center(child:Icon(Icons.newspaper,color:navy))):Image.network(image,
   fit:BoxFit.cover,width:double.infinity,cacheWidth:lead?1000:280,
   errorBuilder:(_,__,___)=>const ColoredBox(color:newsroomPale,child:Center(child:Icon(Icons.newspaper,color:navy))));
  final meta=[if('${post['place']??''}'.isNotEmpty)'${post['place']}',formatPostDate(post)].where((x)=>x.isNotEmpty).join(' · ');
  return Material(color:Colors.white,child:InkWell(onTap:()=>openArticle(context,post),child:Container(
   padding:EdgeInsets.symmetric(vertical:lead?14:12),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:newsroomLine))),
   child:lead?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Semantics(label:'Uitgelicht nieuws: $title',image:true,child:AspectRatio(aspectRatio:16/9,child:photo())),const SizedBox(height:10),
    Text(title,style:newsroomHeading.copyWith(fontSize:27)),const SizedBox(height:7),
    Text(meta,style:const TextStyle(fontSize:12,color:Color(0xFF63788C))),
   ]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    SizedBox(width:104,child:AspectRatio(aspectRatio:4/3,child:photo())),const SizedBox(width:12),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(title,style:newsroomHeading.copyWith(fontSize:20)),const SizedBox(height:6),
     Text(meta,style:const TextStyle(fontSize:11,color:Color(0xFF63788C))),
    ])),
   ]))));
 }
}

class NewsroomProBusinesses extends StatelessWidget {
 final Future<List<dynamic>> items;
 const NewsroomProBusinesses({super.key,required this.items});
 @override Widget build(BuildContext context)=>FutureBuilder<List<dynamic>>(future:items,builder:(context,s){
  final pros=(s.data??[]).where(_businessIsPro).toList();
  if(pros.isEmpty)return const SizedBox.shrink();
  return Padding(padding:const EdgeInsets.symmetric(vertical:20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   NewsroomHeading('PRO-bedrijven',action:'Alle bedrijven →',onTap:()=>ShellTabController.select('businesses')),
   const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Onze lokale ondernemers',style:TextStyle(fontSize:13,color:Color(0xFF63788C)))),
   for(final e in pros)Material(color:newsroomPale,child:ListTile(
    contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
    leading:SizedBox(width:64,height:64,child:'${e['image']??''}'.isEmpty?const Icon(Icons.storefront_outlined,color:navy):Image.network('${e['image']}',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.storefront_outlined,color:navy))),
    title:Text(decodeHtmlEntities('${e['title']??''}'),style:newsroomHeading.copyWith(fontSize:22)),
    subtitle:Text('${e['place']??e['plaats']??'Lokaal ondernemen'}'),
    trailing:const Chip(label:Text('PRO')),
    onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessDetailPage(item:e))),
   )),
  ]));
 });
}


/// Resolve the existing WordPress place category, then paginate its full archive.
/// Never filter only the latest site-wide posts by a title/place substring.
class PlaceNewsSource {
 final String place;
 final http.Client? client;
 int? categoryId;
 PlaceNewsSource(this.place,{this.client});
 Future<NewsroomBatch> call(int page,String before) async {
  if(categoryId==null){
   final slug=Uri.encodeQueryComponent(place.trim().toLowerCase().replaceAll(' ','-'));
   final uri=Uri.parse('https://www.regiovoorneaanzee.nl/wp-json/wp/v2/categories?slug=$slug&_fields=id,slug');
   final request=client==null?http.get(uri,headers:const {'Accept':'application/json'}):client!.get(uri,headers:const {'Accept':'application/json'});
   final response=await request.timeout(const Duration(seconds:20));
   if(response.statusCode!=200)throw Exception('Plaatsarchief kon niet worden opgehaald.');
   final rows=jsonDecode(response.body);
   if(rows is! List||rows.length!=1||rows.first is! Map||rows.first['id'] is! int)throw Exception('Geen plaatsarchief gevonden voor $place.');
   categoryId=rows.first['id'] as int;
  }
  final batch=await loadNewsroomBatch(page,before,categoryId:categoryId,client:client);
  return NewsroomBatch(batch.posts.map((p)=>{...Map<String,dynamic>.from(p),'place':place}).toList(),batch.hasMore);
 }
}
