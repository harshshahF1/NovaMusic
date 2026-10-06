import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'services/music_service.dart';
import 'services/player_service.dart';
import 'screens/home_screen.dart';

NovaAudioHandler? audioHandler;
final musicService = MusicService();

Future<void>? _audioInit;

Future<void> initAudioHandler() {
  if (audioHandler != null) return Future.value();
  return _audioInit ??= _createAudioHandler();
}

Future<void> _createAudioHandler() async {
  try {
    audioHandler = await AudioService.init(
      builder: () => NovaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.harshshah.novamusic.playback',
        androidNotificationChannelName: 'NovaMusic playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidResumeOnClick: true,
      ),
    );
  } catch (_) {
    audioHandler = null;
    _audioInit = null;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovaMusicApp());
  initAudioHandler();
}

class NovaMusicApp extends StatelessWidget {
  const NovaMusicApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'NovaMusic',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF08090D),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9B5CFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}
