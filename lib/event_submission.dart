import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show site, authHeaders, AccountPage, decodeHtmlEntities;

class EventSubmissionPage extends StatefulWidget {
 const EventSubmissionPage({super.key});
 @override State<EventSubmissionPage> createState()=>_EventSubmissionPageState();
}
class _EventSubmissionPageState extends State<EventSubmissionPage>{
 final form=GlobalKey<FormState>();
 final fields={for(final k in ['title','description','start_date','end_date','start_time','end_time','location','address','price','url','repeat_until'])k:TextEditingController()};
 final requestId=DateTime.now().microsecondsSinceEpoch.toString();
 List<dynamic> categories=[]; int? category; String repeat='none',error='';
 XFile? photo;
 bool rights=false;
 bool loading=true,logged=false,sending=false,submitted=false;
 @override void initState(){super.initState();load();}
 @override void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
 Future<void> load()async{
  setState(()=>loading=true);
  try{
   final me=await http.get(Uri.parse('$site/wp-json/rvaz-app/v1/me'),headers:await authHeaders()).timeout(const Duration(seconds:20));
   final cats=await http.get(Uri.parse('$site/wp-json/wp/v2/rvaz_event_category?per_page=100&hide_empty=false')).timeout(const Duration(seconds:20));
   if(cats.statusCode!=200)throw Exception();
   if(mounted)setState((){logged=me.statusCode==200;categories=jsonDecode(cats.body) as List;error='';});
  }catch(_){if(mounted)setState(()=>error='Gegevens laden lukt niet. Probeer opnieuw.');}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> pickDate(String key)async{
  final now=DateTime.now();
  final value=await showDatePicker(context:context,initialDate:DateTime.tryParse(fields[key]!.text)??now,firstDate:DateTime(now.year-1),lastDate:DateTime(now.year+5));
  if(value!=null&&mounted)setState(()=>fields[key]!.text=value.toIso8601String().substring(0,10));
 }
 Future<void> pickTime(String key)async{
  final value=await showTimePicker(context:context,initialTime:TimeOfDay.now());
  if(value!=null&&mounted)setState(()=>fields[key]!.text=value.hour.toString().padLeft(2,'0')+':'+value.minute.toString().padLeft(2,'0'));
 }
 Future<void> submit()async{
  if(sending||submitted||!form.currentState!.validate())return;
  setState((){sending=true;error='';});
  try{
   if(photo!=null&&!rights){setState(()=>error='Bevestig dat je de afbeelding mag gebruiken.');return;}
   final req=http.MultipartRequest('POST',Uri.parse('$site/wp-json/rvaz-native-events/v1/submit'));
   req.headers.addAll(await authHeaders());
   req.fields.addAll({for(final e in fields.entries)e.key:e.value.text.trim(),'category':'$category','repeat':repeat,'request_id':requestId});
   if(photo!=null)req.files.add(await http.MultipartFile.fromPath('event_image',photo!.path));
   final res=await http.Response.fromStream(await req.send()).timeout(const Duration(seconds:60));
   if(!mounted)return;
   dynamic body;try{body=jsonDecode(res.body);}catch(_){}
   if(res.statusCode>=200&&res.statusCode<300&&body is Map&&body['id']!=null){setState(()=>submitted=true);}
   else{setState(()=>error=res.statusCode==404?'Aanmelden is nog niet beschikbaar. Probeer het later opnieuw.':res.statusCode==401?'Log opnieuw in via Account.':body is Map?(body['message']??'Indienen mislukt.').toString():'Indienen mislukt.');}
  }catch(_){if(mounted)setState(()=>error='Geen bevestiging ontvangen. Probeer opnieuw; dezelfde aanvraag wordt niet dubbel opgeslagen.');}
  finally{if(mounted)setState(()=>sending=false);}
 }
 Widget input(String key,String label,{bool required=false,int lines=1,bool date=false,bool time=false})=>Padding(
  padding:const EdgeInsets.only(bottom:16),child:TextFormField(
   controller:fields[key],enabled:!sending,readOnly:date||time,minLines:lines,maxLines:lines,
   decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
   onTap:date||time?()=>date?pickDate(key):pickTime(key):null,
   validator:(v)=>required&&(v??'').trim().isEmpty?'Dit veld is verplicht.':null));
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Evenement aanmelden')),
  body:loading?const Center(child:CircularProgressIndicator()):submitted?
   const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Evenement ontvangen. Na goedkeuring door de redactie verschijnt het in de agenda.'))):
   !logged?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('Log in met je RVAZ-account om een evenement aan te melden.'),
    if(error.isNotEmpty)Text(error),
    FilledButton(onPressed:()async{
     await Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Account')),body:const AccountPage())));
     if(mounted)await load();
    },child:const Text('Inloggen of registreren')),TextButton(onPressed:load,child:const Text('Opnieuw laden'))]))):
   Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[
    const Padding(padding:EdgeInsets.only(bottom:16),child:Text('Vul de gegevens in. Je evenement verschijnt na goedkeuring door de redactie.')),
    input('title','Titel *',required:true),input('description','Beschrijving *',required:true,lines:5),
    DropdownButtonFormField<int>(initialValue:category,isExpanded:true,decoration:const InputDecoration(labelText:'Categorie *'),
      items:categories.map((c)=>DropdownMenuItem<int>(value:c['id'] as int,child:Text(decodeHtmlEntities(c['name'].toString())))).toList(),
      onChanged:sending?null:(v)=>setState(()=>category=v),validator:(v)=>v==null?'Kies een categorie.':null),
    const SizedBox(height:16),input('start_date','Startdatum *',required:true,date:true),input('start_time','Starttijd',time:true),
    input('end_date','Einddatum',date:true),input('end_time','Eindtijd',time:true),
    input('location','Locatie / accommodatie'),input('address','Adres'),input('price','Entree / kosten'),input('url','Website (https://...)'),
    DropdownButtonFormField<String>(initialValue:repeat,decoration:const InputDecoration(labelText:'Herhaling'),
      items:const [DropdownMenuItem(value:'none',child:Text('Niet herhalen')),DropdownMenuItem(value:'weekly',child:Text('Wekelijks')),DropdownMenuItem(value:'biweekly',child:Text('Elke twee weken')),DropdownMenuItem(value:'monthly',child:Text('Maandelijks'))],
      onChanged:sending?null:(v)=>setState(()=>repeat=v??'none')),
    const SizedBox(height:16),if(repeat!='none')input('repeat_until','Herhalen tot *',required:true,date:true),
    OutlinedButton.icon(icon:const Icon(Icons.photo_outlined),label:Text(photo==null?'Afbeelding kiezen':'Afbeelding wijzigen'),
     onPressed:sending?null:()async{try{final p=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:2000,imageQuality:85);if(p!=null&&mounted)setState(()=>photo=p);}catch(_){if(mounted)setState(()=>error='Afbeelding kiezen is niet gelukt.');}}),
    if(photo!=null)...[Text(photo!.name),TextButton(onPressed:sending?null:()=>setState(()=>photo=null),child:const Text('Afbeelding verwijderen')),
     CheckboxListTile(value:rights,onChanged:sending?null:(v)=>setState(()=>rights=v??false),title:const Text('Ik mag deze afbeelding gebruiken.'))],
    if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.red)),
    FilledButton(onPressed:sending?null:submit,child:Text(sending?'Bezig met indienen…':'Ter goedkeuring indienen')),
   ])));
}
