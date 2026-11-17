import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// Keep existing neighbourhood preferences when upgrading from the old calendar.
Future<String> neighborhoodAddressValue(String field) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key:'rvaz_address_$field') ??
    await storage.read(key:'rvaz_waste_$field') ?? '';
}

class NeighborhoodAddressPage extends StatefulWidget {
  const NeighborhoodAddressPage({super.key});
  @override State<NeighborhoodAddressPage> createState() => _NeighborhoodAddressPageState();
}
class _NeighborhoodAddressPageState extends State<NeighborhoodAddressPage> {
  final postcode=TextEditingController(), house=TextEditingController(), addition=TextEditingController();
  bool busy=false;
  String error='';
  @override void initState() { super.initState(); restore(); }
  Future<void> restore() async {
    final values=await Future.wait(['postcode','house','addition'].map(neighborhoodAddressValue));
    if (!mounted) return;
    postcode.text=values[0]; house.text=values[1]; addition.text=values[2];
  }
  @override void dispose() { postcode.dispose(); house.dispose(); addition.dispose(); super.dispose(); }
  Future<void> save() async {
    final pc=postcode.text.replaceAll(' ','').toUpperCase(), nr=house.text.trim(), extra=addition.text.trim().toUpperCase();
    if (!RegExp(r'^[1-9][0-9]{3}[A-Z]{2}$').hasMatch(pc) || !RegExp(r'^[1-9][0-9]*$').hasMatch(nr)) {
      setState(() => error='Vul een geldige postcode en huisnummer in.'); return;
    }
    setState(() {busy=true; error='';});
    try {
      final uri=Uri.https('api.pdok.nl','/bzk/locatieserver/search/v3_1/free',{
        'q':'$pc $nr $extra','fq':['type:adres','postcode:$pc','huisnummer:$nr'],'rows':'100',
      });
      final response=await http.get(uri).timeout(const Duration(seconds:12));
      if (response.statusCode!=200) throw Exception();
      final data=jsonDecode(response.body);
      final docs=data['response']['docs'] as List;
      String normalized(String value) => value.replaceAll(RegExp('[^A-Z0-9]'),'');
      final matches=docs.where((d) => normalized('${d['huisletter']??''}${d['huisnummertoevoeging']??''}'.toUpperCase())==normalized(extra)).toList();
      if(matches.length!=1) { if(mounted)setState(() => error='Adres niet gevonden. Controleer ook de toevoeging.'); return; }
      final address=matches.single;
      const storage=FlutterSecureStorage();
      await storage.write(key:'rvaz_address_postcode',value:pc);
      await storage.write(key:'rvaz_address_house',value:nr);
      await storage.write(key:'rvaz_address_addition',value:extra);
      await storage.write(key:'rvaz_neighborhood_place',value:'${address['woonplaatsnaam']??''}');
      await storage.write(key:'rvaz_neighborhood_street',value:'${address['straatnaam']??''}');
      if(mounted)Navigator.pop(context,true);
    } catch (_) { if(mounted)setState(() => error='Het adres kon niet worden opgehaald. Probeer opnieuw.'); }
    finally { if(mounted)setState(() => busy=false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFFF7F9FB),appBar:AppBar(title:const Text('Mijn adres')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
        Row(children:[
          Expanded(flex:2,child:TextField(controller:postcode,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Postcode',hintText:'3235SJ'))),
          const SizedBox(width:8),Expanded(child:TextField(controller:house,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nr.'))),
          const SizedBox(width:8),Expanded(child:TextField(controller:addition,decoration:const InputDecoration(labelText:'Toev.'))),
        ]),
        const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.save_outlined),label:Text(busy?'Ophalen…':'Adres opslaan'))),
      ]))),
      if(busy) const LinearProgressIndicator(),
      if(error.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text(error)),
    ]),
  );
}
