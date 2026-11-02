import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';

void main(){
 testWidgets('Bottom navigation remains on detail and Menu keeps detail open',(tester)async{
  await tester.pumpWidget(MaterialApp(
   navigatorKey:navigatorKey,
   builder:(context,child)=>AppNavigationFrame(child:child!),
   home:Scaffold(appBar:AppBar(leading:IconButton(tooltip:'Menu',icon:const Icon(Icons.menu),onPressed:()=>ShellTabController.openMenu?.call())),body:const Text('Root page')),
  ));
  navigatorKey.currentState!.push(MaterialPageRoute<void>(
   builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Detail page')),body:const TextField()),
  ));
  await tester.pumpAndSettle();
  for(final title in ['Nieuws','112 & P2000','Agenda','Familie','Account']){
   expect(find.widgetWithText(NavigationDestination,title),findsOneWidget);
  }
  ShellTabController.openMenu!.call();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Evenement aanmelden'),200,
   scrollable:find.descendant(of:find.byType(Drawer),matching:find.byType(Scrollable)));
  expect(find.text('Evenement aanmelden'),findsOneWidget);
  await tester.tap(find.byTooltip('Menu sluiten'));
  await tester.pumpAndSettle();
  expect(find.text('Detail page'),findsOneWidget);
  await tester.tap(find.widgetWithText(NavigationDestination,'Nieuws'));
  await tester.pumpAndSettle();
  expect(find.text('Root page'),findsOneWidget);
  expect(find.text('Detail page'),findsNothing);
 });
}
