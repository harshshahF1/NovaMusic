import '../models/track.dart';

abstract class MusicProvider {
  String get name;
  Future<List<Track>> search(String query);
}
