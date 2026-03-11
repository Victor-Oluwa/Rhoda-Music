import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/audio/audio_handler.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/audio_providers.dart';
import 'presentation/screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final audioHandler = await AudioService.init(
    builder: () => RhodaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.rhoda_music.channel.audio',
      androidNotificationChannelName: 'Rhoda Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Rhoda Music',
          theme: AppTheme.darkTheme,
          home: child,
        );
      },
      child: const HomeScreen(),
    );
  }
}
