import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';

Map<String,dynamic> post(int id)=>{'id':id,'title':'Nieuwsbericht $id','date':'2026-11-02T05:00:00','image':''};

void main(){
 testWidgets('More news appends without duplicates or losing the current scroll position',(tester)async{
  final calls=<int>[];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:NewsroomFeed(showPromotions:false,
   loader:(page,before)async{calls.add(page);return page==1
    ? NewsroomBatch(List.generate(15,(i)=>post(i+1)),true)
    : NewsroomBatch([post(15),post(16),post(17)],false);}))));
  await tester.pumpAndSettle();
  expect(find.text('Nieuwsbericht 1'),findsOneWidget);
  await tester.scrollUntilVisible(find.byKey(const ValueKey('newsroom-load-more')),400,scrollable:find.byType(Scrollable).first);
  final scroll=tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  final before=scroll.pixels;
  await tester.tap(find.text('Meer laden'));
  await tester.pumpAndSettle();
  expect(calls,[1,2]);
  expect(scroll.pixels,closeTo(before,1));
  expect(find.text('Nieuwsbericht 15'),findsOneWidget);
  expect(find.text('Nieuwsbericht 17'),findsOneWidget);
  expect(find.text('Meer laden'),findsNothing);
 });
 testWidgets('A paging failure preserves articles and retries the same page',(tester)async{
  var failed=false;final calls=<int>[];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:NewsroomFeed(showPromotions:false,
   loader:(page,before)async{calls.add(page);if(page==2&&!failed){failed=true;throw Exception('Offline');}
    return page==1?NewsroomBatch([post(1)],true):NewsroomBatch([post(2)],false);}))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Meer laden'));await tester.pumpAndSettle();
  expect(find.text('Nieuwsbericht 1'),findsOneWidget);
  await tester.ensureVisible(find.text('Opnieuw proberen'));
  await tester.tap(find.text('Opnieuw proberen'));await tester.pumpAndSettle();
  expect(calls,[1,2,2]);expect(find.text('Nieuwsbericht 2'),findsOneWidget);
 });
 testWidgets('Paid PRO businesses appear and free profiles do not',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:NewsroomProBusinesses(items:Future.value([
   {'id':1,'title':'Betaald PRO-bedrijf','pro':true},
   {'id':2,'title':'Gratis bedrijf','pro':false},
  ])))));
  await tester.pumpAndSettle();
  expect(find.text('PRO-bedrijven'),findsOneWidget);
  expect(find.text('Betaald PRO-bedrijf'),findsOneWidget);
  expect(find.text('Gratis bedrijf'),findsNothing);
 });
}
