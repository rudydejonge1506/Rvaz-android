import 'dart:convert';
import 'package:http/http.dart' as http;

String businessError(Object error)=>error.toString().replaceFirst(RegExp(r'^(Exception|FormatException): '),'');

void validateBusinessOffer(Map<String,dynamic> data){
 if('${data['title']??''}'.trim().isEmpty||'${data['offer']??''}'.trim().isEmpty)throw Exception('Titel en aanbieding zijn verplicht.');
 if(data['max'] is! int||(data['max'] as int)<0)throw Exception('Vul een geldig maximum in; 0 betekent onbeperkt.');
 final dates=<DateTime>[];
 for(final key in ['valid_from','valid_until']){
  final value='${data[key]??''}';
  if(value.isEmpty)continue;
  final date=DateTime.tryParse(value);
  if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)||date==null||date.toIso8601String().substring(0,10)!=value)throw Exception('Gebruik een geldige datum als JJJJ-MM-DD.');
  dates.add(date);
 }
 if(dates.length==2&&dates.last.isBefore(dates.first))throw Exception('De einddatum moet op of na de begindatum liggen.');
}

/// Reuses the website's owner checks, moderation and PRO entitlements.
/// Canonical host avoids redirecting authenticated POST requests.
class BusinessApi{
 final http.Client? client;
 final Future<Map<String,String>> Function() headers;
 BusinessApi({required this.headers,this.client});
 Future<Map<String,dynamic>> request(String route,{String method='GET',Map<String,dynamic>? data})async{
  final owned=client==null,c=client??http.Client();
  try{
   final h=await headers();
   if(!h.containsKey('Authorization')&&!h.containsKey('X-RVAZ-Token'))throw Exception('Log eerst in bij Mijn RVAZ.');
   final req=http.Request(method,Uri.parse('https://www.regiovoorneaanzee.nl/wp-json/$route'))..headers.addAll(h)..followRedirects=false;
   if(data!=null){req.headers['Content-Type']='application/json';req.body=jsonEncode(data);}
   final response=await http.Response.fromStream(await c.send(req).timeout(const Duration(seconds:20)));
   dynamic decoded;try{decoded=jsonDecode(response.body);}catch(_){}
   if(response.statusCode<200||response.statusCode>=300){
    final message=decoded is Map?decoded['message']:null;
    throw Exception(message??(response.statusCode==401?'Log opnieuw in bij Mijn RVAZ.':'De wijziging is niet bevestigd. Probeer opnieuw.'));
   }
   if(decoded is! Map||decoded.containsKey('code')||decoded['ok']==false)throw Exception('De server heeft de wijziging niet bevestigd.');
   return Map<String,dynamic>.from(decoded);
  }finally{if(owned)c.close();}
 }
 Future<Map<String,dynamic>> mine()=>request('rvaz-business/v1/mine');
 Future<Map<String,dynamic>> saveProfile(Map<String,dynamic> data)async{
  final result=await request('rvaz-business/v1/mine',method:'POST',data:data);
  if(result['ok']!=true||result['pending_changes']!=true)throw Exception('De wijzigingen zijn niet bevestigd. Probeer opnieuw.');
  return result;
 }
 Future<Map<String,dynamic>> offer()=>request('rvaz-vouchers/v1/business-offer');
 Future<Map<String,dynamic>> saveOffer(Map<String,dynamic> data)async{
  validateBusinessOffer(data);
  final result=await request('rvaz-vouchers/v1/business-offer',method:'POST',data:data);
  if((int.tryParse('${result['id']}')??0)<=0)throw Exception('De voucher is niet bevestigd. Probeer opnieuw.');
  return result;
 }
 Future<Map<String,dynamic>> removeOffer()async{
  final result=await request('rvaz-vouchers/v1/business-offer',method:'DELETE');
  if(result['ok']!=true)throw Exception('Deactiveren is niet bevestigd.');
  return result;
 }
}
