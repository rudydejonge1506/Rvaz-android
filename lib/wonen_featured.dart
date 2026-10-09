import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'wonen.dart';

class FeaturedHomes extends StatefulWidget {
  final Future<List<Map<String, dynamic>>>? items;
  const FeaturedHomes({super.key, this.items});
  @override State<FeaturedHomes> createState() => _FeaturedHomesState();
}

class _FeaturedHomesState extends State<FeaturedHomes> {
  late final Future<List<Map<String, dynamic>>> _items = widget.items ?? _load();
  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final response = await http.get(Uri.parse('$wonenApi/uitgelicht'),
          headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return [];
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(6).toList();
    } catch (_) { return []; }
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _items, builder: (context, snapshot) {
      final items = snapshot.data ?? [];
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.home_outlined), const SizedBox(width: 8),
            const Expanded(child: Text('Uitgelichte woningen', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WonenPage())), child: const Text('Alle woningen'))]),
          SizedBox(height: 238, child: ListView.separated(scrollDirection: Axis.horizontal,
            itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final image = wonenText(item, 'image');
              return SizedBox(width: 238, child: Card(clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WoningDetailPage(item: item))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(height: 125, width: double.infinity, child: image.isEmpty
                      ? const Center(child: Icon(Icons.home_outlined, size: 48))
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.home_outlined, size: 48)))),
                    Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(wonenText(item, 'title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(wonenText(item, 'plaats'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${wonenText(item, 'prijs')} · ${wonenText(item, 'transactie')}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                  ]))));
            })),
        ]));
    });
}
