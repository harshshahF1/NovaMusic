import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

class NovaAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  NovaAudioHandler() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _processingState(event.processingState),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });

    _player.currentIndexStream.listen((index) {
      final i = index ?? 0;
      if (i >= 0 && i < queue.value.length) {
        mediaItem.add(queue.value[i]);
      }
    });
  }

  AudioProcessingState _processingState(ProcessingState s) => switch (s) {
    ProcessingState.idle => AudioProcessingState.idle,
    ProcessingState.loading => AudioProcessingState.loading,
    ProcessingState.buffering => AudioProcessingState.buffering,
    ProcessingState.ready => AudioProcessingState.ready,
    ProcessingState.completed => AudioProcessingState.completed,
  };

  Future<void> loadQueue(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;

    final items = tracks.map((track) => MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      artUri: track.artworkUrl == null ? null : Uri.tryParse(track.artworkUrl!),
      duration: track.duration,
    )).toList();

    queue.add(items);

    final sources = <AudioSource>[];
    for (var i = 0; i < tracks.length; i++) {
      sources.add(AudioSource.uri(
        Uri.parse(tracks[i].streamUrl),
        tag: items[i],
      ));
    }

    await _player.setAudioSources(
      sources,
      initialIndex: startIndex.clamp(0, sources.length - 1),
      initialPosition: Duration.zero,
    );
    mediaItem.add(items[startIndex.clamp(0, items.length - 1)]);
  }

  Future<void> load(Track track) => loadQueue([track], 0);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      await _player.play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      await _player.play();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> onTaskRemoved() async {}

  bool get playing => _player.playing;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
}
