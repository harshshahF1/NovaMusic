import '../models/track.dart';
import 'audius_provider.dart';
import 'jamendo_provider.dart';
import 'music_provider.dart';

class MusicService {
  final List<MusicProvider> _providers = [AudiusProvider(), JamendoProvider()];

  Future<List<Track>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final results = await Future.wait(
      _providers.map((p) => p.search(q).catchError((_) => <Track>[])),
    );
    final merged = results.expand((x) => x).toList();
    final seen = <String>{};

    merged.retainWhere((t) {
      final key = t.title.trim().toLowerCase() + '|' + t.artist.trim().toLowerCase();
      return seen.add(key);
    });

    final lower = q.toLowerCase();
    int score(Track t) {
      final title = t.title.toLowerCase();
      final artist = t.artist.toLowerCase();
      if (title == lower) return 0;
      if (title.startsWith(lower)) return 1;
      if (title.contains(lower)) return 2;
      if (artist.contains(lower)) return 4;
      return 5;
    }
    merged.sort((a, b) => score(a).compareTo(score(b)));
    return merged;
  }
}
