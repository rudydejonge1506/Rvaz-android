part of 'main.dart';

const agendaMonths=['','januari','februari','maart','april','mei','juni','juli','augustus','september','oktober','november','december'];
String agendaValue(dynamic event,List<String> keys){
 if(event is! Map)return '';
 for(final key in keys){final value=event[key];if(value is String&&value.trim().isNotEmpty)return decodeHtmlEntities(value.trim());}
 return '';
}
String agendaTitle(dynamic event){
 final title=event is Map?event['title']:null;
 return decodeHtmlEntities(title is Map?'${title['rendered']??''}':'${title??''}').replaceAll(RegExp(r'<[^>]*>'),'');
}
DateTime? agendaStart(dynamic event){
 final raw=agendaValue(event,['start_date','event_start_date','event_date','start','date','datum','datetime']);
 final parsed=DateTime.tryParse(raw)?.toLocal();
 if(parsed==null)return null;
 final clock=agendaValue(event,['start_time','time']);final match=RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clock);
 if(raw.length<=10&&match!=null){final h=int.parse(match[1]!),m=int.parse(match[2]!);if(h<24&&m<60)return DateTime(parsed.year,parsed.month,parsed.day,h,m);}
 return parsed;
}
List<dynamic> agendaUpcoming(List<dynamic> records,{DateTime? now,String place='Alle'}){
 final clock=now??DateTime.now(),seen=<String>{};final today=DateTime(clock.year,clock.month,clock.day);
 final result=records.where((event){
  if(event is! Map)return false;
  final location=agendaValue(event,['place','city','town','plaats','event_place']);
  if(place!='Alle'&&location.toLowerCase()!=place.toLowerCase())return false;
  final start=agendaStart(event),end=DateTime.tryParse(agendaValue(event,['end_date','event_end_date']))?.toLocal();
  final last=end??start;
  if(last!=null&&DateTime(last.year,last.month,last.day).isBefore(today))return false;
  // A recurring event has a separate row for every occurrence; do not dedupe by ID alone.
  return seen.add('${event['id']}|$start|${agendaTitle(event)}|$location');
 }).toList();
 result.sort((a,b)=>(agendaStart(a)??DateTime(2100)).compareTo(agendaStart(b)??DateTime(2100)));
 return result;
}

class AgendaEventTile extends StatelessWidget {
 final dynamic event;
 const AgendaEventTile({super.key,required this.event});
 @override Widget build(BuildContext context){
  final date=agendaStart(event),image=agendaValue(event,['image','image_url','thumbnail']);
  final place=agendaValue(event,['place','city','town','plaats','event_place']);
  final venue=agendaValue(event,['venue','location']);
  final time=agendaValue(event,['start_time','time']);
  final price=agendaValue(event,['price','kosten']);
  return DecoratedBox(decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:newsroomLine))),child:InkWell(
   onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDetailPage(event:event))),
   child:Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    SizedBox(width:54,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(date==null?'—':'${date.day}',style:RvazTypography.heading.copyWith(fontSize:32,color:cyan,height:1.1)),
     if(date!=null)Text(agendaMonths[date.month].substring(0,3),style:const TextStyle(fontFamily:'OpenSans',fontSize:12,color:cyan)),
     if(time.isNotEmpty)Padding(padding:const EdgeInsets.only(top:7),child:Text(time,style:const TextStyle(fontFamily:'OpenSans',fontSize:12,color:cyan))),
    ])),const SizedBox(width:14),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(agendaTitle(event),style:RvazTypography.heading.copyWith(fontSize:22,height:1.3)),const SizedBox(height:6),
     if(venue.isNotEmpty||place.isNotEmpty)Text([venue,if(place.isNotEmpty&&place!=venue)place].where((x)=>x.isNotEmpty).join(' · '),style:const TextStyle(fontFamily:'OpenSans',fontSize:14,height:1.5,color:Color(0xff526575))),
     if(price.isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Text(price,style:const TextStyle(fontFamily:'OpenSans',fontSize:13,color:navy))),
    ])),
    if(image.isNotEmpty)Padding(padding:const EdgeInsets.only(left:12),child:Image.network(image,width:72,height:64,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
   ])),
  ));
 }
}

class AgendaPage extends StatefulWidget {
 final Future<List<dynamic>> Function()? loader;
 final bool showPromotions;
 const AgendaPage({super.key,this.loader,this.showPromotions=true});
 @override State<AgendaPage> createState()=>_AgendaPageState();
}
class _AgendaPageState extends State<AgendaPage> {
 late Future<List<dynamic>> future;
 late final Future<List<AppAd>> ads=widget.showPromotions?loadAppAds(placement:'agenda'):Future.value([]);
 String place='Alle';
 @override void initState(){super.initState();future=(widget.loader??load)();}
 Future<void> refresh()async{setState(()=>future=(widget.loader??load)());await future;}
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
 @override Widget build(BuildContext context)=>ColoredBox(color:Colors.white,child:FutureBuilder<List<dynamic>>(future:future,builder:(context,snapshot){
  if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
  if(snapshot.hasError)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('De agenda kon niet worden geladen.'),TextButton(onPressed:refresh,child:const Text('Opnieuw proberen'))]));
  final all=snapshot.data??[],items=agendaUpcoming(all,place:place);
  final places=<String>{'Alle',...PlacesPage.regionPlaces,...all.map((e)=>agendaValue(e,['place','city','town','plaats','event_place'])).where((p)=>p.isNotEmpty)}.toList();
  String month='';
  return RefreshIndicator(onRefresh:refresh,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,12,16,28),children:[
   const NewsroomHeading('Agenda'),const SizedBox(height:16),
   Wrap(spacing:12,runSpacing:12,alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,children:[
    Text('${items.length} aankomende evenementen',style:const TextStyle(fontFamily:'OpenSans',fontSize:14,color:navy)),
    FilledButton.icon(onPressed:()=>openEventSubmission(context),icon:const Icon(Icons.add),label:const Text('Evenement aanmelden')),
   ]),const SizedBox(height:20),
   DropdownButtonFormField<String>(initialValue:place,isExpanded:true,decoration:const InputDecoration(labelText:'Plaats',border:OutlineInputBorder()),items:places.map((p)=>DropdownMenuItem(value:p,child:Text(p=='Alle'?'Alle plaatsen':p))).toList(),onChanged:(value){if(value!=null)setState(()=>place=value);}),
   const SizedBox(height:16),
   if(widget.showPromotions)RotatingAppAd(future:ads),
   if(items.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:28),child:Text('Geen aankomende evenementen gevonden voor deze selectie.')),
   for(final event in items)...[
    ...(){
     final date=agendaStart(event),label=date==null?'Datum volgt':'${agendaMonths[date.month]} ${date.year}';
     if(month==label)return <Widget>[];month=label;
     return <Widget>[Padding(padding:const EdgeInsets.only(top:20,bottom:2),child:NewsroomHeading(label))];
    }(),
    AgendaEventTile(event:event),
   ],
  ]));
 }));
}
