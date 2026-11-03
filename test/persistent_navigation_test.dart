import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';
void main(){
 testWidgets('One bottom bar remains available on details with Account at the right',(tester)async{
  await tester.pumpWidget(MaterialApp(navigatorKey:navigatorKey,builder:(context,child)=>AppNavigationFrame(child:child!),home:const Scaffold(body:Text('Root page'))));
  navigatorKey.currentState!.push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:Text('Detail page'))));await tester.pumpAndSettle();
  for(final label in ['Nieuws','Mijn Voorne','112 & P2000','Agenda','Account']){expect(find.widgetWithText(NavigationDestination,label),findsOneWidget);}
  expect(find.byType(Drawer),findsNothing);expect(find.byTooltip('Menu'),findsNothing);
  expect(tester.getCenter(find.widgetWithText(NavigationDestination,'Account')).dx,greaterThan(tester.getCenter(find.widgetWithText(NavigationDestination,'Agenda')).dx));
  await tester.tap(find.widgetWithText(NavigationDestination,'Nieuws'));await tester.pumpAndSettle();expect(find.text('Detail page'),findsNothing);
 });
 testWidgets('All app functions remain categorized and searchable',(tester)async{
  final chosen=<String>[];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:AccountMenuSections(onSelected:chosen.add,showBusinessManagement:true)))));
  final keys=accountMenuGroups.values.expand((x)=>x).map((x)=>x.$1).toList();
  expect(keys.toSet().length,keys.length);
  for(final key in ['family','wonen','my-wonen','my-business','scan','coast','waste','feedback','my-family','vouchers']){expect(keys,contains(key));}
  await tester.enterText(find.byType(TextField),'strand');await tester.pumpAndSettle();expect(find.text('Strandweer & kust'),findsOneWidget);expect(find.text('Mijn bedrijf'),findsNothing);
  await tester.enterText(find.byType(TextField),'bedrijf');await tester.pumpAndSettle();await tester.tap(find.text('Mijn bedrijf'));expect(chosen,['my-business']);
 });
}
