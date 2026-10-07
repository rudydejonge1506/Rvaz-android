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
        Card(child: ListTile(leading: Icon(item.$2, color: wonenNavy), title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.$1 == 'Nieuwe woning' ? const NieuweWoningPage() : WonenSectionPage(title: item.$1)))))
    ]),
  );
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
