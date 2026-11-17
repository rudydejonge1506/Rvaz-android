part of 'main.dart';

class FavoritesService {
 static Future<List<dynamic>> load({http.Client? client}) async {
  final uri=Uri.parse('$site/wp-json/rvaz-app/v1/saved'),headers=await authHeaders();
  if(!headers.containsKey('Authorization'))throw Exception('Log eerst in bij Account.');
  final request=client==null?http.get(uri,headers:headers):client.get(uri,headers:headers);
  final response=await request.timeout(const Duration(seconds:15));
  if(response.statusCode!=200)throw Exception('Favorieten konden niet worden geladen. Probeer opnieuw.');
  final data=jsonDecode(response.body);
  if(data is List)return List<dynamic>.from(data);
  if(data is Map&&data['items'] is List)return List<dynamic>.from(data['items']);
  throw const FormatException('Onbekende reactie voor favorieten.');
 }
 static Future<bool> set(dynamic post,{required bool saved,http.Client? client})async{
  final id=int.tryParse('${post['id']??post['post_id']??''}');
  if(id==null)return false;
  final headers=await authHeaders();if(!headers.containsKey('Authorization'))return false;
  headers['Content-Type']='application/json';
  final uri=Uri.parse('$site/wp-json/rvaz-app/v1/saved');
  for(final key in ['post_id','id']){
   try{
    final payload=jsonEncode({key:id,'saved':saved});
    final request=client==null?http.post(uri,headers:headers,body:payload):client.post(uri,headers:headers,body:payload);
    final response=await request.timeout(const Duration(seconds:15));
    if(response.statusCode>=200&&response.statusCode<300){
     final body=jsonDecode(response.body);
     return body is Map&&body['saved']==saved;
    }
   }catch(_){}
  }
  return false;
 }
}
Future<bool> saveArticle(dynamic post,{bool saved=true})=>FavoritesService.set(post,saved:saved);

class SavedPage extends StatefulWidget {
 final Future<List<dynamic>> Function()? loader;
 final Future<bool> Function(dynamic post,bool saved)? update;
 const SavedPage({super.key,this.loader,this.update});
 @override State<SavedPage> createState()=>_SavedPageState();
}
class _SavedPageState extends State<SavedPage> {
 late Future<List<dynamic>> future;
 final removing=<String>{};
 @override void initState(){super.initState();future=(widget.loader??FavoritesService.load)();}
 Future<void> refresh()async{setState(()=>future=(widget.loader??FavoritesService.load)());await future;}
 Future<void> remove(dynamic post,List<dynamic> items)async{
  final id='${post['id']??post['post_id']}';setState(()=>removing.add(id));
  final ok=await(widget.update?.call(post,false)??saveArticle(post,saved:false));
  if(!mounted)return;
  setState((){removing.remove(id);if(ok)future=Future.value(items.where((p)=>'${p['id']??p['post_id']}'!=id).toList());});
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'Artikel uit je favorieten verwijderd.':'Verwijderen is niet gelukt. Probeer opnieuw.')));
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.white,appBar:AppBar(title:const Text('Bewaarde artikelen')),body:FutureBuilder<List<dynamic>>(future:future,builder:(context,snapshot){
  if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
  if(snapshot.hasError)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${snapshot.error}'),TextButton(onPressed:refresh,child:const Text('Opnieuw proberen'))]));
  final items=snapshot.data??[];
  return RefreshIndicator(onRefresh:refresh,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),children:[
   const NewsroomHeading('Mijn favorieten'),const SizedBox(height:16),
   if(items.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Text('Je hebt nog geen artikelen bewaard.')),
   for(final post in items)ListTile(contentPadding:const EdgeInsets.symmetric(vertical:12),
    title:Text(decodeHtmlEntities(post['title'] is Map?'${post['title']['rendered']??''}':'${post['title']??'Artikel'}'),style:RvazTypography.heading.copyWith(fontSize:22)),
    onTap:()=>openArticle(context,{...Map<String,dynamic>.from(post),'id':post['id']??post['post_id'],'needs_fetch':true}),
    trailing:IconButton(tooltip:'Verwijderen uit favorieten',onPressed:removing.contains('${post['id']??post['post_id']}')?null:()=>remove(post,items),icon:const Icon(Icons.bookmark_remove_outlined,color:navy)),
   ),
  ]));
 }));
}
