import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/youtube_player_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  final library = LibraryService();

  List<Track> results = [];
  List<Track> liked = [];
  List<Track> recent = [];
  List<String> playlists = [];
  Track? current;
  bool loading = false;
  bool playerLoading = false;
  int tab = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    _refreshLibrary();
    initAudioHandler().then((_) {
      final h = audioHandler;
      h?.mediaItem.listen((item) {
        if (!mounted || item == null) return;
        final all = [...results, ...liked, ...recent];
        Track? match;
        for (final t in all) { if (t.id == item.id) { match = t; break; } }
        if (match != null) setState(() => current = match);
      });
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshLibrary() async {
    final l = await library.liked();
    final r = await library.recent();
    final p = await library.playlistNames();
    if (mounted) setState(() { liked = l; recent = r; playlists = p; });
  }

  Future<void> search() async {
    final q = searchController.text.trim();
    if (q.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { loading = true; error = null; tab = 1; });
    try {
      final data = await musicService.search(q);
      if (!mounted) return;
      setState(() { results = data; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        results = [];
        loading = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> play(Track t, {List<Track>? sourceQueue}) async {
    if (t.isYouTube) {
      final queue = (sourceQueue ?? results).where((x) => x.isYouTube).toList();
      if (queue.isEmpty) queue.add(t);
      final start = queue.indexWhere((x) => x.id == t.id);
      setState(() { current = t; error = null; });
      await library.addRecent(t);
      await _refreshLibrary();
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF08090D),
        builder: (_) => FractionallySizedBox(
          heightFactor: .92,
          child: YouTubePlayerSheet(queue: queue, initialIndex: start < 0 ? 0 : start),
        ),
      );
      return;
    }
    setState(() { current = t; playerLoading = true; error = null; });
    await initAudioHandler();
    final h = audioHandler;
    if (h == null) {
      if (mounted) setState(() { playerLoading = false; error = 'Player could not start.'; });
      return;
    }

    try {
      final q = sourceQueue ?? results;
      final queue = q.isEmpty ? [t] : q;
      final index = queue.indexWhere((x) => x.id == t.id);
      await h.loadQueue(queue, index < 0 ? 0 : index);
      await h.play();
      await library.addRecent(t);
      await _refreshLibrary();
      if (mounted) setState(() => playerLoading = false);
    } catch (_) {
      if (mounted) setState(() {
        playerLoading = false;
        error = 'Playback failed for this track. Try another song.';
      });
    }
  }

  Future<void> toggleLike(Track t) async {
    await library.toggleLiked(t);
    await _refreshLibrary();
  }

  Future<void> createPlaylist() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Playlist name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await library.createPlaylist(name);
      await _refreshLibrary();
    }
  }

  Future<void> addPlaylist(Track t) async {
    if (playlists.isEmpty) {
      await createPlaylist();
      if (playlists.isEmpty) return;
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF14161E),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add to playlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            ...playlists.map((p) => ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(p),
              onTap: () => Navigator.pop(context, p),
            )),
          ],
        ),
      ),
    );
    if (name != null) await library.addToPlaylist(name, t);
  }

  void openPlayer() {
    final t = current;
    if (t == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF08090D),
      builder: (_) => FullPlayer(
        track: t,
        handler: audioHandler,
        liked: liked.any((x) => x.id == t.id),
        onLike: () => toggleLike(t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(child: _body()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != null) MiniPlayer(
            track: current!,
            handler: audioHandler,
            loading: playerLoading,
            liked: liked.any((x) => x.id == current!.id),
            onOpen: openPlayer,
            onLike: () => toggleLike(current!),
          ),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
              NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Library'),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (tab == 1) return _searchPage();
    if (tab == 2) return _libraryPage();
    return _homePage();
  }

  Widget _homePage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    children: [
      Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: const LinearGradient(colors: [Color(0xFF9B5CFF), Color(0xFF39D9FF)])),
          child: const Icon(Icons.graphic_eq_rounded),
        ),
        const SizedBox(width: 12),
        const Text('NOVAMUSIC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.7)),
      ]),
      const SizedBox(height: 32),
      const Text('Good music.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const Text('Everything you want to play.', style: TextStyle(fontSize: 18, color: Colors.white54)),
      const SizedBox(height: 22),
      _searchBox(),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 28),
        const Text('Recently played', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.take(10).length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final t = recent[i];
              return SizedBox(width: 135, child: GestureDetector(
                onTap: () => play(t, sourceQueue: recent),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  art(t, 135, 135),
                  const SizedBox(height: 7),
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ));
            },
          ),
        ),
      ],
      if (liked.isNotEmpty) ...[
        const SizedBox(height: 25),
        const Text('Liked songs', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...liked.take(5).map(row),
      ],
    ],
  );

  Widget _searchPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    children: [
      const Text('Search', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      _searchBox(),
      if (loading) const Padding(padding: EdgeInsets.only(top: 15), child: LinearProgressIndicator(minHeight: 2)),
      if (!loading && searchController.text.isNotEmpty && results.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 45), child: Center(child: Text('No songs found.', style: TextStyle(color: Colors.white54)))),
      const SizedBox(height: 10),
      ...results.map(row),
    ],
  );

  Widget _libraryPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    children: [
      const Text('Your Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFFF107A3)])), child: const Icon(Icons.favorite_rounded)),
        title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(liked.length.toString() + ' songs'),
        onTap: () => showTracks('Liked Songs', liked),
      ),
      const Divider(),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.add_circle_outline_rounded, size: 38), title: const Text('Create playlist', style: TextStyle(fontWeight: FontWeight.w800)), onTap: createPlaylist),
      ...playlists.map((p) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.queue_music_rounded, size: 34),
        title: Text(p),
        subtitle: FutureBuilder<List<Track>>(future: library.playlist(p), builder: (_, s) => Text((s.data?.length ?? 0).toString() + ' songs')),
        onTap: () async => showTracks(p, await library.playlist(p)),
      )),
      if (playlists.isEmpty && liked.isEmpty) const Padding(padding: EdgeInsets.only(top: 45), child: Center(child: Text('Like songs or create a playlist to build your library.', style: TextStyle(color: Colors.white54)))),
    ],
  );

  Future<void> showTracks(String title, List<Track> tracks) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0F15),
      builder: (_) => SafeArea(child: ListView(
        padding: const EdgeInsets.all(18),
        shrinkWrap: true,
        children: [
          Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (tracks.isEmpty) const Text('No songs yet.', style: TextStyle(color: Colors.white54)),
          ...tracks.map(row),
        ],
      )),
    );
  }

  Widget _searchBox() => TextField(
    controller: searchController,
    onSubmitted: (_) => search(),
    decoration: InputDecoration(
      hintText: 'What do you want to play?',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: IconButton(onPressed: search, icon: const Icon(Icons.arrow_forward_rounded)),
      filled: true,
      fillColor: const Color(0xFF12151D),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 17),
    ),
  );

  Widget row(Track t) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 7),
    minLeadingWidth: 68,
    leading: art(t, 64, 64),
    title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        t.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'play') await play(t);
        if (v == 'like') await toggleLike(t);
        if (v == 'playlist') await addPlaylist(t);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'play', child: Text('Play')),
        PopupMenuItem(value: 'like', child: Text('Like / Unlike')),
        PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
      ],
    ),
    onTap: () => play(t),
  );

  Widget art(Track t, double w, double h) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: w, height: h,
      child: t.artworkUrl == null
        ? const ColoredBox(color: Color(0xFF20232C), child: Icon(Icons.music_note_rounded))
        : CachedNetworkImage(imageUrl: t.artworkUrl!, fit: BoxFit.cover, errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFF20232C), child: Icon(Icons.music_note_rounded))),
    ),
  );
}

class MiniPlayer extends StatelessWidget {
  final Track track;
  final NovaAudioHandler? handler;
  final bool loading;
  final bool liked;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  const MiniPlayer({super.key, required this.track, required this.handler, required this.loading, required this.liked, required this.onOpen, required this.onLike});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF171A22),
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(children: [
          _art(),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ])),
          IconButton(onPressed: onLike, icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded)),
          StreamBuilder<bool>(
            stream: handler?.playbackState.map((s) => s.playing).distinct(),
            initialData: false,
            builder: (_, s) => IconButton(
              onPressed: loading || handler == null ? null : () => s.data == true ? handler!.pause() : handler!.play(),
              icon: Icon(loading ? Icons.hourglass_top_rounded : (s.data == true ? Icons.pause_rounded : Icons.play_arrow_rounded)),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget _art() => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(width: 48, height: 48, child: track.artworkUrl == null ? const ColoredBox(color: Color(0xFF20232C), child: Icon(Icons.music_note)) : CachedNetworkImage(imageUrl: track.artworkUrl!, fit: BoxFit.cover)),
  );
}

class FullPlayer extends StatefulWidget {
  final Track track;
  final NovaAudioHandler? handler;
  final bool liked;
  final VoidCallback onLike;
  const FullPlayer({super.key, required this.track, required this.handler, required this.liked, required this.onLike});
  @override State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  late bool liked;

  @override
  void initState() {
    super.initState();
    liked = widget.liked;
  }

  String time(Duration d) => d.inMinutes.toString() + ':' + d.inSeconds.remainder(60).toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = widget.handler;
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
          const Expanded(child: Text('NOW PLAYING', textAlign: TextAlign.center, style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 12))),
          const SizedBox(width: 48),
        ]),
        const SizedBox(height: 20),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: widget.track.artworkUrl == null ? const ColoredBox(color: Color(0xFF20232C), child: Icon(Icons.music_note_rounded, size: 80)) : CachedNetworkImage(imageUrl: widget.track.artworkUrl!, fit: BoxFit.cover),
        )))),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(widget.track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, color: Colors.white54)),
          ])),
          IconButton(onPressed: () { widget.onLike(); setState(() => liked = !liked); }, icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 29)),
        ]),
        StreamBuilder<Duration>(
          stream: h?.positionStream,
          initialData: Duration.zero,
          builder: (_, p) => StreamBuilder<Duration?>(
            stream: h?.durationStream,
            initialData: widget.track.duration,
            builder: (_, d) {
              final total = d.data ?? widget.track.duration ?? const Duration(seconds: 1);
              final max = total.inMilliseconds.clamp(1, 8640000000);
              final value = (p.data ?? Duration.zero).inMilliseconds.clamp(0, max);
              return Column(children: [
                Slider(value: value.toDouble(), max: max.toDouble(), onChanged: h == null ? null : (v) => h.seek(Duration(milliseconds: v.round()))),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(time(Duration(milliseconds: value))), Text(time(total))]),
              ]);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle_rounded, color: Colors.white70)),
          IconButton(onPressed: h?.skipToPrevious, icon: const Icon(Icons.skip_previous_rounded, size: 40)),
          StreamBuilder<bool>(
            stream: h?.playbackState.map((s) => s.playing).distinct(),
            initialData: false,
            builder: (_, s) => FilledButton(
              style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(20)),
              onPressed: h == null ? null : () => s.data == true ? h.pause() : h.play(),
              child: Icon(s.data == true ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
            ),
          ),
          IconButton(onPressed: h?.skipToNext, icon: const Icon(Icons.skip_next_rounded, size: 40)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.repeat_rounded, color: Colors.white70)),
        ]),
      ]),
    ));
  }
}
