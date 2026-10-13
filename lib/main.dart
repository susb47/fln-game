import 'dart:async';

import 'package:flutter/material.dart';

import 'audio/audio_manager.dart';
import 'audio/audio_settings.dart';
import 'brand.dart';
import 'data/cast.dart';
import 'data/content.dart';
import 'game_scope.dart';
import 'logic/profile_store.dart';
import 'screens/auth_screen.dart';
import 'screens/map_screen.dart';
import 'screens/placement_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final content = await Content.load();
  final store = await ProfileStore.load();
  final cast = await Cast.load();
  final audio = AudioManager.device(await AudioSettings.load(), clips: cast.clips);
  unawaited(audio.checkVoice()); // Finds a Bangla voice before the first line is spoken.
  runApp(FlnApp(content: content, store: store, cast: cast, audio: audio));
}

class FlnApp extends StatelessWidget {
  final Content content;
  final ProfileStore store;
  final Cast? cast;
  final AudioManager? audio;

  const FlnApp({super.key, required this.content, required this.store, this.cast, this.audio});

  @override
  Widget build(BuildContext context) {
    return GameScope(
      content: content,
      store: store,
      cast: cast,
      audio: audio,
      child: MaterialApp(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1D3557),
          fontFamily: 'NotoSansBengali',
          // Solid colours everywhere, so no screen can show black through it.
          scaffoldBackgroundColor: const Color(0xFFBDE0FE),
          canvasColor: Colors.white,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
                backgroundColor: Color(0xFFBDE0FE),
              ),
            },
          ),
        ),
        // Who is playing decides the first screen.
        home: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final player = store.current;
            if (player == null) return const AuthScreen();
            if (!player.placementDone) return PlacementScreen(key: ValueKey(player.id));
            return MapScreen(key: ValueKey(player.id));
          },
        ),
      ),
    );
  }
}
