import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rvaz_android/main.dart';

void main(){
 test('Place news uses its full category archive, with distinct older pages and one category lookup',()async{
  final requests=<Uri>[];
  final client=MockClient((r)async{
   requests.add(r.url);
   if(r.url.path.endsWith('/categories'))return http.Response(jsonEncode([{'id':134,'slug':'rockanje'}]),200);
   expect(r.url.queryParameters['categories'],'134');expect(r.url.queryParameters['per_page'],'15');
   expect(r.url.queryParameters['_fields'],isNot(contains('content')));
   final page=int.parse(r.url.queryParameters['page']!);
   return http.Response(jsonEncode(List.generate(15,(i)=>{'id':(page-1)*15+i+1,'title':{'rendered':'Bericht uit het lokale archief'},'date':'2026-10-01T10:00:00','_embedded':{}})),200,headers:{'x-wp-totalpages':'37'});
  });
  final source=PlaceNewsSource('Rockanje',client:client);
  final a=await source.call(1,'2026-11-03T12:00:00Z'),b=await source.call(2,'2026-11-03T12:00:00Z');
  expect(a.posts.length,15);expect(b.posts.length,15);expect(b.posts.first['id'],16);
  expect(a.hasMore,isTrue);expect(b.posts.every((p)=>p['place']=='Rockanje'),isTrue);
  expect(requests.where((u)=>u.path.endsWith('/categories')).length,1);
  expect(requests.where((u)=>u.path.contains('/rvaz-app/')),isEmpty);
 });
 testWidgets('Place page uses newsroom cards and loads older local news',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final calls=<int>[];
  await tester.pumpWidget(MaterialApp(home:PlaceNewsPage(place:'Hellevoetsluis',loader:(page,before)async{
   calls.add(page);return NewsroomBatch(List.generate(15,(i)=>{'id':(page-1)*15+i,'title':'Lokaal nieuws ${(page-1)*15+i}','date':'2026-10-01T10:00:00'}),page==1);
  })));
  await tester.pumpAndSettle();expect(find.text('Nieuws uit Hellevoetsluis'),findsOneWidget);expect(find.byType(NewsroomArticleTile),findsWidgets);
  await tester.scrollUntilVisible(find.text('Meer laden'),450,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.text('Meer laden'));await tester.tap(find.text('Meer laden'));await tester.pumpAndSettle();
  expect(calls,[1,2]);await tester.scrollUntilVisible(find.text('Lokaal nieuws 16'),300,scrollable:find.byType(Scrollable).first);expect(find.text('Lokaal nieuws 16'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
 testWidgets('Places directory includes all nine places with the new typography',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:PlacesPage()));
  for(final place in PlacesPage.regionPlaces){
   await tester.scrollUntilVisible(find.text(place),250,scrollable:find.byType(Scrollable).first);
   final title=tester.widget<Text>(find.text(place));expect(title.style?.fontFamily,'Dosis');expect(title.style?.fontWeight,FontWeight.w600);
  }
  expect(tester.takeException(),isNull);
 });
}
