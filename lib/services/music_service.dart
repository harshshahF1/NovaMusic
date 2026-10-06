import '../models/track.dart';
import 'audius_provider.dart';
import 'jamendo_provider.dart';
import 'music_provider.dart';

class MusicService {
  final List<MusicProvider> _providers = [AudiusProvider(), JamendoProvider()];

  static const _blocked = <String>{
    'podcast', 'podcasts', 'spoken word', 'spoken-word', 'audiobook',
    'audiobooks', 'talk', 'talk radio', 'kids', 'kid', 'children',
    'child', 'nursery', 'cartoon', 'lullaby', 'school', 'learning',
    'education', 'story', 'stories', 'bedtime', 'fairy tale',
    'playlist', 'compilation', 'mix', 'radio', 'interview',
  };

  bool _isSong(Track t, String q) {
    final title = t.title.trim();
    final artist = t.artist.trim();
    final album = t.album?.trim() ?? '';
    if (title.isEmpty || artist.isEmpty || title.toLowerCase() == 'untitled') return false;
    if (artist.toLowerCase() == 'unknown artist' || artist.toLowerCase() == 'unknown') return false;
    if (t.streamUrl.trim().isEmpty || !t.streamUrl.startsWith('http')) return false;
    final content = '$title $artist $album'.toLowerCase();
    if (_blocked.any((word) => RegExp(r'(^|[^a-z])' + RegExp.escape(word) + r'([^a-z]|$)').hasMatch(content))) return false;
    final tokens = q.toLowerCase().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final titleArtist = '$title $artist'.toLowerCase();
    if (!tokens.every(titleArtist.contains)) return false;
    final suspiciousArtist = RegExp(r'^(user|unknown|anonymous|various artists?|va|soundcloud|official audio|official music|music channel|channel)\s*[-_:#]?\s*\d*$', caseSensitive: false);
    if (suspiciousArtist.hasMatch(artist)) return false;
    return true;
  }

  Future<List<Track>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final results = await Future.wait(_providers.map((p) => p.search(q).catchError((_) => <Track>[])));
    final merged = results.expand((x) => x).where((t) => _isSong(t, q)).toList();
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
      if (artist == lower) return 3;
      if (artist.startsWith(lower)) return 4;
      return 5;
    }
    merged.sort((a, b) {
      final s = score(a).compareTo(score(b));
      return s != 0 ? s : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return merged;
  }
}