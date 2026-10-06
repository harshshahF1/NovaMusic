import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'music_provider.dart';

class AudiusProvider implements MusicProvider {
  static const _base = 'https://api.audius.co';
  static const _appName = 'NovaMusic';

  @override
  String get name => 'audius';

  @override
  Future<List<Track>> search(String query) async {
    final uri = Uri.parse('$_base/v1/tracks/search').replace(queryParameters: {
      'query': query, 'app_name': _appName, 'limit': '50', 'offset': '0',
    });
    final response = await http.get(uri, headers: {
      'Accept': 'application/json', 'User-Agent': 'NovaMusic/1.0',
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    final q = query.toLowerCase().trim();
    final tracks = <Track>[];

    for (final raw in data) {
      final t = raw as Map<String, dynamic>;
      final genre = t['genre']?.toString().toLowerCase().trim() ?? '';
      final type = t['track_type']?.toString().toLowerCase().trim() ?? 'track';

      if (type != 'track') continue;
      if ({'podcast','podcasts','spoken word','spoken-word','audiobook','audiobooks','talk','talk radio'}.contains(genre)) continue;

      final id = t['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final artwork = t['artwork'] is Map
          ? (t['artwork']['1000x1000'] ?? t['artwork']['480x480'] ?? t['artwork']['150x150'])
          : null;
      final seconds = (t['duration'] as num?)?.toInt();

      tracks.add(Track(
        id: 'audius_$id',
        title: t['title']?.toString() ?? 'Untitled',
        artist: (t['user'] as Map?)?['name']?.toString() ?? 'Unknown artist',
        album: t['genre']?.toString(),
        artworkUrl: artwork?.toString(),
        streamUrl: '$_base/v1/tracks/$id/stream?app_name=$_appName',
        duration: seconds == null ? null : Duration(seconds: seconds),
        source: name,
      ));
    }

    int score(Track t) {
      final title = t.title.toLowerCase();
      final artist = t.artist.toLowerCase();
      if (title == q) return 0;
      if (title.startsWith(q)) return 1;
      if (title.contains(q)) return 2;
      if (artist.contains(q)) return 4;
      return 5;
    }
    tracks.sort((a, b) => score(a).compareTo(score(b)));
    return tracks;
  }
}
