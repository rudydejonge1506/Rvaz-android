part of 'main.dart';

typedef AccountMenuEntry=(String,String,IconData);
const accountMenuGroups=<String,List<AccountMenuEntry>>{
 'Nieuws & plaatsen':[
  ('news','Laatste nieuws',Icons.newspaper_outlined),('places','Nieuws per plaats',Icons.location_on_outlined),
  ('family','Familieberichten',Icons.favorite_border),('emergency','112 & P2000',Icons.emergency_outlined),
 ],
 'Mijn Voorne & dagelijks leven':[
  ('myvoorne','Mijn Voorne',Icons.today_outlined),('waste','Afvalkalender',Icons.recycling),
  ('address','Mijn adres',Icons.home_outlined),('traffic','Verkeer',Icons.traffic_outlined),('parking','Parkeren',Icons.local_parking),
 ],
 'Agenda & vrije tijd':[
  ('agenda','Agenda',Icons.event_outlined),('submit-event','Evenement aanmelden',Icons.add_circle_outline),
  ('recreation','Natuur & recreatie',Icons.park_outlined),
 ],
 'Strand & weer':[
  ('coast','Strandweer & kust',Icons.waves),
 ],
 'Wonen, bedrijven & voordeel':[
  ('wonen','Wonen',Icons.real_estate_agent_outlined),('businesses','Bedrijven',Icons.storefront_outlined),
  ('vouchers','Vouchers & aanbiedingen',Icons.local_offer_outlined),
 ],
 'Mijn account':[
  ('profile','Mijn profiel',Icons.person_outline),('saved','Mijn favorieten',Icons.bookmark_outline),
  ('my-vouchers','Mijn vouchers',Icons.confirmation_number_outlined),('my-family','Mijn familieberichten',Icons.favorite_outline),
  ('notifications','Meldingen & P2000',Icons.notifications_outlined),('contributions','Mijn bijdragen',Icons.edit_note),
 ],
 'Zakelijk beheer':[
  ('my-business','Mijn bedrijf',Icons.storefront_outlined),('scan','Voucher scannen',Icons.qr_code_scanner),
  ('my-wonen','Mijn Wonen',Icons.apartment),('my-ads','Mijn advertenties',Icons.campaign_outlined),('invoices','Facturen',Icons.receipt_long_outlined),
 ],
 'Contact & hulp':[
  ('tip','Tip de redactie',Icons.campaign_outlined),('feedback','Foutje melden / feedback',Icons.bug_report_outlined),
  ('contact','Contact',Icons.mail_outline),('review','Beoordeel de app',Icons.star_outline),
 ],
};

String accountMenuLabel(String key){
 for(final group in accountMenuGroups.values){for(final item in group){if(item.$1==key)return item.$2;}}
 return 'RVAZ';
}

class AccountMenuSections extends StatefulWidget{
 final ValueChanged<String> onSelected;
 final bool showVoucherScanner, showBusinessManagement, showHousingManagement;
 const AccountMenuSections({super.key,required this.onSelected,this.showVoucherScanner=false,this.showBusinessManagement=false,this.showHousingManagement=false});
 @override State<AccountMenuSections> createState()=>_AccountMenuSectionsState();
}
class _AccountMenuSectionsState extends State<AccountMenuSections>{
 String query='';
 @override Widget build(BuildContext context){
  final groups=<String,List<AccountMenuEntry>>{};
  for(final group in accountMenuGroups.entries){
   final entries=group.value.where((e)=>(e.$1 != 'scan' || widget.showVoucherScanner) && (e.$1 != 'my-business' || widget.showBusinessManagement) && (e.$1 != 'my-wonen' || widget.showHousingManagement) && '${group.key} ${e.$2}'.toLowerCase().contains(query)).toList();
   if(entries.isNotEmpty)groups[group.key]=entries;
  }
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   TextField(onChanged:(value)=>setState(()=>query=value.trim().toLowerCase()),decoration:const InputDecoration(labelText:'Zoek een onderdeel',hintText:'Bijvoorbeeld afval, strand of vouchers',prefixIcon:Icon(Icons.search))),
   const SizedBox(height:20),
   if(groups.isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('Geen onderdeel gevonden. Probeer een andere zoekterm.')),
   for(final group in groups.entries)Padding(padding:const EdgeInsets.only(bottom:12),child:Material(color:newsroomPale,child:ExpansionTile(
    key:ValueKey('${group.key}|$query'),initiallyExpanded:query.isNotEmpty,
    tilePadding:const EdgeInsets.symmetric(horizontal:16,vertical:6),childrenPadding:EdgeInsets.zero,
    iconColor:navy,collapsedIconColor:navy,shape:const Border(),collapsedShape:const Border(),
    title:Text(group.key,style:RvazTypography.heading.copyWith(fontSize:22)),
    children:[for(final item in group.value)Material(color:Colors.white,child:Container(decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Color(0xffd9e5ed)))) ,child:ListTile(
     contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:8),leading:Icon(item.$3,color:cyan),
     title:Text(item.$2,style:RvazTypography.heading.copyWith(fontSize:21)),trailing:const Icon(Icons.chevron_right,color:navy),onTap:()=>widget.onSelected(item.$1),
    )))],
   ))),
  ]);
 }
}
