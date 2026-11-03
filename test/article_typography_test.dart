import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';

Iterable<({String text,TextStyle style})> spans(InlineSpan span,[TextStyle inherited=const TextStyle()]) sync* {
 if(span is TextSpan){
  final style=inherited.merge(span.style);
  if(span.text?.isNotEmpty==true)yield(text:span.text!,style:style);
  for(final child in span.children??<InlineSpan>[])yield* spans(child,style);
 }
}
void main(){
 testWidgets('WordPress heading children use Dosis 600; body emphasis stays Open Sans bold',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:RvazArticleHtml(data:'<h2><strong>Tussenkop</strong> <span style="font-family:Arial;font-weight:900">naast</span></h2><p>Gewone tekst met <strong>belangrijk</strong>.</p><h4><b>Kleine kop</b></h4>')))));
  await tester.pumpAndSettle();
  final text=tester.widgetList<RichText>(find.byType(RichText)).expand((w)=>spans(w.text)).toList();
  for(final label in ['Tussenkop','naast','Kleine kop']){
   final pieces=text.where((s)=>s.text.contains(label)).toList();expect(pieces,isNotEmpty);
   for(final piece in pieces){expect(piece.style.fontFamily,'Dosis');expect(piece.style.fontWeight,FontWeight.w600);expect(piece.style.color,const Color(0xff073b66));}
  }
  final emphasis=text.firstWhere((s)=>s.text.contains('belangrijk'));
  expect(emphasis.style.fontFamily,'OpenSans');expect(emphasis.style.fontWeight,FontWeight.w700);
  final regular=text.firstWhere((s)=>s.text.contains('Gewone tekst'));
  expect(regular.style.fontFamily,'OpenSans');expect(regular.style.fontSize,16);
  expect(tester.takeException(),isNull);
 });
 testWidgets('Editorial preview fits a phone with enlarged text and preserves wording',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  for(final font in ['Dosis','OpenSans']){
   final loader=FontLoader(font)..addFont(rootBundle.load('assets/fonts/$font.ttf'));await loader.load();
  }
  final boundary=GlobalKey();
  await tester.pumpWidget(MaterialApp(home:MediaQuery(data:const MediaQueryData(size:Size(390,844),textScaler:TextScaler.linear(1.3)),child:Scaffold(backgroundColor:Colors.white,body:RepaintBoundary(key:boundary,child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('Komende week meer zon en kans op lichte vorst',style:RvazTypography.articleTitle(390)),const SizedBox(height:24),
   const RvazArticleHtml(data:'<p>Voorbeeld om de nieuwe typografie te controleren.</p><h2><strong>Steeds meer zon en temperaturen rond 10 graden</strong></h2><p>De lopende tekst gebruikt hetzelfde lettertype en dezelfde regelafstand als de website.</p><h3>Een duidelijke tussenkop</h3><p>Ook op een kleiner scherm blijft deze tekst goed leesbaar.</p>'),
  ]))))))));
  await tester.pumpAndSettle();
  expect(find.text('Komende week meer zon en kans op lichte vorst'),findsOneWidget);
  expect(tester.takeException(),isNull);
  if(Platform.environment['RVAZ_TYPOGRAPHY_PREVIEW']=='1'){
   await tester.runAsync(()async{
   final image=await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:2);
   final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
   Directory('evidence').createSync(recursive:true);File('evidence/article-typography.png').writeAsBytesSync(bytes!.buffer.asUint8List());
   });
  }
 });
}
