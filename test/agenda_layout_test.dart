import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';
void main(){
 test('Agenda sorts times and preserves recurring dates while removing duplicate occurrences',(){
  final events=[
   {'id':1,'title':'Weekmarkt','date':'2026-11-04','time':'09:00','place':'Rockanje'},
   {'id':1,'title':'Weekmarkt','date':'2026-11-11','time':'09:00','place':'Rockanje'},
   {'id':1,'title':'Weekmarkt','date':'2026-11-04','time':'09:00','place':'Rockanje'},
   {'id':2,'title':'Vroege markt','date':'2026-11-04','time':'08:00','place':'Rockanje'},
   {'id':3,'title':'Voorbij','date':'2026-10-01','place':'Rockanje'},
   {'id':4,'title':'Brielle','date':'2026-11-04','place':'Brielle'},
  ];
  final items=agendaUpcoming(events,now:DateTime(2026,11,3),place:'Rockanje');
  expect(items.length,3);expect(items.first['id'],2);expect(items.last['date'],'2026-11-11');
 });
 testWidgets('Agenda has date column, website title style and readable phone layout',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:AgendaPage(showPromotions:false,loader:()async=>[{'id':1,'title':'Een gezellige middag met muziek','date':'2099-11-04','time':'14:00','place':'Oostvoorne','venue':'Cultureel centrum','price':'Gratis'}])))));
  await tester.pumpAndSettle();
  expect(find.text('november 2099'),findsOneWidget);expect(find.text('14:00'),findsOneWidget);
  final title=tester.widget<Text>(find.text('Een gezellige middag met muziek'));expect(title.style?.fontFamily,'Dosis');expect(title.style?.fontWeight,FontWeight.w600);
  expect(find.text('Cultureel centrum · Oostvoorne'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
