import 'package:flutter/material.dart';

const wonenNavy = Color(0xFF073B63);
const wonenBlue = Color(0xFF0878F9);
const wonenBg = Color(0xFFF4F7FA);

class WonenPage extends StatelessWidget {
  const WonenPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: wonenBg,
    appBar: AppBar(backgroundColor: Colors.white, foregroundColor: wonenNavy, title: const Text('Wonen op Voorne', style: TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Wonen op Voorne', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: wonenNavy)),
      const Text('Koop, huur, nieuwbouw en bedrijfspanden'),
      const SizedBox(height: 14),
      TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Plaats, straat of postcode...', suffixIcon: const Icon(Icons.tune), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      const SizedBox(height: 10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['Alle','Koop','Huur','Nieuwbouw','Bedrijfspanden'].map((label) => Padding(padding: const EdgeInsets.only(right: 7), child: Chip(label: Text(label)))).toList())),
      const SizedBox(height: 12),
      const Card(child: Padding(padding: EdgeInsets.all(22), child: Column(children: [Icon(Icons.home_work_outlined, size: 48, color: wonenNavy), SizedBox(height: 8), Text('Woningaanbod op Voorne', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: wonenNavy)), Text('Nieuw woningaanbod verschijnt hier automatisch vanuit RVAZ Wonen.')])))
    ]),
  );
}

class MakelaarsPortalPage extends StatelessWidget {
  const MakelaarsPortalPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: wonenBg,
    appBar: AppBar(backgroundColor: Colors.white, foregroundColor: wonenNavy, title: const Text('Mijn Wonen', style: TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Mijn Wonen', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: wonenNavy)), Text('Makelaarsportaal Voorne')])), FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NieuweWoningPage())), icon: const Icon(Icons.add), label: const Text('Nieuwe woning'))]),
      const SizedBox(height: 14),
      const Row(children: [_Stat('Actief','0',Icons.home), _Stat('Verkocht','0',Icons.home_work), _Stat('Concept','0',Icons.description_outlined)]),
      const SizedBox(height: 14),
      for (final item in const [('Mijn woningen',Icons.home_outlined),('Nieuwe woning',Icons.add_home_outlined),('Mijn kantoor',Icons.business_outlined),('Statistieken',Icons.bar_chart),('Abonnement',Icons.card_membership),('Facturen',Icons.receipt_long)])
        Card(child: ListTile(leading: Icon(item.$2, color: wonenNavy), title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => portalPage(item.$1)))))
    ]),
  );
  static Widget portalPage(String title) { switch(title) { case 'Nieuwe woning': return const NieuweWoningPage(); case 'Mijn woningen': return const MijnWoningenPage(); case 'Mijn kantoor': return const WonenOfficePage(); case 'Statistieken': return const WonenStatsPage(); case 'Abonnement': return const WonenSubscriptionPage(); case 'Facturen': return const WonenInvoicesPage(); default: return WonenSectionPage(title:title); } }
}

class _Stat extends StatelessWidget {
  final String label, value; final IconData icon;
  const _Stat(this.label,this.value,this.icon);
  @override Widget build(BuildContext context) => Expanded(child: Card(margin: const EdgeInsets.all(3), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(icon,color:wonenBlue), Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)), Text(label,style:const TextStyle(fontSize:11))]))));
}

class NieuweWoningPage extends StatelessWidget {
  const NieuweWoningPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Nieuwe woning')),body:ListView(padding:const EdgeInsets.all(16),children:[
    const WonenSteps(active:1), const SizedBox(height:18), const Text('Basisgegevens',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)), const SizedBox(height:12),
    for(final label in ['Adres *','Postcode *','Plaats *','Woningtype *','Koop of huur *','Status *','Prijs *','Bouwjaar','Woonoppervlak (m²)','Perceeloppervlak (m²)','Aantal slaapkamers']) Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(decoration:InputDecoration(labelText:label,filled:true,fillColor:Colors.white,border:const OutlineInputBorder()))),
    Align(alignment:Alignment.centerRight,child:FilledButton(onPressed:(){},child:const Text('Volgende →')))
  ]));
}

class WonenSteps extends StatelessWidget {
  final int active; const WonenSteps({super.key,required this.active});
  @override Widget build(BuildContext context) => Row(children:List.generate(5,(i)=>Expanded(child:Column(children:[CircleAvatar(radius:13,backgroundColor:i+1<=active?wonenBlue:Colors.white,child:Text('${i+1}',style:TextStyle(fontSize:11,color:i+1<=active?Colors.white:wonenNavy))),Text(const ['Basisgegevens','Kenmerken','Foto’s','Omschrijving','Publiceren'][i],style:const TextStyle(fontSize:8))]))));
}

class WonenSectionPage extends StatelessWidget {
  final String title; const WonenSectionPage({super.key,required this.title});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:Text(title)),body:Center(child:Text(title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy))));
}


class MijnWoningenPage extends StatelessWidget {
  const MijnWoningenPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Mijn woningen')),body:ListView(padding:const EdgeInsets.all(16),children:[
    Row(children:[const Expanded(child:Text('Mijn woningen',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy))),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NieuweWoningPage())),icon:const Icon(Icons.add),label:const Text('Nieuwe woning'))]),
    const SizedBox(height:12),const Card(child:ListTile(leading:Icon(Icons.home_outlined,color:wonenNavy),title:Text('Nog geen woningen',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('Nieuwe woningen verschijnen hier met foto, adres, prijs en status.')))
  ]));
}
class WonenOfficePage extends StatelessWidget {
  const WonenOfficePage({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Mijn kantoor')),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Kantoorgegevens',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy)),const SizedBox(height:12),
    for(final label in ['Kantoornaam','KvK nummer','Adres','Postcode','Plaats','Telefoon','Website'])Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(decoration:InputDecoration(labelText:label,filled:true,fillColor:Colors.white,border:const OutlineInputBorder()))),
    const Card(child:ListTile(leading:Icon(Icons.image_outlined,color:wonenNavy),title:Text('Kantoorlogo',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('Logo wijzigen of verwijderen')))
  ]));
}
class WonenStatsPage extends StatelessWidget {
  const WonenStatsPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Statistieken')),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Statistieken',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy)),const SizedBox(height:12),const Row(children:[_Stat('Actief','0',Icons.home),_Stat('Verkocht','0',Icons.check_circle_outline),_Stat('Weergaven','0',Icons.visibility_outlined)]),const SizedBox(height:12),const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Weergaven en prestaties per woning.')))
  ]));
}


class WonenSubscriptionPage extends StatelessWidget {
 const WonenSubscriptionPage({super.key});
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Abonnement')),body:ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Kies een abonnement',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy)),const SizedBox(height:12),
  _PlanCard(name:'Basis',price:'49',limit:'Tot 5 woningen'),_PlanCard(name:'Plus',price:'99',limit:'Tot 20 woningen'),_PlanCard(name:'Pro',price:'179',limit:'Onbeperkt woningen')
 ]));
}
class _PlanCard extends StatelessWidget {
 final String name,price,limit; const _PlanCard({required this.name,required this.price,required this.limit});
 @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(name,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:wonenNavy)),Text('€ $price per maand',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('✓ $limit\n✓ Vermelding op website en app\n✓ Eigen makelaarspagina\n✓ Statistieken'),const SizedBox(height:12),OutlinedButton(onPressed:null,child:Text('Kies $name'))
 ])));
}
class WonenInvoicesPage extends StatelessWidget {
 const WonenInvoicesPage({super.key});
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Facturen')),body:ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Facturen',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy)),const SizedBox(height:12),
  Card(child:ListTile(leading:const Icon(Icons.receipt_long,color:wonenNavy),title:const Text('Factuur 2026-0017',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:const Text('Plus · Openstaand'),trailing:const Text('€ 119,79',style:TextStyle(fontWeight:FontWeight.w900)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WonenInvoiceDetailPage()))))
 ]));
}
class WonenInvoiceDetailPage extends StatelessWidget {
 const WonenInvoiceDetailPage({super.key});
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:wonenBg,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:wonenNavy,title:const Text('Factuur 2026-0017')),body:ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Factuur 2026-0017',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:wonenNavy)),const SizedBox(height:8),const Chip(label:Text('Openstaand')),const SizedBox(height:10),
  const Card(child:Padding(padding:EdgeInsets.all(16),child:Column(children:[_InvoiceLine('Abonnement Plus','€ 99,00'),_InvoiceLine('BTW 21%','€ 20,79'),Divider(),_InvoiceLine('Totaal','€ 119,79',bold:true)]))),
  const SizedBox(height:12),const Row(children:[Expanded(child:FilledButton(onPressed:null,child:Text('Betaal via Tikkie'))),SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:null,child:Text('Download PDF')))])
 ]));
}
class _InvoiceLine extends StatelessWidget {
 final String left,right; final bool bold; const _InvoiceLine(this.left,this.right,{this.bold=false});
 @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Expanded(child:Text(left,style:TextStyle(fontWeight:bold?FontWeight.w900:null))),Text(right,style:TextStyle(fontWeight:bold?FontWeight.w900:null))]));
}
