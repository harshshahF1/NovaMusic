import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/track.dart';

class YouTubePlayerSheet extends StatefulWidget {
  final List<Track> queue;
  final int initialIndex;
  const YouTubePlayerSheet({super.key, required this.queue, required this.initialIndex});

  @override State<YouTubePlayerSheet> createState() => _YouTubePlayerSheetState();
}

class _YouTubePlayerSheetState extends State<YouTubePlayerSheet> {
  late final List<Track> queue;
  late int index;
  late final WebViewController controller;
  bool ready = false;

  Track get track => queue[index];

  @override
  void initState() {
    super.initState();
    queue = widget.queue.where((t) => t.isYouTube).toList();
    index = widget.initialIndex.clamp(0, queue.isEmpty ? 0 : queue.length - 1);
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        if (mounted) setState(() => ready = true);
      }));
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    if (queue.isEmpty) return;
    if (mounted) setState(() => ready = false);
    final id = track.youtubeVideoId!;
    await controller.loadRequest(Uri.parse(
      'https://www.youtube.com/embed/$id?autoplay=1&playsinline=1&rel=0&enablejsapi=1&origin=https://www.youtube.com',
    ));
  }

  Future<void> _next() async {
    if (index + 1 >= queue.length) return;
    setState(() => index++);
    await _loadVideo();
  }

  Future<void> _previous() async {
    if (index == 0) return;
    setState(() => index--);
    await _loadVideo();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: Row(children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
          const Expanded(child: Text('NOW PLAYING', textAlign: TextAlign.center, style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w800))),
          const SizedBox(width: 48),
        ]),
      ),
      AspectRatio(
        aspectRatio: 16 / 9,
        child: ready ? WebViewWidget(controller: controller) : const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator())),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
        Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 15)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          IconButton(onPressed: _previous, icon: const Icon(Icons.skip_previous_rounded, size: 42)),
          const Icon(Icons.play_circle_fill_rounded, size: 56),

          IconButton(onPressed: _next, icon: const Icon(Icons.skip_next_rounded, size: 42)),
        ]),
        const SizedBox(height: 10),
        const Text('Official YouTube playback', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
      ])),
    ]),
  );
}
