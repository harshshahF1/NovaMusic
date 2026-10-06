class Track {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String streamUrl;
  final Duration? duration;
  final String source;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    required this.source,
    this.album,
    this.artworkUrl,
    this.duration,
  });
}
