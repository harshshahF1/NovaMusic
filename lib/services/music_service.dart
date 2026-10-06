import '../models/track.dart';
import 'audius_provider.dart';
import 'jamendo_provider.dart';
import 'music_provider.dart';

class MusicService {
  final List<MusicProvider> _providers = [AudiusProvider(), JamendoProvider()];

  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final results = await Future.wait(
      _providers.map((p) => p.search(query).catchError((_) => <Track>[])),
    );
    final merged = results.expand((x) => x).toList();
    final seen = <String>{};
    merged.retainWhere((t) => seen.add('${t.title.toLowerCase()}|${t.artist.toLowerCase()}'));
    return merged;
  }
}
