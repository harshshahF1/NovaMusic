import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'music_provider.dart';

class JamendoProvider implements MusicProvider {
  @override
  String get name => 'jamendo';

  @override
  Future<List<Track>> search(String query) async {
    const clientId = String.fromEnvironment('JAMENDO_CLIENT_ID');
    if (clientId.isEmpty) return [];
    final uri = Uri.parse('https://api.jamendo.com/v3.0/tracks/').replace(queryParameters: {
      'client_id': clientId,
      'format': 'json',
      'namesearch': query,
      'limit': '25',
      'audioformat': 'mp32',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['results'] as List?) ?? const [];
    return data.map((raw) {
      final t = raw as Map<String, dynamic>;
      return Track(
        id: 'jamendo_${t['id']}',
        title: '${t['name'] ?? 'Untitled'}',
        artist: '${t['artist_name'] ?? 'Unknown artist'}',
        album: t['album_name']?.toString(),
        artworkUrl: t['album_image']?.toString(),
        streamUrl: '${t['audio'] ?? ''}',
        duration: (t['duration'] as num?) == null ? null : Duration(seconds: (t['duration'] as num).toInt()),
        source: name,
      );
    }).where((t) => t.streamUrl.isNotEmpty).toList();
  }
}
