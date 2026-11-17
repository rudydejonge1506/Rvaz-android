import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;

// Replace the complete web game, including its login prompt, before article
// sanitization removes forms and scripts. Keep the public introduction intact.
String replaceWordGameHtml(String source) {
  final fragment = html.parseFragment(source);
  var found = false;
  for (final element in fragment.querySelectorAll('.rvword, .rvaz-lockbox')) {
    if (!element.classes.contains('rvword') &&
        !element.text.contains('om mee te spelen')) continue;
    element.replaceWith(dom.Element.tag('p')..text = '[[RVAZ_WORD_GAME]]');
    found = true;
  }
  if (!found && !source.contains('[rvaz_woordspel')) return source;
  return fragment.outerHtml.replaceAll(
    RegExp(r'\[rvaz_woordspel\b[^\]]*\]'),
    '<p>[[RVAZ_WORD_GAME]]</p>',
  );
}

class WordGameException implements Exception {
  final int status;
  final String message;
  const WordGameException(this.status, this.message);
  @override String toString() => message;
}

typedef WordGameRequest = Future<Map<String, dynamic>> Function(int postId, String? word);

Future<Map<String, dynamic>> requestWordGame(int postId, String? word) async {
  final token = await const FlutterSecureStorage().read(key: 'rvaz_token');
  if (token == null || token.isEmpty) {
    throw const WordGameException(401, 'Log in om mee te spelen.');
  }
  final uri = Uri.parse('https://www.regiovoorneaanzee.nl/wp-json/rvaz-woord/v1/app/${word == null ? 'state' : 'guess'}');
  final headers = {'Accept':'application/json', 'Content-Type':'application/json',
    'Authorization':'Bearer $token', 'X-RVAZ-Token':token};
  final response = await (word == null
    ? http.get(uri.replace(queryParameters:{'post_id':'$postId'}), headers:headers)
    : http.post(uri, headers:headers, body:jsonEncode({'post_id':postId,'word':word})))
    .timeout(const Duration(seconds:20));
  dynamic data;
  try { data = jsonDecode(utf8.decode(response.bodyBytes)); } catch (_) {
    throw const WordGameException(502, 'Het spel kon niet worden geladen. Probeer opnieuw.');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw WordGameException(response.statusCode,
      data is Map && data['message'] is String ? data['message'] as String : 'Het spel is tijdelijk niet beschikbaar.');
  }
  if (data is! Map || data['rows'] is! List || data['ranking'] is! List) {
    throw const WordGameException(502, 'Het spel ontvangt geen geldig antwoord. Probeer opnieuw.');
  }
  return Map<String,dynamic>.from(data);
}

class WordGame extends StatefulWidget {
  final int postId;
  final Future<void> Function() onLogin;
  final WordGameRequest request;
  const WordGame({super.key, required this.postId, required this.onLogin, this.request = requestWordGame});
  @override State<WordGame> createState() => _WordGameState();
}

class _WordGameState extends State<WordGame> {
  final input = TextEditingController();
  Map<String,dynamic>? game;
  bool busy = true, login = false;
  String error = '';
  static const navy = Color(0xFF073B63);
  @override void initState() { super.initState(); load(); }
  @override void didUpdateWidget(covariant WordGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) { game = null; input.clear(); load(); }
  }
  @override void dispose() { input.dispose(); super.dispose(); }
  Future<void> load([String? guess]) async {
    setState(() { busy = true; error = ''; login = false; });
    try {
      final result = await widget.request(widget.postId, guess);
      if (!mounted) return;
      setState(() { game = result; if (guess != null) input.clear(); });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e is WordGameException ? e.message : 'Geen verbinding. Probeer opnieuw.';
        login = e is WordGameException && e.status == 401; });
    } finally { if (mounted) setState(() => busy = false); }
  }
  void submit() {
    if (busy || game == null || game!['done'] == true || game!['available'] != true) return;
    if (!RegExp(r'^[a-zA-Z]{6}$').hasMatch(input.text.trim())) {
      setState(() => error = 'Vul precies zes letters in.'); return;
    }
    load(input.text.trim().toLowerCase());
  }
  Color color(String? value) => switch (value) {
    'correct' => const Color(0xFF19834B),
    'present' => const Color(0xFFC18B00),
    'absent' => const Color(0xFF65717C),
    _ => Colors.white,
  };
  @override Widget build(BuildContext context) {
    final rows = game?['rows'] as List? ?? [];
    final ranking = game?['ranking'] as List? ?? [];
    final done = game?['done'] == true;
    final playable = game?['available'] == true && !done && !login;
    return Card(child: Padding(padding:const EdgeInsets.all(16), child: Column(
      crossAxisAlignment:CrossAxisAlignment.stretch, children:[
      const Text('Raad het woord', style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:8),
      const Text('Zes letters. Zes pogingen.'),
      if (busy) const Padding(padding:EdgeInsets.symmetric(vertical:16),child:LinearProgressIndicator()),
      if (login) ...[
        const SizedBox(height:12), const Text('Log gratis in om mee te spelen'),
        FilledButton(onPressed:() async { await widget.onLogin(); if (mounted) load(); },child:const Text('Inloggen of registreren')),
      ] else if (game != null) ...[
        const SizedBox(height:16),
        // Six equal cells keep the existing game usable on narrow iOS/Android screens.
        for (var r=0;r<6;r++) Row(children:[
          for (var c=0;c<6;c++) Expanded(child:AspectRatio(aspectRatio:1,child:Container(
            margin:const EdgeInsets.all(2),alignment:Alignment.center,
            decoration:BoxDecoration(color:color(r<rows.length?'${rows[r]['colors'][c]}':null),
              border:Border.all(color:const Color(0xFFD5DFE7)),borderRadius:BorderRadius.circular(4)),
            child:Text(r<rows.length?'${rows[r]['word']}'.substring(c,c+1).toUpperCase():
              (r==rows.length&&input.text.length>c?input.text[c].toUpperCase():''),
              style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:r<rows.length?Colors.white:navy)),
          ))),
        ]),
        const SizedBox(height:12),
        if (playable) ...[
          TextField(controller:input,enabled:!busy,maxLength:6,textCapitalization:TextCapitalization.characters,
            autocorrect:false,enableSuggestions:false,
            inputFormatters:[FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))],
            decoration:const InputDecoration(labelText:'Jouw woord',counterText:''),
            textInputAction:TextInputAction.done,onChanged:(_) => setState((){}),onSubmitted:(_) => submit()),
          FilledButton(onPressed:busy?null:submit,child:const Text('Probeer')),
        ],
        Text(game!['available']!=true?'Voor dit dagspel staat nog geen woord klaar.':
          game!['won']==true?'Goed geraden in ${rows.length} van de 6 pogingen!':
          done?'Het woord was ${'${game!['answer']??''}'.toUpperCase()}.':'Nog ${game!['remaining']} pogingen.'),
        const SizedBox(height:10), const Text('Groen: juiste plek · Geel: andere plek · Grijs: niet in het woord'),
        const SizedBox(height:20),
        const Text('Ranglijst van dit dagspel',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:navy)),
        if(ranking.isEmpty) const Text('Er heeft nog niemand gewonnen.'),
        ..._ranking(ranking),
      ],
      if(error.isNotEmpty && !login) ...[
        Text(error,semanticsLabel:error),
        TextButton(onPressed:busy?null:() => load(),child:const Text('Opnieuw proberen')),
      ],
    ])));
  }
  List<Widget> _ranking(List entries) {
    var rank=0, previous=0;
    return List<Widget>.generate(entries.length,(i) {
      final e=entries[i]; final attempts=e['attempts'] as int;
      if(attempts!=previous) rank=i+1;
      previous=attempts;
      return Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Text('$rank. ${e['name']} — $attempts/6'));
    });
  }
}
