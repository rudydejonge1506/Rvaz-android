import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rvaz_android/main.dart';
void main(){
 test('Removing a favorite uses the current account and saved false',()async{
  FlutterSecureStorage.setMockInitialValues({'rvaz_token':'fictitious-test-token'});
  final client=MockClient((request)async{
   expect(request.headers['Authorization'],'Bearer fictitious-test-token');
   final data=jsonDecode(request.body);expect(data['post_id'],42);expect(data['saved'],false);
   return http.Response('{"saved":false}',200);
  });
  expect(await FavoritesService.set({'id':42},saved:false,client:client),isTrue);
 });
 testWidgets('Saved article disappears only after successful removal',(tester)async{
  final changes=<bool>[];
  await tester.pumpWidget(MaterialApp(home:SavedPage(loader:()async=>[{'id':42,'title':'Bewaard artikel'}],update:(post,saved)async{changes.add(saved);return true;})));
  await tester.pumpAndSettle();await tester.tap(find.byTooltip('Verwijderen uit favorieten'));await tester.pumpAndSettle();
  expect(changes,[false]);expect(find.text('Bewaard artikel'),findsNothing);expect(find.text('Je hebt nog geen artikelen bewaard.'),findsOneWidget);
 });
 testWidgets('A failed removal keeps the saved article visible',(tester)async{
  await tester.pumpWidget(MaterialApp(home:SavedPage(loader:()async=>[{'id':42,'title':'Bewaard artikel'}],update:(post,saved)async=>false)));
  await tester.pumpAndSettle();await tester.tap(find.byTooltip('Verwijderen uit favorieten'));await tester.pumpAndSettle();
  expect(find.text('Bewaard artikel'),findsOneWidget);expect(find.text('Verwijderen is niet gelukt. Probeer opnieuw.'),findsOneWidget);
 });
}
