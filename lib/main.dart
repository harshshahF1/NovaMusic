import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'services/music_service.dart';
import 'services/player_service.dart';
import 'screens/home_screen.dart';

late final NovaAudioHandler audioHandler;
final musicService = MusicService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => NovaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.harshshah.novamusic.playback',
      androidNotificationChannelName: 'NovaMusic playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const NovaMusicApp());
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
