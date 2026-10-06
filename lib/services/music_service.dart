import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

class MusicService {
  static const _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');

  Future<List<Track>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    if (_apiKey.isEmpty) {
      throw StateError('YouTube search is not configured. Add YOUTUBE_API_KEY to the app build.');
    }

    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'q': q,
      'type': 'video',
      'videoEmbeddable': 'true',
      'videoSyndicated': 'true',
      'maxResults': '25',
      'regionCode': 'IN',
      'relevanceLanguage': 'en',
      'key': _apiKey,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('YouTube search failed (${res.statusCode})');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>? ?? []);
    final results = <Track>[];

    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final id = (item['id'] as Map<String, dynamic>?)?['videoId']?.toString();
      final snippet = item['snippet'] as Map<String, dynamic>?;
      if (id == null || snippet == null) continue;

      final title = _clean(snippet['title']?.toString() ?? '');
      final artist = _clean(snippet['channelTitle']?.toString() ?? '');
      if (title.isEmpty || artist.isEmpty) continue;

      final thumbs = snippet['thumbnails'] as Map<String, dynamic>?;
      final maxres = thumbs?['maxres'] as Map<String, dynamic>?;
      final high = thumbs?['high'] as Map<String, dynamic>?;
      final medium = thumbs?['medium'] as Map<String, dynamic>?;
      final artwork = (maxres?['url'] ?? high?['url'] ?? medium?['url'])?.toString();

      results.add(Track(
        id: 'yt_$id',
        title: title,
        artist: artist,
        album: 'YouTube',
        artworkUrl: artwork,
        streamUrl: '',
        source: 'youtube',
        youtubeVideoId: id,
      ));
    }
    return results;
  }

  String _clean(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .trim();
}
