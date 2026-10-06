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
      'query': query,
      'app_name': _appName,
      'limit': '25',
      'offset': '0',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.map((raw) {
      final t = raw as Map<String, dynamic>;
      final id = '${t['id'] ?? ''}';
      final artwork = (t['artwork'] is Map)
          ? (t['artwork']['1000x1000'] ?? t['artwork']['480x480'] ?? t['artwork']['150x150'])
          : null;
      final seconds = (t['duration'] as num?)?.toInt();
      return Track(
        id: 'audius_$id',
        title: '${t['title'] ?? 'Untitled'}',
        artist: '${(t['user'] as Map?)?['name'] ?? 'Unknown artist'}',
        album: t['genre']?.toString(),
        artworkUrl: artwork?.toString(),
        streamUrl: '$_base/v1/tracks/$id/stream?app_name=$_appName',
        duration: seconds == null ? null : Duration(seconds: seconds),
        source: name,
      );
    }).where((t) => t.streamUrl.isNotEmpty).toList();
  }
}
