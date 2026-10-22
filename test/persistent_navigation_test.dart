import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';

void main(){
 testWidgets('Bottom navigation remains on detail and Menu keeps detail open',(tester)async{
  await tester.pumpWidget(MaterialApp(
   navigatorKey:navigatorKey,
   builder:(context,child)=>AppNavigationFrame(child:child!),
   home:const Scaffold(body:Text('Root page')),
  ));
  navigatorKey.currentState!.push(MaterialPageRoute<void>(
   builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Detail page')),body:const TextField()),
  ));
  await tester.pumpAndSettle();
  for(final title in ['Home','Agenda','P2000','Menu']){
   expect(find.widgetWithText(NavigationDestination,title),findsOneWidget);
  }
  await tester.tap(find.widgetWithText(NavigationDestination,'Menu'));
  await tester.pumpAndSettle();
  expect(find.text('Evenement aanmelden'),findsOneWidget);
  await tester.tap(find.byTooltip('Menu sluiten'));
  await tester.pumpAndSettle();
  expect(find.text('Detail page'),findsOneWidget);
  await tester.tap(find.widgetWithText(NavigationDestination,'Home'));
  await tester.pumpAndSettle();
  expect(find.text('Root page'),findsOneWidget);
  expect(find.text('Detail page'),findsNothing);
 });
}
