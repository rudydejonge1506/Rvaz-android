import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/word_game.dart';

Map<String,dynamic> state({List<Map<String,dynamic>> rows=const [],bool done=false}) => {
  'date':'2026-11-17','available':true,'rows':rows,'ranking':[
    {'name':'SpelerEen','attempts':2},{'name':'SpelerTwee','attempts':2},{'name':'SpelerDrie','attempts':4}],
  'won':false,'done':done,'remaining':6-rows.length,'answer':done?'strand':null,
};
void main(){
  test('Replaces rendered game without changing introduction or ordinary articles',(){
    const plain='<p>Een nieuwsbericht</p>';
    expect(replaceWordGameHtml(plain),plain);
    final result=replaceWordGameHtml('<p>Openbare intro</p><section class="rvword"><form><input></form><p>Spel laden</p></section><p>Na het spel</p>');
    expect(result,contains('Openbare intro')); expect(result,contains('Na het spel'));
    expect('[[RVAZ_WORD_GAME]]'.allMatches(result).length,1); expect(result, isNot(contains('<form')));
    expect(replaceWordGameHtml('<p>Intro</p>[rvaz_woordspel]'),contains('[[RVAZ_WORD_GAME]]'));
    expect(replaceWordGameHtml('<section class="rvaz-lockbox">Log gratis in om mee te spelen</section>'),contains('[[RVAZ_WORD_GAME]]'));
    expect(replaceWordGameHtml('<section class="rvaz-lockbox">Log in om te lezen</section>'),isNot(contains('[[RVAZ_WORD_GAME]]')));
  });
  testWidgets('Login required and account return reloads the same daily article', (tester)async{
    var logged=false; final ids=<int>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:WordGame(postId:18475,onLogin:()async{logged=true;},request:(id,word)async{
      ids.add(id); if(!logged)throw const WordGameException(401,'Log in'); return state();
    })))));
    await tester.pumpAndSettle(); expect(find.byType(TextField),findsNothing);
    await tester.tap(find.text('Inloggen of registreren')); await tester.pumpAndSettle();
    expect(ids,[18475,18475]); expect(find.byType(TextField),findsOneWidget);
  });
  testWidgets('Six-letter input submits once, retains server rows, and ties share rank', (tester)async{
    tester.view.physicalSize=const Size(320,900); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final sent=<String>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:WordGame(postId:18475,onLogin:()async{},request:(id,word)async{
      if(word!=null)sent.add(word);
      return state(rows:word==null?[]:[{'word':word,'colors':['absent','correct','present','absent','absent','correct']}]);
    })))));
    await tester.pumpAndSettle();
    expect(find.text('1. SpelerEen — 2/6'),findsOneWidget); expect(find.text('1. SpelerTwee — 2/6'),findsOneWidget);
    expect(find.text('3. SpelerDrie — 4/6'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'KORT'); await tester.tap(find.text('Probeer')); await tester.pump();
    expect(sent,isEmpty); expect(find.text('Vul precies zes letters in.'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'STRAND'); await tester.tap(find.text('Probeer')); await tester.pumpAndSettle();
    expect(sent,['strand']); expect(find.text('Nog 5 pogingen.'),findsOneWidget); expect(tester.takeException(),isNull);
  });
  testWidgets('Completed round cannot submit more guesses', (tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:WordGame(postId:1,onLogin:()async{},request:(id,word)async=>state(done:true))))));
    await tester.pumpAndSettle(); expect(find.byType(TextField),findsNothing); expect(find.text('Probeer'),findsNothing);
  });
}
