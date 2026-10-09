import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/wonen.dart';

void main() {
  testWidgets('broker coupon replaces introductory price and follows a changed plan', (tester) async {
    final calls = <Map<String, dynamic>>[]; WonenCouponQuote? last;
    Future<dynamic> request(String path, {Map<String, dynamic>? body}) async { calls.add(body!); return {'total': body['plan'] == 'pro' ? '10.00' : '0.00'}; }
    Widget app(String plan, String price) => MaterialApp(home: Scaffold(body: WonenCouponField(
      audience: 'makelaar', plan: plan, normalPrice: price, defaultPrice: '24.50', request: request, onChanged: (quote) => last = quote)));
    await tester.pumpWidget(app('basis', '49.00')); await tester.pump();
    expect(find.text('Eerste maand: €24,50'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'makelaar'); await tester.pump(const Duration(milliseconds: 350)); await tester.pump();
    expect(find.text('Eerste maand: €0,00'), findsOneWidget); expect(last!.ready, isTrue); expect(last!.code, 'MAKELAAR');
    expect(calls.last, {'audience':'makelaar','plan':'basis','code':'MAKELAAR'});
    await tester.pumpWidget(app('pro', '179.00')); await tester.pump(); await tester.pump();
    expect(calls.last['plan'], 'pro'); expect(last!.total, '10.00');
    expect(find.text('Daarna €179,00 per maand. Korting wordt niet gestapeld.'), findsOneWidget);
  });
  testWidgets('used or invalid code blocks request until removed', (tester) async {
    WonenCouponQuote? last;
    Future<dynamic> request(String path, {Map<String, dynamic>? body}) async { throw const WonenApiException(400, 'Kortingscode is opgebruikt.'); }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WonenCouponField(audience:'particulier',normalPrice:'25.00',defaultPrice:'25.00',request:request,onChanged:(q)=>last=q)))); await tester.pump();
    await tester.enterText(find.byType(TextField), 'OP'); await tester.pump(const Duration(milliseconds:350)); await tester.pump();
    expect(last!.ready,isFalse);expect(find.text('Kortingscode is opgebruikt.'),findsOneWidget);
    await tester.enterText(find.byType(TextField), '');await tester.pump(const Duration(milliseconds:350));await tester.pump();
    expect(last!.ready,isTrue);expect(last!.code,'');expect(find.text('Eén maand plaatsing: €25,00'),findsOneWidget);
  });
  testWidgets('returning broker cannot use new-office coupon', (tester) async {
    int calls=0;WonenCouponQuote? last;
    Future<dynamic> request(String path,{Map<String,dynamic>? body})async{calls++;return {'total':'0.00'};}
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WonenCouponField(audience:'makelaar',plan:'basis',normalPrice:'49.00',defaultPrice:'49.00',returning:true,request:request,onChanged:(q)=>last=q))));await tester.pump();
    await tester.enterText(find.byType(TextField),'MAKELAAR');await tester.pump(const Duration(milliseconds:350));await tester.pump();
    expect(calls,0);expect(last!.ready,isFalse);expect(find.textContaining('alleen voor een nieuw makelaarskantoor'),findsOneWidget);
  });
  testWidgets('late response cannot overwrite a newer coupon quote', (tester) async {
    final old=Completer<dynamic>();WonenCouponQuote? last;
    Future<dynamic> request(String path,{Map<String,dynamic>? body})async=>body!['code']=='OLD'?old.future:{'total':'15.00'};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WonenCouponField(audience:'particulier',normalPrice:'25.00',defaultPrice:'25.00',request:request,onChanged:(q)=>last=q))));await tester.pump();
    await tester.enterText(find.byType(TextField),'OLD');await tester.pump(const Duration(milliseconds:350));
    await tester.enterText(find.byType(TextField),'NEW');await tester.pump(const Duration(milliseconds:350));await tester.pump();
    old.complete({'total':'0.00'});await tester.pump();expect(last!.code,'NEW');expect(last!.total,'15.00');
  });
  testWidgets('private order confirms discounted price and preserves base tariff and month contract', (tester) async {
    Map<String,dynamic>? ordered; bool refreshed=false;
    Future<dynamic> request(String path,{Map<String,dynamic>? body})async{
      if(path.endsWith('/bestellen')){ordered=body;return {'status':'open'};}return {'total':'15.00'};
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WonenPrivateOrder(id:12,request:request,refresh:()=>refreshed=true))));await tester.pump();
    await tester.enterText(find.byType(TextField),'PRIV10');await tester.pump(const Duration(milliseconds:350));await tester.pump();
    await tester.tap(find.text('Plaatsing aanvragen'));await tester.pumpAndSettle();
    expect(find.textContaining('€15,00 voor één woning'),findsOneWidget);
    await tester.tap(find.text('Bevestigen'));await tester.pumpAndSettle();
    expect(ordered,{'confirm':true,'expected_price':'25.00','expected_period':'1_month','coupon_code':'PRIV10'});expect(refreshed,isTrue);
  });
}
