import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class LibraryService {
  static const likedKey = 'nova_liked';
  static const recentKey = 'nova_recent';
  static const playlistsKey = 'nova_playlists';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Map<String, dynamic> _map(Track t) => {
    'id': t.id,
    'title': t.title,
    'artist': t.artist,
    'album': t.album,
    'artworkUrl': t.artworkUrl,
    'streamUrl': t.streamUrl,
    'duration': t.duration?.inSeconds,
    'source': t.source,
    'youtubeVideoId': t.youtubeVideoId,
  };

  Track _track(Map<String, dynamic> m) => Track(
    id: m['id']?.toString() ?? '',
    title: m['title']?.toString() ?? '',
    artist: m['artist']?.toString() ?? '',
    album: m['album']?.toString(),
    artworkUrl: m['artworkUrl']?.toString(),
    streamUrl: m['streamUrl']?.toString() ?? '',
    duration: m['duration'] == null ? null : Duration(seconds: (m['duration'] as num).toInt()),
    source: m['source']?.toString() ?? 'audius',
    youtubeVideoId: m['youtubeVideoId']?.toString(),
  );

  Future<List<Track>> _read(String key) async {
    final p = await _prefs;
    return (p.getStringList(key) ?? []).map((x) {
      try {
        return _track(jsonDecode(x) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<Track>().toList();
  }

  Future<void> _write(String key, List<Track> tracks) async {
    final p = await _prefs;
    await p.setStringList(key, tracks.map((t) => jsonEncode(_map(t))).toList());
  }

  Future<List<Track>> liked() => _read(likedKey);

  Future<void> toggleLiked(Track t) async {
    final list = await liked();
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.insert(0, t);
    }
    await _write(likedKey, list);
  }

  Future<List<Track>> recent() => _read(recentKey);

  Future<void> addRecent(Track t) async {
    final list = await recent();
    list.removeWhere((x) => x.id == t.id);
    list.insert(0, t);
    if (list.length > 50) list.removeRange(50, list.length);
    await _write(recentKey, list);
  }

  Future<List<String>> playlistNames() async {
    final p = await _prefs;
    return p.getStringList(playlistsKey) ?? [];
  }

  Future<void> createPlaylist(String name) async {
    final p = await _prefs;
    final names = await playlistNames();
    if (!names.contains(name)) {
      names.add(name);
      await p.setStringList(playlistsKey, names);
    }
  }

  Future<List<Track>> playlist(String name) => _read('nova_playlist_' + name);

  Future<void> addToPlaylist(String name, Track t) async {
    final list = await playlist(name);
    if (!list.any((x) => x.id == t.id)) list.insert(0, t);
    await _write('nova_playlist_' + name, list);
  }
}
