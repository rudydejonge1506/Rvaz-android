part of 'main.dart';

const familyKinds = <String,String>{
 'geboorte':'Geboorte', 'herinnering':'Overlijden & herdenkingen',
 'jubileum':'Jubilea & huwelijksjubilea', 'felicitatie':'Felicitaties & bijzondere gebeurtenissen',
};
const familyBackgrounds = <String,String>{
 'papier':'Krant / papier','bloesem':'Bloesem','duinen':'Duinen',
 'hemel':'Hemel','goud':'Goud','klassiek':'Klassiek wit',
};
const familyPlaces = ['Hellevoetsluis','Brielle','Rockanje','Oostvoorne','Oudenhoorn','Nieuwenhoorn','Tinte','Vierpolders','Zwartewaal','Overig'];
const familyApi = 'https://www.regiovoorneaanzee.nl/wp-json/rvaz-family/v1';

class FamilyApiException implements Exception {
 final String message;
 final bool loginRequired;
 const FamilyApiException(this.message,{this.loginRequired=false});
 @override String toString()=>message;
}
class FamilyService {
 static Map<String,dynamic> decode(http.Response r){
  Map<String,dynamic> data={};
  try {final x=jsonDecode(r.body);if(x is Map)data=Map<String,dynamic>.from(x);}catch(_){}
  if(r.statusCode<200||r.statusCode>=300)throw FamilyApiException(
   '${data['message']??'Familieberichten zijn tijdelijk niet beschikbaar. Probeer opnieuw.'}',loginRequired:r.statusCode==401);
  return data;
 }
 static Future<Map<String,dynamic>> list({bool mine=false,String kind='',int page=1}) async {
  final headers=mine?await authHeaders():<String,String>{'Accept':'application/json'};
  if(mine&&!headers.containsKey('Authorization'))throw const FamilyApiException('Log in met je RVAZ-account om je familieberichten te beheren.',loginRequired:true);
  final uri=Uri.parse('$familyApi/${mine?'mine':'notices'}').replace(queryParameters:{'page':'$page',if(kind.isNotEmpty)'kind':kind});
  return decode(await http.get(uri,headers:headers).timeout(const Duration(seconds:25)));
 }
 static Future<void> remove(int id) async {
  decode(await http.delete(Uri.parse('$familyApi/notices/$id'),headers:await authHeaders()).timeout(const Duration(seconds:25)));
 }
 static Future<void> submit(Map<String,String> fields,XFile? image) async {
  final headers=await authHeaders();
  if(!headers.containsKey('Authorization'))throw const FamilyApiException('Log opnieuw in via Account.',loginRequired:true);
  final request=http.MultipartRequest('POST',Uri.parse('$familyApi/notices'))..headers.addAll(headers)..fields.addAll(fields);
  if(image!=null)request.files.add(await http.MultipartFile.fromPath('image',image.path));
  decode(await http.Response.fromStream(await request.send().timeout(const Duration(seconds:60))));
 }
}

class FamilyNoticeCard extends StatelessWidget {
 final Map<String,dynamic> notice;
 final bool full;
 const FamilyNoticeCard({super.key,required this.notice,this.full=false});
 @override Widget build(BuildContext context){
  final bg='${notice['background']??'papier'}';
  const backgrounds=<String,List<Color>>{
   'papier':[Color(0xfff7f2e8),Color(0xffeee7d9)],
   'bloesem':[Color(0xfffff4f7),Color(0xfff4dfe8)],
   'duinen':[Color(0xfff9f2dd),Color(0xffe4ebdc)],
   'hemel':[Color(0xffeff8ff),Color(0xffd5e9f7)],
   'goud':[Color(0xfffff9e8),Color(0xffe9d8a9)],
   'klassiek':[Colors.white,Colors.white],
  };
  final centered=notice['align']!='left';
  final align=centered?TextAlign.center:TextAlign.left;
  final font=notice['font']=='sans'?'OpenSans':'serif';
  Widget? image;
  if(notice['local_image'] is XFile){image=Image.file(File((notice['local_image'] as XFile).path),fit:BoxFit.contain);}
  else if('${notice['image_base64']??''}'.isNotEmpty){
   try{image=Image.memory(base64Decode('${notice['image_base64']}'),fit:BoxFit.contain);}catch(_){}
  }else if('${notice['image_url']??''}'.isNotEmpty){
   image=Image.network('${notice['image_url']}',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('Afbeelding kon niet geladen worden.'));
  }
  final body='${notice['message']??''}';
  return Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(
   gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:backgrounds[bg]??backgrounds['papier']!),
   border:Border.all(color:const Color(0xffd5dfe6)),
  ),child:Column(crossAxisAlignment:centered?CrossAxisAlignment.center:CrossAxisAlignment.start,children:[
   Text(familyKinds[notice['kind']]??'Familiebericht',textAlign:align,style:const TextStyle(color:navy,fontSize:12,fontWeight:FontWeight.w600)),
   const SizedBox(height:16),
   if(image!=null)Padding(padding:const EdgeInsets.only(bottom:20),child:notice['layout']=='image'?image:ConstrainedBox(constraints:const BoxConstraints(maxHeight:240),child:image)),
   Text('${notice['title']??''}',textAlign:align,style:TextStyle(fontFamily:font,fontSize:26,height:1.3,color:navy,fontWeight:FontWeight.w600)),
   const SizedBox(height:14),
   Text(body,textAlign:align,maxLines:full?null:5,overflow:full?TextOverflow.visible:TextOverflow.ellipsis,style:TextStyle(fontFamily:font,fontSize:16,height:1.65,color:const Color(0xff273b4a))),
   const SizedBox(height:16),Text('${notice['place']??''}',textAlign:align,style:const TextStyle(fontSize:12,color:navy)),
  ]));
 }
}

class FamilyPage extends StatefulWidget {
 final bool mine;
 const FamilyPage({super.key,this.mine=false});
 @override State<FamilyPage> createState()=>_FamilyPageState();
}
class _FamilyPageState extends State<FamilyPage> {
 final List<Map<String,dynamic>> items=[];
 String kind='',error='';bool loading=false,more=true,needsLogin=false;
 int page=1,generation=0;
 @override void initState(){super.initState();load(reset:true);}
 Future<void> load({bool reset=false}) async {
  if(loading&&!reset)return;
  final run=++generation;
  if(reset){page=1;items.clear();more=true;}
  setState((){loading=true;error='';needsLogin=false;});
  try{
   final d=await FamilyService.list(mine:widget.mine,kind:kind,page:page);
   if(!mounted||run!=generation)return;
   final known=items.map((e)=>e['id']).toSet();
   setState((){items.addAll((d['items'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e)).where((e)=>known.add(e['id'])));more=d['has_more']==true;page++;});
  }catch(e){if(mounted&&run==generation)setState((){error=e is FamilyApiException?e.message:'Geen verbinding. Probeer opnieuw.';needsLogin=e is FamilyApiException&&e.loginRequired;});}
  finally{if(mounted&&run==generation)setState(()=>loading=false);}
 }
 Future<bool> login() async {
  if(await appLoggedIn())return true;
  if(!mounted)return false;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountPage()));
  return appLoggedIn();
 }
 Future<void> create()async{
  if(!await login()||!mounted)return;
  final sent=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const FamilyEditorPage()));
  if(sent==true&&mounted){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Je familiebericht is ontvangen en wacht op redactionele beoordeling.')));
   if(widget.mine)load(reset:true);
  }
 }
 Future<void> remove(Map<String,dynamic> n)async{
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Familiebericht verwijderen?'),content:const Text('Je bericht verdwijnt uit de app en van de website. De redactie kan het nog terugvinden in de prullenbak.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuleren')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Verwijderen'))]));
  if(yes!=true)return;
  try{await FamilyService.remove(n['id'] as int);if(mounted)setState(()=>items.removeWhere((e)=>e['id']==n['id']));}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is FamilyApiException?e.message:'Verwijderen is niet gelukt.')));}
 }
 String status(Map<String,dynamic> n)=>n['rejected']==true?'Afgekeurd':{'publish':'Gepubliceerd','pending':'Wacht op redactionele controle','draft':'Concept','private':'Privé'}[n['status']]??'In beoordeling';
 @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()=>load(reset:true),child:ListView(padding:const EdgeInsets.all(16),physics:const AlwaysScrollableScrollPhysics(),children:[
  NewsroomHeading(widget.mine?'Mijn familieberichten':'Familieberichten'),
  const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('De momenten die ertoe doen. Maak een persoonlijke kaart; de redactie controleert je bericht vóór publicatie.')),
  Wrap(spacing:8,runSpacing:8,children:[
   FilledButton.icon(onPressed:create,icon:const Icon(Icons.edit_outlined),label:const Text('Bericht maken')),
   if(!widget.mine)OutlinedButton.icon(onPressed:()async{if(!await login()||!mounted)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Mijn familieberichten')),body:const FamilyPage(mine:true))));},icon:const Icon(Icons.person_outline),label:const Text('Mijn berichten')),
  ]),
  if(!widget.mine)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Wrap(spacing:8,runSpacing:6,children:{'':'Alle berichten',...familyKinds}.entries.map((e)=>ChoiceChip(label:Text(e.value),selected:kind==e.key,onSelected:(_){kind=e.key;load(reset:true);})).toList())),
  if(error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:20),child:Column(children:[Text(error),TextButton(onPressed:needsLogin?()async{if(await login()&&mounted)load(reset:true);}:()=>load(reset:items.isEmpty),child:Text(needsLogin?'Inloggen / account maken':'Opnieuw proberen'))])),
  if(!loading&&error.isEmpty&&items.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:24),child:Text(widget.mine?'Je hebt nog geen familieberichten aangemeld.':'Er zijn nog geen gepubliceerde familieberichten in deze categorie.')),
  for(final n in items)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Familiebericht')),body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:FamilyNoticeCard(notice:n,full:true))))),child:FamilyNoticeCard(notice:n)),
   if(widget.mine)Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,children:[Text(status(n)),TextButton.icon(onPressed:()=>remove(n),icon:const Icon(Icons.delete_outline),label:const Text('Verwijderen'))]),
   if(!widget.mine)TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Familiebericht')),body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:FamilyNoticeCard(notice:n,full:true))))),child:const Text('Lees familiebericht →')),
  ])),
  if(loading)const Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator())),
  if(!loading&&more&&items.isNotEmpty&&error.isEmpty)OutlinedButton(onPressed:()=>load(),child:const Text('Meer laden')),
 ]));
}

class FamilyEditorPage extends StatefulWidget {
 const FamilyEditorPage({super.key});
 @override State<FamilyEditorPage> createState()=>_FamilyEditorPageState();
}
class _FamilyEditorPageState extends State<FamilyEditorPage> {
 final form=GlobalKey<FormState>();
 final title=TextEditingController(),message=TextEditingController();
 String kind='herinnering',background='papier',font='serif',align='center',layout='card',place='Hellevoetsluis';
 late final String requestId='family-${DateTime.now().microsecondsSinceEpoch}';
 XFile? image;bool permission=false,busy=false;String error='';
 @override void dispose(){title.dispose();message.dispose();super.dispose();}
 Map<String,dynamic> get preview=>{'title':title.text.isEmpty?'Jouw titel':title.text,'message':message.text.isEmpty?'Jouw persoonlijke bericht':message.text,'kind':kind,'background':background,'font':font,'align':align,'layout':layout,'place':place,'local_image':image};
 Widget choice(String label,String value,Map<String,String> options,ValueChanged<String> change)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:DropdownButtonFormField<String>(initialValue:value,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),items:options.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),onChanged:busy?null:(v){if(v!=null)setState(()=>change(v));}));
 Future<void> pick()async{
  try{final x=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1600,maxHeight:1600,imageQuality:85);if(x==null)return;if(await x.length()>5*1024*1024){if(mounted)setState(()=>error='Kies een afbeelding van maximaal 5 MB.');return;}if(mounted)setState((){image=x;error='';});}
  catch(_){if(mounted)setState(()=>error='Afbeelding kon niet geopend worden. Controleer je fototoegang.');}
 }
 Future<void> send()async{
  if(busy||!form.currentState!.validate())return;
  if(!permission){setState(()=>error='Bevestig je toestemming voor publicatie.');return;}
  if(layout=='image'&&image==null){setState(()=>error='Voeg je zelfgemaakte kaart toe.');return;}
  setState((){busy=true;error='';});
  try{await FamilyService.submit({'title':title.text.trim(),'message':message.text.trim(),'kind':kind,'background':background,'font':font,'align':align,'layout':layout,'place':place,'permission':'1','request_id':requestId},image);if(mounted)Navigator.pop(context,true);}
  catch(e){if(mounted)setState(()=>error=e is FamilyApiException?e.message:'Geen bevestiging ontvangen. Probeer opnieuw; je inzending wordt niet dubbel geplaatst.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Maak je familiebericht')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Je maakt je kaart rechtstreeks in de app. Je bericht wordt pas zichtbaar na goedkeuring door de redactie.'),const SizedBox(height:16),
  choice('Soort bericht',kind,familyKinds,(v)=>kind=v),
  choice('Achtergrond',background,familyBackgrounds,(v)=>background=v),
  choice('Lettertype',font,{'serif':'Klassieke krant','sans':'Helder en modern'},(v)=>font=v),
  choice('Uitlijning',align,{'center':'Gecentreerd','left':'Links'},(v)=>align=v),
  choice('Afbeelding gebruiken als',layout,{'card':'Foto in mijn kaart','image':'Volledige zelfgemaakte kaart'},(v)=>layout=v),
  TextFormField(controller:title,enabled:!busy,maxLength:120,decoration:const InputDecoration(labelText:'Titel',border:OutlineInputBorder()),validator:(v)=>(v??'').trim().isEmpty?'Vul een titel in.':null,onChanged:(_)=>setState((){})),const SizedBox(height:12),
  TextFormField(controller:message,enabled:!busy,maxLength:3000,minLines:5,maxLines:12,decoration:const InputDecoration(labelText:'Berichttekst',border:OutlineInputBorder()),validator:(v)=>(v??'').trim().isEmpty?'Vul je berichttekst in.':null,onChanged:(_)=>setState((){})),
  choice('Plaats',place,{for(final p in familyPlaces)p:p},(v)=>place=v),
  OutlinedButton.icon(onPressed:busy?null:pick,icon:const Icon(Icons.add_photo_alternate_outlined),label:Text(image==null?'Foto of kaart kiezen':'Andere afbeelding kiezen')),
  if(image!=null)TextButton(onPressed:busy?null:()=>setState(()=>image=null),child:const Text('Afbeelding verwijderen')),
  const SizedBox(height:24),const NewsroomHeading('Voorbeeld van je kaart'),const SizedBox(height:16),FamilyNoticeCard(notice:preview,full:true),const SizedBox(height:16),
  CheckboxListTile(contentPadding:EdgeInsets.zero,value:permission,onChanged:busy?null:(v)=>setState(()=>permission=v??false),title:const Text('Ik heb toestemming om deze tekst en afbeelding openbaar te laten publiceren.')),
  const Text('De redactie kan contact opnemen via het e-mailadres van je account. Dat adres verschijnt niet bij je bericht.'),
  if(error.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(error,style:const TextStyle(color:Colors.red))),
  const SizedBox(height:16),FilledButton.icon(onPressed:busy?null:send,icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send_outlined),label:Text(busy?'Versturen…':'Versturen ter beoordeling')),const SizedBox(height:32),
 ])));
}
