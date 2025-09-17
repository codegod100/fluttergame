import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/cute_platformer_game.dart';
import 'game/hud.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final game = CutePlatformerGame();
  runApp(_CutePlatformerApp(game: game));
}

class _CutePlatformerApp extends StatelessWidget {
  const _CutePlatformerApp({required this.game});

  final CutePlatformerGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Cute Platformer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8ECAE6)),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFEDF2FB),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 720 ? 32.0 : 0.0;
            final verticalPadding = constraints.maxHeight > 640 ? 24.0 : 0.0;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: GameWidget<CutePlatformerGame>(
                game: game,
                overlayBuilderMap: {
                  'hud': (context, game) => CuteHud(game: game),
                },
                initialActiveOverlays: const ['hud'],
              ),
            );
          },
        ),
      ),
    );
  }
}
