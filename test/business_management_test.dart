import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rvaz_android/vouchers_business.dart';

void main(){
 Future<Map<String,String>> headers()async=>{'Authorization':'Bearer fixture-only','X-RVAZ-Token':'fixture-only'};
 test('Profile changes retain account headers, moderation and complete opening hours',()async{
  final api=BusinessApi(headers:headers,client:MockClient((r)async{
   expect(r.url.host,'www.regiovoorneaanzee.nl');expect(r.method,'POST');
   expect(r.headers['Authorization'],'Bearer fixture-only');
   expect(r.url.path,'/wp-json/rvaz-business/v1/mine');
   final body=jsonDecode(r.body);expect(body['hours']['monday'],{'open':'09:00','close':'17:30','closed':false});
   return http.Response('{"ok":true,"pending_changes":true}',200);
  }));
  await api.saveProfile({'title':'Fictief testbedrijf','hours':{'monday':{'open':'09:00','close':'17:30','closed':false}}});
 });
 test('Company photos use the authenticated native moderation endpoint',()async{
  final dir=await Directory.systemTemp.createTemp('rvaz-business-media-');
  try{
   final photo=File('${dir.path}/fictitious.jpg');await photo.writeAsBytes([255,216,255,217]);
   final api=BusinessApi(headers:headers,client:MockClient((r)async{
    expect(r.method,'POST');expect(r.url.path,'/wp-json/rvaz-business/v1/mine/media');expect(r.headers['Authorization'],'Bearer fixture-only');
    expect(r.headers['content-type'],contains('multipart/form-data'));expect(r.body,contains('name="logo"'));
    return http.Response('{"ok":true,"pending_changes":true,"media":{"logo":"https://example.invalid/logo.jpg"}}',200);
   }));
   await api.uploadMedia({'logo':photo.path});
  }finally{await dir.delete(recursive:true);}
 });
 test('PRO voucher create, update and deactivation reuse the existing owner endpoint',()async{
  final methods=<String>[];
  final api=BusinessApi(headers:headers,client:MockClient((r)async{
   methods.add(r.method);expect(r.url.path,'/wp-json/rvaz-vouchers/v1/business-offer');expect(r.headers['X-RVAZ-Token'],'fixture-only');
   if(r.method=='DELETE')return http.Response('{"ok":true,"deleted":true}',200);
   final body=jsonDecode(r.body);return http.Response(jsonEncode({...body,'id':42}),200);
  }));
  final data={'title':'Fictief voordeel','offer':'10% korting','active':true,'max':10,'valid_from':'2026-11-01','valid_until':'2026-12-01'};
  await api.saveOffer(data);await api.saveOffer({...data,'offer':'15% korting'});await api.removeOffer();
  expect(methods,['POST','POST','DELETE']);
 });
 test('Denied writes and invalid server receipts never report success',()async{
  for(final status in [200,403,500]){
   final api=BusinessApi(headers:headers,client:MockClient((_)async=>http.Response(status==200?'{}':'{"message":"Geen toegang"}',status)));
   await expectLater(api.saveProfile({'title':'Fictief'}),throwsException);
  }
 });
 test('Invalid voucher dates and backwards ranges are rejected before saving',(){
  final base={'title':'Fictief','offer':'10%','max':0};
  expect(()=>validateBusinessOffer({...base,'valid_from':'2026-02-30'}),throwsException);
  expect(()=>validateBusinessOffer({...base,'valid_from':'2026-12-01','valid_until':'2026-11-01'}),throwsException);
  expect(()=>validateBusinessOffer({...base,'max':-1}),throwsException);
 });
 testWidgets('Editing both opening times does not erase either value',(tester)async{
  final hours=<String,dynamic>{'monday':{'open':'08:00','close':'18:00','closed':false}};
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:OpeningHoursEditor(hours:hours,onSave:()async{}))));
  await tester.enterText(find.widgetWithText(TextFormField,'08:00'),'09:00');
  await tester.enterText(find.widgetWithText(TextFormField,'18:00'),'17:30');
  expect(hours['monday']['open'],'09:00');expect(hours['monday']['close'],'17:30');
 });
 testWidgets('Profile editor exposes existing PRO controls and pending moderation',(tester)async{
  final api=BusinessApi(headers:headers,client:MockClient((_)async=>http.Response('{"id":42,"title":"Fictief testbedrijf","pro":true,"pending_changes":true,"hours":{}}',200)));
  await tester.pumpWidget(MaterialApp(home:BusinessManagePage(api:api)));await tester.pumpAndSettle();
  expect(find.text('Gegevens'),findsOneWidget);expect(find.text('Openingstijden'),findsOneWidget);expect(find.text('Voordeel'),findsOneWidget);
  expect(find.textContaining('Wijzigingen wachten op goedkeuring'),findsOneWidget);
 });
}
