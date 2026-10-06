import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'music_provider.dart';

class JamendoProvider implements MusicProvider {
  @override
  String get name => 'jamendo';

  static const _blocked = <String>{
    'podcast', 'podcasts', 'spoken word', 'spoken-word', 'audiobook',
    'audiobooks', 'talk', 'talk radio', 'kids', 'kid', 'children',
    'child', 'nursery', 'cartoon', 'lullaby', 'school', 'learning',
    'education', 'story', 'stories', 'bedtime', 'fairy tale',
    'playlist', 'compilation', 'mix', 'radio', 'interview',
  };

  bool _valid(Track t, String query) {
    final title = t.title.trim();
    final artist = t.artist.trim();
    final album = t.album?.trim() ?? '';
    if (title.isEmpty || artist.isEmpty || title.toLowerCase() == 'untitled') return false;
    if (artist.toLowerCase() == 'unknown artist' || artist.toLowerCase() == 'unknown') return false;
    if (t.streamUrl.trim().isEmpty || !t.streamUrl.startsWith('http')) return false;
    final content = '$title $artist $album'.toLowerCase();
    if (_blocked.any((word) => RegExp(r'(^|[^a-z])' + RegExp.escape(word) + r'([^a-z]|$)').hasMatch(content))) return false;
    final tokens = query.toLowerCase().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final titleArtist = '$title $artist'.toLowerCase();
    return tokens.every(titleArtist.contains);
  }

  @override
  Future<List<Track>> search(String query) async {
    const clientId = String.fromEnvironment('JAMENDO_CLIENT_ID');
    if (clientId.isEmpty) return [];
    final uri = Uri.parse('https://api.jamendo.com/v3.0/tracks/').replace(queryParameters: {
      'client_id': clientId, 'format': 'json', 'namesearch': query, 'limit': '50', 'audioformat': 'mp32',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['results'] as List?) ?? const [];
    final tracks = data.map((raw) {
      final t = raw as Map<String, dynamic>;
      return Track(
        id: 'jamendo_${t['id']}',
        title: '${t['name'] ?? ''}',
        artist: '${t['artist_name'] ?? ''}',
        album: t['album_name']?.toString(),
        artworkUrl: t['album_image']?.toString(),
        streamUrl: '${t['audio'] ?? ''}',
        duration: (t['duration'] as num?) == null ? null : Duration(seconds: (t['duration'] as num).toInt()),
        source: name,
      );
    }).where((t) => _valid(t, query)).toList();
    return tracks;
  }
}