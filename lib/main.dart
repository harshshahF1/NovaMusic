import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'services/music_service.dart';
import 'services/player_service.dart';
import 'screens/home_screen.dart';

NovaAudioHandler? audioHandler;
final musicService = MusicService();

Future<void> initAudioHandler() async {
  if (audioHandler != null) return;
  try {
    audioHandler = await AudioService.init(
      builder: () => NovaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.harshshah.novamusic.playback',
        androidNotificationChannelName: 'NovaMusic playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    // Keep the main UI available even if Android media-service initialization fails.
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
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}
