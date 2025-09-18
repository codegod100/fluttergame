import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/cute_platformer_game.dart';
import 'game/hud.dart';

const _systemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Color(0xFFEDF2FB),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Colors.transparent,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(_systemUiOverlayStyle);
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
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemUiOverlayStyle,
        child: Scaffold(
          backgroundColor: const Color(0xFFEDF2FB),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final horizontalPadding = constraints.maxWidth > 720 ? 32.0 : 16.0;
              final verticalPadding = constraints.maxHeight > 640 ? 24.0 : 12.0;

              final gameView = GameWidget<CutePlatformerGame>(
                game: game,
                overlayBuilderMap: {
                  'hud': (context, game) => CuteHud(game: game),
                },
                initialActiveOverlays: const ['hud'],
                backgroundBuilder: (context) =>
                    Container(color: const Color(0xFFEDF2FB)),
              );

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: gameView,
                        ),
                      ),
                      SizedBox(height: isLandscape ? 12 : 20),
                      SizedBox(
                        width: double.infinity,
                        child: CuteControlsPanel(game: game),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
