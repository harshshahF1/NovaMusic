import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/track.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = TextEditingController();
  List<Track> results = [];
  bool loading = false;
  Track? current;

  Future<void> search() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;
    setState(() => loading = true);
    final data = await musicService.search(q);
    if (mounted) setState(() { results = data; loading = false; });
  }

  Future<void> play(Track t) async {
    setState(() => current = t);
    await initAudioHandler();
    final handler = audioHandler;
    if (handler == null) return;
    try {
      await handler.load(t);
      await handler.play();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9B5CFF), Color(0xFF39D9FF)],
                        ),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text('NOVAMUSIC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                    const Spacer(),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                  ]),
                  const SizedBox(height: 30),
                  const Text('Your sound.', style: TextStyle(fontSize: 35, fontWeight: FontWeight.w800)),
                  const Text('One place for every vibe.', style: TextStyle(fontSize: 17, color: Colors.white54)),
                  const SizedBox(height: 22),
                  TextField(
                    controller: controller,
                    onSubmitted: (_) => search(),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search songs, artists, albums…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(onPressed: search, icon: const Icon(Icons.arrow_forward_rounded)),
                      filled: true,
                      fillColor: const Color(0xFF12151D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (loading) const LinearProgressIndicator(minHeight: 2),
                  if (!loading && results.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 30), child: _EmptyState()),
                ],
              ),
            ),
          ),
          if (results.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              sliver: SliverList.builder(
                itemCount: results.length,
                itemBuilder: (_, i) => _TrackTile(
                  track: results[i],
                  selected: current?.id == results[i].id,
                  onTap: () => play(results[i]),
                ),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: current == null ? null : _MiniPlayer(track: current!),
  );
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final bool selected;
  final VoidCallback onTap;
  const _TrackTile({required this.track, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: selected ? const Color(0xFF171A25) : Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 58, height: 58,
                child: track.artworkUrl == null
                  ? Container(color: const Color(0xFF20232C), child: const Icon(Icons.music_note_rounded))
                  : CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFF20232C),
                        child: const Icon(Icons.music_note_rounded),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 5),
                Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
              ],
            )),
            IconButton(onPressed: onTap, icon: Icon(selected ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 34)),
          ]),
        ),
      ),
    ),
  );
}

class _MiniPlayer extends StatelessWidget {
  final Track track;
  const _MiniPlayer({required this.track});

  @override
  Widget build(BuildContext context) {
    final handler = audioHandler;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151821),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44, height: 44,
            child: track.artworkUrl == null
              ? const ColoredBox(color: Color(0xFF20232C), child: Icon(Icons.music_note))
              : CachedNetworkImage(imageUrl: track.artworkUrl!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        )),
        if (handler != null)
          IconButton(
            onPressed: () => handler.playing ? handler.pause() : handler.play(),
            icon: StreamBuilder<bool>(
              stream: handler.playbackState.map((s) => s.playing).distinct(),
              initialData: false,
              builder: (_, snap) => Icon(snap.data == true ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(children: [
      Icon(Icons.album_rounded, size: 64, color: Colors.white.withValues(alpha: .13)),
      const SizedBox(height: 12),
      const Text('Search for something you love', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      const Text('Your results will appear here.', style: TextStyle(color: Colors.white38)),
    ]),
  );
}
