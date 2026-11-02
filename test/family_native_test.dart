import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rvaz_android/main.dart';

void main(){
 test('Family API distinguishes an expired account from a server error',(){
  expect(()=>FamilyService.decode(http.Response(jsonEncode({'message':'Log opnieuw in.'}),401)),throwsA(isA<FamilyApiException>().having((e)=>e.loginRequired,'loginRequired',true)));
  expect(()=>FamilyService.decode(http.Response('unavailable',503)),throwsA(isA<FamilyApiException>().having((e)=>e.loginRequired,'loginRequired',false)));
  expect(FamilyService.decode(http.Response('{"items":[],"has_more":false}',200))['items'],isEmpty);
 });
 testWidgets('Notice keeps text, category and place readable with long copy', (tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:FamilyNoticeCard(notice:{'title':'Fictieve familie De Voorbeeld','message':'Een persoonlijk familiebericht.\nMet ruimte voor een herinnering.','kind':'herinnering','place':'Brielle','background':'goud','font':'sans','align':'left'},full:true)))));
  expect(find.text('Overlijden & herdenkingen'),findsOneWidget);
  expect(find.text('Brielle'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
 testWidgets('Family account route has a safe page frame and native login', (tester)async{
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(const MaterialApp(home:FamilyAccountRoute()));
  await tester.pumpAndSettle();
  expect(find.byType(AppBar),findsOneWidget);
  expect(find.byType(SafeArea),findsWidgets);
  expect(find.text('Inloggen'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
 testWidgets('Native editor changes background and renders preview without submitting', (tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home:FamilyEditorPage()));
  await tester.tap(find.text('Krant / papier'));await tester.pumpAndSettle();
  await tester.tap(find.text('Bloesem').last);await tester.pumpAndSettle();
  expect(find.text('Bloesem'),findsOneWidget);
  await tester.scrollUntilVisible(find.text('Versturen ter beoordeling'),400,scrollable:find.byType(Scrollable).first);
  await tester.tap(find.text('Versturen ter beoordeling'));await tester.pumpAndSettle();
  // Required fields stop submission. No account, website or network is involved.
  expect(find.byType(FamilyEditorPage),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
