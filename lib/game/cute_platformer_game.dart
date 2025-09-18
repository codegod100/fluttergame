import 'dart:async';
import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LevelDefinition {
  const LevelDefinition({
    required this.size,
    required this.playerSpawn,
    required this.platforms,
    required this.starPlacements,
    this.floatingFriends = const <FloatingFriendSpec>[],
    this.baddies = const <BaddieSpec>[],
    this.coinPlacements = const <CoinPlacement>[],
    this.tunnels = const <TunnelSpec>[],
  });

  final Vector2 size;
  final Vector2 playerSpawn;
  final List<PlatformSpec> platforms;
  final List<StarPlacement> starPlacements;
  final List<FloatingFriendSpec> floatingFriends;
  final List<BaddieSpec> baddies;
  final List<CoinPlacement> coinPlacements;
  final List<TunnelSpec> tunnels;
}

class PlatformSpec {
  const PlatformSpec({
    required this.position,
    required this.size,
    required this.color,
    this.priority,
  });

  final Vector2 position;
  final Vector2 size;
  final Color color;
  final int? priority;
}

class FloatingFriendSpec {
  const FloatingFriendSpec({
    required this.position,
    required this.color,
    required this.amplitude,
    required this.speed,
  });

  final Vector2 position;
  final Color color;
  final double amplitude;
  final double speed;
}

class BaddieSpec {
  const BaddieSpec._internal({
    this.position,
    this.platformIndex,
    this.horizontalFraction,
    required this.patrolDistance,
    required this.speed,
    required this.color,
    required this.startMovingRight,
  }) : assert(
          patrolDistance >= 0,
          'patrolDistance must be non-negative',
        ),
        assert(
          horizontalFraction == null ||
              (horizontalFraction >= 0 && horizontalFraction <= 1),
          'horizontalFraction must be between 0 and 1',
        );

  const BaddieSpec.absolute({
    required Vector2 position,
    double patrolDistance = 120,
    double speed = 70,
    Color color = const Color(0xFFFFB4A2),
    bool startMovingRight = true,
  }) : this._internal(
          position: position,
          patrolDistance: patrolDistance,
          speed: speed,
          color: color,
          startMovingRight: startMovingRight,
        );

  const BaddieSpec.onPlatform(
    int platformIndex, {
    double horizontalFraction = 0.5,
    double patrolDistance = 120,
    double speed = 70,
    Color color = const Color(0xFFFFB4A2),
    bool startMovingRight = true,
  }) : this._internal(
          platformIndex: platformIndex,
          horizontalFraction: horizontalFraction,
          patrolDistance: patrolDistance,
          speed: speed,
          color: color,
          startMovingRight: startMovingRight,
        );

  final Vector2? position;
  final int? platformIndex;
  final double? horizontalFraction;
  final double patrolDistance;
  final double speed;
  final Color color;
  final bool startMovingRight;

  Vector2 resolvePosition(
    List<PlatformSpec> platforms,
    Vector2 levelSize,
  ) {
    if (position != null) {
      final resolved = position!.clone();
      resolved.x = resolved.x
          .clamp(0, levelSize.x - Baddie.bodyWidth)
          .toDouble();
      resolved.y = resolved.y
          .clamp(0, levelSize.y - Baddie.bodyHeight)
          .toDouble();
      return resolved;
    }

    assert(
      platformIndex != null &&
          platformIndex! >= 0 &&
          platformIndex! < platforms.length,
      'Baddie spec references an invalid platform index.',
    );
    final platform = platforms[platformIndex!];
    final centerX = platform.position.x +
        platform.size.x * (horizontalFraction ?? 0.5);
    final x = (centerX - Baddie.bodyWidth / 2)
        .clamp(0, levelSize.x - Baddie.bodyWidth)
        .toDouble();
    final y = (platform.position.y - Baddie.bodyHeight)
        .clamp(0, levelSize.y - Baddie.bodyHeight)
        .toDouble();
    return Vector2(x, y);
  }
}

class CameraTarget extends PositionComponent {
  CameraTarget(this._player)
      : super(
          position: Vector2(
            _player.position.x + _player.size.x / 2,
            _player.position.y + _player.size.y / 2,
          ),
          size: Vector2.zero(),
        );

  final Player _player;

  Vector2 _playerCenter() => Vector2(
        _player.position.x + _player.size.x / 2,
        _player.position.y + _player.size.y / 2,
      );

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(_playerCenter());
  }
}

class StarPlacement {
  const StarPlacement._internal({
    this.position,
    this.platformIndex,
    this.horizontalFraction = 0.5,
    this.heightOffset = 70,
  }) : assert(
          horizontalFraction >= 0 && horizontalFraction <= 1,
          'horizontalFraction must be between 0 and 1',
        );

  const StarPlacement.absolute(Vector2 position)
      : this._internal(position: position);

  const StarPlacement.abovePlatform(
    int platformIndex, {
    double horizontalFraction = 0.5,
    double heightOffset = 70,
  }) : this._internal(
          platformIndex: platformIndex,
          horizontalFraction: horizontalFraction,
          heightOffset: heightOffset,
        );

  final Vector2? position;
  final int? platformIndex;
  final double horizontalFraction;
  final double heightOffset;

  Vector2 resolve(List<PlatformSpec> platforms, Vector2 levelSize) {
    if (position != null) {
      final resolved = position!.clone();
      final halfSize = 15.0;
      resolved.x = resolved.x
          .clamp(halfSize, levelSize.x - halfSize)
          .toDouble();
      resolved.y = resolved.y
          .clamp(halfSize, levelSize.y - halfSize)
          .toDouble();
      return resolved;
    }
    assert(
      platformIndex != null &&
          platformIndex! >= 0 &&
          platformIndex! < platforms.length,
      'Star placement references an invalid platform index.',
    );
    final platform = platforms[platformIndex!];
    final x = platform.position.x + platform.size.x * horizontalFraction;
    final y = platform.position.y - heightOffset;
    final halfSize = 15.0;
    return Vector2(
      x.clamp(halfSize, levelSize.x - halfSize).toDouble(),
      y.clamp(halfSize, levelSize.y - halfSize).toDouble(),
    );
  }
}

class CoinPlacement {
  const CoinPlacement._internal({
    this.position,
    this.platformIndex,
    this.horizontalFraction = 0.5,
    this.heightOffset = 50,
  }) : assert(
          horizontalFraction >= 0 && horizontalFraction <= 1,
          'horizontalFraction must be between 0 and 1',
        );

  const CoinPlacement.absolute(Vector2 position)
      : this._internal(position: position);

  const CoinPlacement.abovePlatform(
    int platformIndex, {
    double horizontalFraction = 0.5,
    double heightOffset = 50,
  }) : this._internal(
          platformIndex: platformIndex,
          horizontalFraction: horizontalFraction,
          heightOffset: heightOffset,
        );

  final Vector2? position;
  final int? platformIndex;
  final double horizontalFraction;
  final double heightOffset;

  Vector2 resolve(List<PlatformSpec> platforms, Vector2 levelSize) {
    if (position != null) {
      final resolved = position!.clone();
      const halfSize = 12.0;
      resolved.x = resolved.x
          .clamp(halfSize, levelSize.x - halfSize)
          .toDouble();
      resolved.y = resolved.y
          .clamp(halfSize, levelSize.y - halfSize)
          .toDouble();
      return resolved;
    }
    assert(
      platformIndex != null &&
          platformIndex! >= 0 &&
          platformIndex! < platforms.length,
      'Coin placement references an invalid platform index.',
    );
    final platform = platforms[platformIndex!];
    final x = platform.position.x + platform.size.x * horizontalFraction;
    final y = platform.position.y - heightOffset;
    const halfSize = 12.0;
    return Vector2(
      x.clamp(halfSize, levelSize.x - halfSize).toDouble(),
      y.clamp(halfSize, levelSize.y - halfSize).toDouble(),
    );
  }
}

class TunnelSpec {
  const TunnelSpec({
    required this.position,
    required this.size,
    required this.exitSpawn,
    this.color = const Color(0xFF6BD425),
    this.entryInset = const EdgeInsets.fromLTRB(12, 14, 12, 6),
    this.cooldownSeconds = 0.6,
    this.label,
    this.linkId,
    this.rememberEntryPosition = false,
    this.returnToRememberedEntry = false,
  });

  final Vector2 position;
  final Vector2 size;
  final Vector2 exitSpawn;
  final Color color;
  final EdgeInsets entryInset;
  final double cooldownSeconds;
  final String? label;
  final String? linkId;
  final bool rememberEntryPosition;
  final bool returnToRememberedEntry;
}

class CutePlatformerGame extends FlameGame with KeyboardEvents {
  static const double _viewportWidth = 800;
  static const double _viewportHeight = 480;
  static const int _initialLives = 3;

  CutePlatformerGame()
      : score = ValueNotifier<int>(0),
        coins = ValueNotifier<int>(0),
        lives = ValueNotifier<int>(_initialLives),
        gravity = Vector2(0, 900);

  final ValueNotifier<int> score;
  final ValueNotifier<int> coins;
  final ValueNotifier<int> lives;
  final Vector2 gravity;

  late final Player _player;
  final List<PlatformBlock> _platforms = [];
  final List<FloatingFriend> _floatingFriends = [];
  final List<Baddie> _baddies = [];
  final List<Coin> _coins = [];
  final List<TunnelPipe> _tunnels = [];
  List<Vector2> _starSpawns = [];
  List<Vector2> _coinSpawns = [];
  late Rect _levelBounds;
  PastelBackground? _background;
  int _currentLevelIndex = 0;
  bool _playerAdded = false;
  bool _levelTransitionPending = false;
  CameraTarget? _cameraTarget;
  final Map<String, Vector2> _storedTunnelEntries = {};

  final List<LevelDefinition> _levels = [
    LevelDefinition(
      size: Vector2(1600, 1200),
      playerSpawn: Vector2(100, 480),
      platforms: [
        PlatformSpec(
          position: Vector2(0, 544),
          size: Vector2(1600, 56),
          color: const Color(0xFFBEE3DB),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(140, 420),
          size: Vector2(150, 32),
          color: const Color(0xFFF0A6CA),
        ),
        PlatformSpec(
          position: Vector2(430, 300),
          size: Vector2(160, 28),
          color: const Color(0xFF9AD0EC),
        ),
        PlatformSpec(
          position: Vector2(680, 390),
          size: Vector2(220, 30),
          color: const Color(0xFFFFD6BA),
        ),
        PlatformSpec(
          position: Vector2(960, 280),
          size: Vector2(180, 28),
          color: const Color(0xFFCAFFBF),
        ),
        PlatformSpec(
          position: Vector2(1230, 380),
          size: Vector2(200, 32),
          color: const Color(0xFFFDE2E4),
        ),
        PlatformSpec(
          position: Vector2(80, 1040),
          size: Vector2(1520, 40),
          color: const Color(0xFFB6E2D3),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(360, 920),
          size: Vector2(240, 26),
          color: const Color(0xFFA0C4FF),
        ),
        PlatformSpec(
          position: Vector2(720, 880),
          size: Vector2(220, 24),
          color: const Color(0xFFFFD6BA),
        ),
        PlatformSpec(
          position: Vector2(1000, 960),
          size: Vector2(220, 28),
          color: const Color(0xFFFDE2E4),
        ),
      ],
      starPlacements: const [
        StarPlacement.abovePlatform(1, horizontalFraction: 0.4, heightOffset: 80),
        StarPlacement.abovePlatform(2, horizontalFraction: 0.6, heightOffset: 80),
        StarPlacement.abovePlatform(3, horizontalFraction: 0.45, heightOffset: 80),
        StarPlacement.abovePlatform(4, horizontalFraction: 0.55, heightOffset: 90),
        StarPlacement.abovePlatform(5, horizontalFraction: 0.7, heightOffset: 80),
      ],
      floatingFriends: [
        FloatingFriendSpec(
          position: Vector2(360, 490),
          color: const Color(0xFF8EECF5),
          amplitude: 8,
          speed: 1.2,
        ),
        FloatingFriendSpec(
          position: Vector2(880, 450),
          color: const Color(0xFFFFE3E3),
          amplitude: 10,
          speed: 0.8,
        ),
        FloatingFriendSpec(
          position: Vector2(980, 900),
          color: const Color(0xFFFFF1E6),
          amplitude: 12,
          speed: 1.1,
        ),
      ],
      baddies: const [
        BaddieSpec.onPlatform(
          1,
          horizontalFraction: 0.6,
          patrolDistance: 120,
          speed: 70,
          color: Color(0xFFFFB4A2),
        ),
        BaddieSpec.onPlatform(
          3,
          horizontalFraction: 0.4,
          patrolDistance: 150,
          speed: 80,
          color: Color(0xFFFF99AC),
          startMovingRight: false,
        ),
      ],
      coinPlacements: [
        CoinPlacement.absolute(Vector2(380, 880)),
        CoinPlacement.absolute(Vector2(430, 838)),
        CoinPlacement.absolute(Vector2(480, 880)),
        CoinPlacement.absolute(Vector2(720, 842)),
        CoinPlacement.absolute(Vector2(780, 802)),
        CoinPlacement.absolute(Vector2(840, 842)),
      ],
      tunnels: [
        TunnelSpec(
          position: Vector2(380, 424),
          size: Vector2(112, 120),
          exitSpawn: Vector2(404, 988),
          label: 'Underground bonus!',
          linkId: 'level1-main',
          rememberEntryPosition: true,
        ),
        TunnelSpec(
          position: Vector2(1360, 922),
          size: Vector2(96, 118),
          exitSpawn: Vector2(1382, 492),
          color: const Color(0xFF64DFDF),
          entryInset: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          label: 'Back to daylight!',
          linkId: 'level1-main',
          returnToRememberedEntry: true,
        ),
      ],
    ),
    LevelDefinition(
      size: Vector2(1800, 1200),
      playerSpawn: Vector2(140, 500),
      platforms: [
        PlatformSpec(
          position: Vector2(0, 584),
          size: Vector2(1800, 56),
          color: const Color(0xFFF4F1DE),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(220, 500),
          size: Vector2(220, 30),
          color: const Color(0xFFFFC8DD),
        ),
        PlatformSpec(
          position: Vector2(520, 380),
          size: Vector2(200, 28),
          color: const Color(0xFFA0C4FF),
        ),
        PlatformSpec(
          position: Vector2(820, 380),
          size: Vector2(220, 28),
          color: const Color(0xFFBDE0FE),
        ),
        PlatformSpec(
          position: Vector2(1100, 320),
          size: Vector2(220, 30),
          color: const Color(0xFFCDB4DB),
        ),
        PlatformSpec(
          position: Vector2(1420, 260),
          size: Vector2(220, 30),
          color: const Color(0xFFFFF1E6),
        ),
        PlatformSpec(
          position: Vector2(1620, 430),
          size: Vector2(160, 28),
          color: const Color(0xFFB9FBC0),
        ),
        PlatformSpec(
          position: Vector2(240, 1040),
          size: Vector2(1320, 44),
          color: const Color(0xFFE0FBFC),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(520, 920),
          size: Vector2(240, 28),
          color: const Color(0xFF98F5E1),
        ),
        PlatformSpec(
          position: Vector2(980, 880),
          size: Vector2(220, 28),
          color: const Color(0xFFFFD6FF),
        ),
      ],
      starPlacements: const [
        StarPlacement.abovePlatform(1, horizontalFraction: 0.5, heightOffset: 80),
        StarPlacement.abovePlatform(2, horizontalFraction: 0.65, heightOffset: 80),
        StarPlacement.abovePlatform(3, horizontalFraction: 0.35, heightOffset: 80),
        StarPlacement.abovePlatform(4, horizontalFraction: 0.7, heightOffset: 85),
        StarPlacement.abovePlatform(5, horizontalFraction: 0.5, heightOffset: 90),
        StarPlacement.abovePlatform(6, horizontalFraction: 0.5, heightOffset: 80),
      ],
      floatingFriends: [
        FloatingFriendSpec(
          position: Vector2(460, 520),
          color: const Color(0xFFFAE1DD),
          amplitude: 12,
          speed: 1.0,
        ),
        FloatingFriendSpec(
          position: Vector2(1040, 420),
          color: const Color(0xFFCCD5AE),
          amplitude: 14,
          speed: 1.1,
        ),
        FloatingFriendSpec(
          position: Vector2(1520, 360),
          color: const Color(0xFFFFD6FF),
          amplitude: 10,
          speed: 0.9,
        ),
        FloatingFriendSpec(
          position: Vector2(880, 940),
          color: const Color(0xFFB9FBC0),
          amplitude: 10,
          speed: 1.0,
        ),
      ],
      baddies: const [
        BaddieSpec.onPlatform(
          2,
          horizontalFraction: 0.3,
          patrolDistance: 140,
          speed: 75,
          color: Color(0xFFFFB3C6),
        ),
        BaddieSpec.onPlatform(
          4,
          horizontalFraction: 0.7,
          patrolDistance: 160,
          speed: 85,
          color: Color(0xFFFFA69E),
        ),
        BaddieSpec.onPlatform(
          6,
          horizontalFraction: 0.5,
          patrolDistance: 110,
          speed: 80,
          color: Color(0xFFFB8A72),
          startMovingRight: false,
        ),
      ],
      coinPlacements: [
        CoinPlacement.absolute(Vector2(540, 890)),
        CoinPlacement.absolute(Vector2(600, 850)),
        CoinPlacement.absolute(Vector2(660, 890)),
        CoinPlacement.absolute(Vector2(1020, 840)),
        CoinPlacement.absolute(Vector2(1080, 802)),
        CoinPlacement.absolute(Vector2(1140, 840)),
      ],
      tunnels: [
        TunnelSpec(
          position: Vector2(500, 508),
          size: Vector2(112, 120),
          exitSpawn: Vector2(560, 986),
          label: 'Secret cavern!',
          linkId: 'level2-main',
          rememberEntryPosition: true,
        ),
        TunnelSpec(
          position: Vector2(1360, 920),
          size: Vector2(112, 120),
          exitSpawn: Vector2(1380, 472),
          color: const Color(0xFF64DFDF),
          entryInset: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          label: 'Back up top!',
          linkId: 'level2-main',
          returnToRememberedEntry: true,
        ),
      ],
    ),
    LevelDefinition(
      size: Vector2(2000, 1320),
      playerSpawn: Vector2(120, 520),
      platforms: [
        PlatformSpec(
          position: Vector2(0, 624),
          size: Vector2(2000, 56),
          color: const Color(0xFFE6F4EA),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(220, 520),
          size: Vector2(220, 30),
          color: const Color(0xFFFDFFB6),
        ),
        PlatformSpec(
          position: Vector2(520, 450),
          size: Vector2(200, 28),
          color: const Color(0xFFFFA69E),
        ),
        PlatformSpec(
          position: Vector2(820, 380),
          size: Vector2(220, 28),
          color: const Color(0xFF9BF6FF),
        ),
        PlatformSpec(
          position: Vector2(1120, 320),
          size: Vector2(220, 30),
          color: const Color(0xFFBDB2FF),
        ),
        PlatformSpec(
          position: Vector2(1400, 260),
          size: Vector2(220, 28),
          color: const Color(0xFFFFE066),
        ),
        PlatformSpec(
          position: Vector2(1680, 320),
          size: Vector2(190, 28),
          color: const Color(0xFFD0F4DE),
        ),
        PlatformSpec(
          position: Vector2(1840, 460),
          size: Vector2(160, 32),
          color: const Color(0xFFFFC6FF),
        ),
        PlatformSpec(
          position: Vector2(260, 1120),
          size: Vector2(1500, 48),
          color: const Color(0xFFE6F4EA),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(620, 1020),
          size: Vector2(240, 30),
          color: const Color(0xFFFDFFB6),
        ),
        PlatformSpec(
          position: Vector2(1180, 980),
          size: Vector2(240, 30),
          color: const Color(0xFFFFB5A7),
        ),
      ],
      starPlacements: const [
        StarPlacement.abovePlatform(1, horizontalFraction: 0.45, heightOffset: 85),
        StarPlacement.abovePlatform(2, horizontalFraction: 0.6, heightOffset: 85),
        StarPlacement.abovePlatform(3, horizontalFraction: 0.4, heightOffset: 90),
        StarPlacement.abovePlatform(4, horizontalFraction: 0.7, heightOffset: 95),
        StarPlacement.abovePlatform(5, horizontalFraction: 0.5, heightOffset: 100),
        StarPlacement.abovePlatform(6, horizontalFraction: 0.4, heightOffset: 90),
        StarPlacement.abovePlatform(7, horizontalFraction: 0.6, heightOffset: 85),
      ],
      floatingFriends: [
        FloatingFriendSpec(
          position: Vector2(520, 560),
          color: const Color(0xFFFFE5EC),
          amplitude: 12,
          speed: 1.2,
        ),
        FloatingFriendSpec(
          position: Vector2(1080, 440),
          color: const Color(0xFFEDE7B1),
          amplitude: 16,
          speed: 1.0,
        ),
        FloatingFriendSpec(
          position: Vector2(1640, 360),
          color: const Color(0xFFBEE1E6),
          amplitude: 14,
          speed: 1.3,
        ),
        FloatingFriendSpec(
          position: Vector2(980, 1020),
          color: const Color(0xFFFFF1E6),
          amplitude: 12,
          speed: 1.15,
        ),
      ],
      baddies: const [
        BaddieSpec.onPlatform(
          1,
          horizontalFraction: 0.5,
          patrolDistance: 160,
          speed: 80,
          color: Color(0xFFFFB5A7),
        ),
        BaddieSpec.onPlatform(
          3,
          horizontalFraction: 0.35,
          patrolDistance: 160,
          speed: 90,
          color: Color(0xFFFFA69E),
        ),
        BaddieSpec.onPlatform(
          5,
          horizontalFraction: 0.55,
          patrolDistance: 180,
          speed: 95,
          color: Color(0xFFFF8FAB),
        ),
        BaddieSpec.onPlatform(
          7,
          horizontalFraction: 0.4,
          patrolDistance: 140,
          speed: 90,
          color: Color(0xFFFFB3C6),
          startMovingRight: false,
        ),
      ],
      coinPlacements: [
        CoinPlacement.absolute(Vector2(640, 980)),
        CoinPlacement.absolute(Vector2(700, 940)),
        CoinPlacement.absolute(Vector2(760, 980)),
        CoinPlacement.absolute(Vector2(1220, 942)),
        CoinPlacement.absolute(Vector2(1280, 904)),
        CoinPlacement.absolute(Vector2(1340, 942)),
      ],
      tunnels: [
        TunnelSpec(
          position: Vector2(440, 528),
          size: Vector2(116, 126),
          exitSpawn: Vector2(660, 1076),
          label: 'Deep cavern!',
          linkId: 'level3-main',
          rememberEntryPosition: true,
        ),
        TunnelSpec(
          position: Vector2(1540, 994),
          size: Vector2(116, 126),
          exitSpawn: Vector2(1580, 512),
          color: const Color(0xFF64DFDF),
          entryInset: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          label: 'Surface ahead!',
          linkId: 'level3-main',
          returnToRememberedEntry: true,
        ),
      ],
    ),
  ];

  double _keyboardDirection = 0;
  bool _leftButtonDown = false;
  bool _rightButtonDown = false;
  double _buttonDirection = 0;

  Rect get levelBounds => _levelBounds;
  List<PlatformBlock> get platforms => _platforms;
  List<TunnelPipe> get tunnels => _tunnels;
  List<Baddie> get baddies => _baddies;
  double get horizontalDirection =>
      _buttonDirection != 0 ? _buttonDirection : _keyboardDirection;
  int get totalStars => _starSpawns.length;
  int get totalCoins => _coinSpawns.length;
  bool get hasFinishedLevel => score.value >= totalStars;
  Player get player => _player;
  int get currentLevel => _currentLevelIndex;
  int get levelCount => _levels.length;
  int get maxLives => _initialLives;

  static final _movementKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyD,
  };

  static final _jumpKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyW,
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(_viewportWidth, _viewportHeight),
    );
    camera.viewfinder.zoom = 1;

    await _loadLevel(0);
  }

  Future<void> _loadLevel(int index) async {
    _levelTransitionPending = false;
    _currentLevelIndex = index;
    final level = _levels[index];

    _levelBounds = Rect.fromLTWH(0, 0, level.size.x, level.size.y);

    _clearLevel();
    score.value = 0;
    coins.value = 0;
    lives.value = _initialLives;

    _background?.removeFromParent();
    _background = PastelBackground(levelSize: level.size.clone());
    await world.add(_background!);

    for (final platformSpec in level.platforms) {
      final block = PlatformBlock(
        position: platformSpec.position.clone(),
        size: platformSpec.size.clone(),
        color: platformSpec.color,
        priority: platformSpec.priority,
      );
      _platforms.add(block);
    }
    await world.addAll(_platforms);

    _starSpawns = level.starPlacements
        .map((placement) => placement.resolve(level.platforms, level.size))
        .toList(growable: false);
    _spawnStars();

    _coinSpawns = level.coinPlacements
        .map((placement) => placement.resolve(level.platforms, level.size))
        .toList(growable: false);
    _spawnCoins();

    for (final spec in level.floatingFriends) {
      final friend = FloatingFriend(
        position: spec.position.clone(),
        color: spec.color,
        amplitude: spec.amplitude,
        speed: spec.speed,
      );
      _floatingFriends.add(friend);
    }
    await world.addAll(_floatingFriends);

    for (final spec in level.baddies) {
      final baddie = Baddie(
        start: spec.resolvePosition(level.platforms, level.size),
        patrolDistance: spec.patrolDistance,
        speed: spec.speed,
        color: spec.color,
        startMovingRight: spec.startMovingRight,
      );
      _baddies.add(baddie);
    }
    await world.addAll(_baddies);

    for (final spec in level.tunnels) {
      if (!_isTunnelPlacementClear(spec)) {
        continue;
      }
      final tunnel = TunnelPipe(
        position: spec.position.clone(),
        size: spec.size.clone(),
        exitSpawn: spec.exitSpawn.clone(),
        color: spec.color,
        entryInset: spec.entryInset,
        cooldownDuration: spec.cooldownSeconds,
        label: spec.label,
        linkId: spec.linkId,
        rememberEntryPosition: spec.rememberEntryPosition,
        returnToRememberedEntry: spec.returnToRememberedEntry,
      );
      _tunnels.add(tunnel);
    }
    await world.addAll(_tunnels);

    if (!_playerAdded) {
      _player = Player(spawnPoint: level.playerSpawn.clone());
      await world.add(_player);
      _playerAdded = true;
    } else {
      _player.setSpawnPoint(level.playerSpawn);
      _player.respawn();
    }

    if (_cameraTarget == null) {
      _cameraTarget = CameraTarget(_player);
      await world.add(_cameraTarget!);
    }

    camera.viewfinder.zoom = 1;
    camera.stop();
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, level.size.x, level.size.y),
      considerViewport: true,
    );
    camera.follow(
      _cameraTarget!,
      snap: true,
      maxSpeed: 1200,
    );
  }

  void _clearLevel() {
    for (final platform in _platforms) {
      platform.removeFromParent();
    }
    _platforms.clear();

    for (final friend in _floatingFriends) {
      friend.removeFromParent();
    }
    _floatingFriends.clear();

    for (final baddie in _baddies) {
      baddie.removeFromParent();
    }
    _baddies.clear();

    for (final coin in _coins) {
      coin.removeFromParent();
    }
    _coins.clear();
    _coinSpawns = [];

    for (final tunnel in _tunnels) {
      tunnel.removeFromParent();
    }
    _tunnels.clear();
    _storedTunnelEntries.clear();

    for (final star in world.children.whereType<Star>().toList()) {
      star.removeFromParent();
    }

    for (final floatingText in world.children.whereType<FloatingText>().toList()) {
      floatingText.removeFromParent();
    }
  }

  void _queueNextLevel() {
    if (_levelTransitionPending || _currentLevelIndex >= _levels.length - 1) {
      return;
    }
    _levelTransitionPending = true;
    final targetIndex = _currentLevelIndex + 1;
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      if (!_levelTransitionPending) {
        return;
      }
      await _loadLevel(targetIndex);
    });
  }

  void _spawnStars() {
    for (final spawn in _starSpawns) {
      world.add(Star(position: spawn.clone()));
    }
  }

  void _spawnCoins() {
    for (final spawn in _coinSpawns) {
      final coin = Coin(position: spawn.clone());
      _coins.add(coin);
      world.add(coin);
    }
  }

  bool _isTunnelPlacementClear(TunnelSpec spec) {
    final pipeTop = spec.position.y;
    final openingLeft = spec.position.x + spec.entryInset.left;
    final openingRight = spec.position.x + spec.size.x - spec.entryInset.right;
    final openingTop = pipeTop + spec.entryInset.top;

    if (openingRight <= openingLeft) {
      return false;
    }

    const double verticalTolerance = 1.0;
    const double requiredClearance = 44.0;

    for (final platform in _platforms) {
      final bounds = platform.bounds;
      final overlapsOpening =
          bounds.left < openingRight && bounds.right > openingLeft;
      if (!overlapsOpening) {
        continue;
      }

      final double clearanceCeiling = openingTop - requiredClearance;
      if (bounds.top < openingTop && bounds.bottom >= clearanceCeiling) {
        return false;
      }

      final intrudesAboveOpening =
          bounds.top < openingTop && bounds.bottom > pipeTop - verticalTolerance;
      if (intrudesAboveOpening) {
        return false;
      }
    }

    return true;
  }

  void collectStar(Star star) {
    if (star.collected) {
      return;
    }
    score.value += 1;
    star.collect();

    if (hasFinishedLevel) {
      final isLastLevel = _currentLevelIndex >= _levels.length - 1;
      world.add(FloatingText(
        text: isLastLevel
            ? 'All levels complete! \uD83C\uDF89'
            : 'Level ${_currentLevelIndex + 1} complete! \u2728',
        position: _player.position.clone() - Vector2(0, 60),
        color: const Color(0xFF5E60CE),
      ));

      if (!isLastLevel) {
        _queueNextLevel();
      }
    }
  }

  void collectCoin(Coin coin) {
    if (coin.collected) {
      return;
    }
    coins.value += 1;
    coin.collect();
    world.add(
      FloatingText(
        text: '+1 coin! 🪙',
        position: coin.position.clone() - Vector2(0, 50),
        color: const Color(0xFFFB8500),
      ),
    );
  }

  Future<void> resetLevel() async {
    _levelTransitionPending = false;
    final shouldRestartFromStart =
        hasFinishedLevel && _currentLevelIndex >= _levels.length - 1;
    final targetIndex = shouldRestartFromStart ? 0 : _currentLevelIndex;
    await _loadLevel(targetIndex);
  }

  void setLeftPressed(bool pressed) {
    _leftButtonDown = pressed;
    _updateButtonDirection();
  }

  void setRightPressed(bool pressed) {
    _rightButtonDown = pressed;
    _updateButtonDirection();
  }

  void _updateButtonDirection() {
    var direction = 0.0;
    if (_leftButtonDown) {
      direction -= 1;
    }
    if (_rightButtonDown) {
      direction += 1;
    }
    _buttonDirection = direction.clamp(-1, 1);
  }

  void triggerJump() {
    _player.jump();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _player.horizontalInput = horizontalDirection;
    _handleEnemyInteractions();
    _handleTunnelTravel();
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _updateKeyboardDirection(keysPressed);

    final key = event.logicalKey;
    if (_jumpKeys.contains(key) && event is KeyDownEvent) {
      _player.jump();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyR && event is KeyDownEvent) {
      resetLevel();
      return KeyEventResult.handled;
    }

    if (_movementKeys.contains(key)) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _updateKeyboardDirection(Set<LogicalKeyboardKey> keysPressed) {
    var direction = 0.0;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      direction -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      direction += 1;
    }
    _keyboardDirection = direction.clamp(-1, 1);
  }

  void _handleEnemyInteractions() {
    for (final baddie in _baddies) {
      if (!baddie.isActive) {
        continue;
      }

      if (!_player.bounds.overlaps(baddie.bounds)) {
        continue;
      }

      final enemyBounds = baddie.bounds;
      final wasAbove =
          _player.previousBottom <= enemyBounds.top + 4; // small tolerance
      final isFalling = _player.verticalVelocity >= 0;

      if (wasAbove && isFalling) {
        baddie.defeat();
        _player.bounceFromEnemy(enemyBounds.top);
        world.add(
          FloatingText(
            text: 'Boop!',
            position: Vector2(
              enemyBounds.center.dx,
              enemyBounds.top - 20,
            ),
            color: const Color(0xFFFFC857),
          ),
        );
      } else if (_player.applyEnemyHit(enemyBounds)) {
        _onPlayerDamaged();
      }

      break;
    }
  }

  void _onPlayerDamaged() {
    if (lives.value <= 0) {
      return;
    }

    final remainingLives = math.max(0, lives.value - 1);
    if (remainingLives == lives.value) {
      return;
    }

    lives.value = remainingLives;
    world.add(
      FloatingText(
        text: remainingLives > 0
            ? 'Ouch! Lives: $remainingLives'
            : 'Out of lives! Restarting...',
        position: _player.position.clone() - Vector2(0, 40),
        color: const Color(0xFFFF758F),
      ),
    );

    if (remainingLives <= 0) {
      resetLevel();
    }
  }

  void _handleTunnelTravel() {
    if (_player.isTeleporting) {
      return;
    }
    for (final tunnel in _tunnels) {
      if (!tunnel.canTeleport(_player)) {
        continue;
      }

      if (tunnel.rememberEntryPosition && tunnel.linkId != null) {
        final surfaceSpot = tunnel.surfaceReturnPosition(_player.size);
        _storedTunnelEntries[tunnel.linkId!] = surfaceSpot;
      }

      Vector2? destinationOverride;
      if (tunnel.returnToRememberedEntry && tunnel.linkId != null) {
        final stored = _storedTunnelEntries[tunnel.linkId!];
        if (stored != null) {
          destinationOverride = stored.clone();
        }
      }

      final destination =
          destinationOverride ?? tunnel.resolveExitFor(_player.size);
      final travelDuration = _player.startTunnelTravel(tunnel, destination);
      tunnel.triggerCooldown();

      if (destinationOverride != null && tunnel.linkId != null) {
        for (final other in _tunnels) {
          if (identical(other, tunnel)) {
            continue;
          }
          if (other.linkId == tunnel.linkId) {
            other.triggerCooldown();
          }
        }
      }

      if (tunnel.returnToRememberedEntry && tunnel.linkId != null) {
        _storedTunnelEntries.remove(tunnel.linkId!);
      }

      if (tunnel.label != null) {
        final labelText = tunnel.label!;
        final labelPosition = destination.clone() - Vector2(0, 60);
        Future<void>.delayed(
          Duration(milliseconds: (travelDuration * 1000).round()),
          () {
            world.add(
              FloatingText(
                text: labelText,
                position: labelPosition.clone(),
                color: const Color(0xFF4895EF),
              ),
            );
          },
        );
      }

      break;
    }
  }

  bool shouldBypassTunnelCollision(Player player, Rect platformRect) {
    for (final tunnel in _tunnels) {
      if (tunnel.shouldBypassCollision(player, platformRect)) {
        return true;
      }
    }
    return false;
  }
}

class Player extends PositionComponent
    with HasGameRef<CutePlatformerGame>
    implements OpacityProvider {
  Player({required Vector2 spawnPoint})
      : _spawnPoint = spawnPoint.clone(),
        super(
          position: spawnPoint.clone(),
          size: Vector2.all(52),
        ) {
    _applyOpacityToPaints();
  }

  final Vector2 _spawnPoint;
  final Vector2 _velocity = Vector2.zero();
  final Vector2 _previousPosition = Vector2.zero();
  double horizontalInput = 0;
  bool _isOnGround = false;
  double _invulnerabilityTimer = 0;

  double _opacity = 1.0;
  bool _isTeleporting = false;
  double _teleportTimer = 0;
  double _teleportEntryDuration = 0;
  double _teleportExitDuration = 0;
  bool _teleportWarped = false;

  final Vector2 _teleportStart = Vector2.zero();
  final Vector2 _teleportExitStart = Vector2.zero();
  final Vector2 _teleportEntryOffset = Vector2.zero();
  final Vector2 _teleportExitOffset = Vector2.zero();
  final Vector2 _teleportWork = Vector2.zero();

  static const _moveSpeed = 220.0;
  static const _jumpSpeed = 520.0;
  static const _invulnerabilityDuration = 1.2;
  static const _knockbackSpeed = 240.0;

  static const Color _bodyColor = Color(0xFF8ECAE6);
  static const Color _bellyColor = Color(0xFFEFF7F6);
  static const Color _cheekColor = Color(0xFFFFB5A7);
  static const Color _eyeColor = Color(0xFF1D3557);

  final Paint _bodyPaint = Paint();
  final Paint _bellyPaint = Paint();
  final Paint _cheekPaint = Paint();
  final Paint _eyePaint = Paint();

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);
  double get previousBottom => _previousPosition.y + size.y;
  double get verticalVelocity => _velocity.y;
  bool get isInvulnerable => _invulnerabilityTimer > 0;
  bool get isTeleporting => _isTeleporting;

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    final clamped = value.clamp(0, 1).toDouble();
    if (clamped == _opacity) {
      return;
    }
    _opacity = clamped;
    _applyOpacityToPaints();
  }

  void _applyOpacityToPaints() {
    _bodyPaint.color = _bodyColor.withValues(alpha: _opacity);
    _bellyPaint.color = _bellyColor.withValues(alpha: _opacity);
    _cheekPaint.color = _cheekColor.withValues(alpha: _opacity);
    _eyePaint.color = _eyeColor.withValues(alpha: _opacity);
  }

  @override
  void render(Canvas canvas) {
    if (_invulnerabilityTimer > 0 && (_invulnerabilityTimer * 20).floor().isEven) {
      return;
    }
    if (_opacity <= 0) {
      return;
    }
    final bodyRect = RRect.fromRectAndRadius(
      Offset.zero & Size(size.x, size.y),
      const Radius.circular(14),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    final bellyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.18, size.y * 0.35, size.x * 0.64, size.y * 0.5),
      const Radius.circular(12),
    );
    canvas.drawRRect(bellyRect, _bellyPaint);

    final cheekOffsetY = size.y * 0.42;
    final cheekRadius = size.x * 0.12;
    canvas.drawCircle(Offset(size.x * 0.25, cheekOffsetY), cheekRadius, _cheekPaint);
    canvas.drawCircle(Offset(size.x * 0.75, cheekOffsetY), cheekRadius, _cheekPaint);

    final eyeRadius = size.x * 0.08;
    final eyeOffsetY = size.y * 0.32;
    canvas.drawCircle(Offset(size.x * 0.32, eyeOffsetY), eyeRadius, _eyePaint);
    canvas.drawCircle(Offset(size.x * 0.68, eyeOffsetY), eyeRadius, _eyePaint);

    final smilePath = Path()
      ..moveTo(size.x * 0.35, size.y * 0.62)
      ..quadraticBezierTo(size.x * 0.5, size.y * 0.7, size.x * 0.65, size.y * 0.62);
    final smilePaint = Paint()
      ..color = _eyePaint.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  void update(double dt) {
    _previousPosition.setFrom(position);
    if (_isTeleporting) {
      _updateTeleport(dt);
      super.update(dt);
      _keepWithinBounds();
      if (_invulnerabilityTimer > 0) {
        _invulnerabilityTimer = math.max(0, _invulnerabilityTimer - dt);
      }
      _previousPosition.setFrom(position);
      if (_isTeleporting) {
        return;
      }
    } else {
      super.update(dt);
    }

    _applyPhysics(dt);
    _keepWithinBounds();

    if (_invulnerabilityTimer > 0) {
      _invulnerabilityTimer = math.max(0, _invulnerabilityTimer - dt);
    }
  }

  void _updateTeleport(double dt) {
    final totalDuration = _teleportEntryDuration + _teleportExitDuration;
    if (totalDuration <= 0) {
      _finishTeleport();
      return;
    }

    _teleportTimer = math.min(_teleportTimer + dt, totalDuration);

    if (_teleportTimer <= _teleportEntryDuration && _teleportEntryDuration > 0) {
      final double progress =
          (_teleportTimer / _teleportEntryDuration).clamp(0.0, 1.0);
      final eased = Curves.easeInQuad.transform(progress);
      _teleportWork
        ..setFrom(_teleportEntryOffset)
        ..scale(eased)
        ..add(_teleportStart);
      position.setFrom(_teleportWork);
      opacity = 1 - Curves.easeInCubic.transform(progress);
    } else {
      if (!_teleportWarped) {
        position.setFrom(_teleportExitStart);
        _previousPosition.setFrom(position);
        _teleportWarped = true;
      }
      final double exitProgress = _teleportExitDuration <= 0
          ? 1.0
          : ((_teleportTimer - _teleportEntryDuration) / _teleportExitDuration)
              .clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(exitProgress);
      _teleportWork
        ..setFrom(_teleportExitOffset)
        ..scale(eased)
        ..add(_teleportExitStart);
      position.setFrom(_teleportWork);
      opacity = Curves.easeOutCubic.transform(exitProgress);
    }

    if (_teleportTimer >= totalDuration - 1e-6) {
      _finishTeleport();
    }
  }

  double startTunnelTravel(TunnelPipe tunnel, Vector2 destination) {
    _cancelTeleport();

    final opening = tunnel.openingRect;
    final levelBounds = gameRef.levelBounds;
    final double maxEntryDepth =
        math.max(0, opening.bottom - (position.y + size.y));
    final double maxExitDepth =
        math.max(0, levelBounds.bottom - size.y - destination.y);
    final double travelDepth = math.min(math.min(maxEntryDepth, maxExitDepth), 48.0);

    _teleportStart.setFrom(position);
    _teleportExitStart
      ..setFrom(destination)
      ..y += travelDepth;

    _teleportEntryOffset
      ..setValues(0, travelDepth);
    _teleportExitOffset
      ..setValues(0, -travelDepth);

    _teleportTimer = 0;
    _teleportEntryDuration = 0.26;
    _teleportExitDuration = 0.28;
    _teleportWarped = false;
    _isTeleporting = true;
    horizontalInput = 0;
    _velocity.setZero();
    _isOnGround = false;
    opacity = 1;

    return _teleportEntryDuration + _teleportExitDuration;
  }

  void _finishTeleport() {
    _isTeleporting = false;
    _teleportTimer = 0;
    _teleportEntryDuration = 0;
    _teleportExitDuration = 0;
    _teleportWarped = false;
    _teleportEntryOffset.setZero();
    _teleportExitOffset.setZero();
    _teleportStart.setZero();
    _teleportExitStart.setZero();
    opacity = 1;
    _velocity.setZero();
    _isOnGround = false;
    _previousPosition.setFrom(position);
  }

  void _cancelTeleport() {
    if (!_isTeleporting) {
      opacity = 1;
      _teleportEntryOffset.setZero();
      _teleportExitOffset.setZero();
      _teleportStart.setZero();
      _teleportExitStart.setZero();
      return;
    }
    _isTeleporting = false;
    _teleportTimer = 0;
    _teleportEntryDuration = 0;
    _teleportExitDuration = 0;
    _teleportWarped = false;
    _teleportEntryOffset.setZero();
    _teleportExitOffset.setZero();
    _teleportStart.setZero();
    _teleportExitStart.setZero();
    opacity = 1;
  }

  void jump() {
    if (_isTeleporting) {
      return;
    }
    if (_isOnGround) {
      _velocity.y = -_jumpSpeed;
      _isOnGround = false;
    }
  }

  void respawn() {
    _cancelTeleport();
    position.setFrom(_spawnPoint);
    _previousPosition.setFrom(_spawnPoint);
    _velocity.setZero();
    _isOnGround = false;
    _invulnerabilityTimer = 0;
  }

  void setSpawnPoint(Vector2 spawnPoint) {
    _spawnPoint.setFrom(spawnPoint);
  }

  void bounceFromEnemy(double surfaceY) {
    position.y = surfaceY - size.y;
    _velocity.y = -_jumpSpeed * 0.6;
    _isOnGround = false;
  }

  bool applyEnemyHit(Rect enemyBounds) {
    if (_isTeleporting) {
      return false;
    }
    if (_invulnerabilityTimer > 0) {
      return false;
    }

    final playerCenter = bounds.center.dx;
    final enemyCenter = enemyBounds.center.dx;
    final direction = playerCenter < enemyCenter ? -1 : 1;
    const separation = 6.0;

    if (direction < 0) {
      position.x = enemyBounds.left - size.x - separation;
    } else {
      position.x = enemyBounds.right + separation;
    }

    final levelBounds = gameRef.levelBounds;
    position.x = position.x.clamp(levelBounds.left, levelBounds.right - size.x);
    position.y = math.min(position.y, levelBounds.bottom - size.y);

    horizontalInput = 0;
    _velocity
      ..x = direction * _knockbackSpeed
      ..y = -_jumpSpeed * 0.4;
    _isOnGround = false;
    _invulnerabilityTimer = _invulnerabilityDuration;
    return true;
  }

  void teleportTo(Vector2 destination) {
    _cancelTeleport();
    position.setFrom(destination);
    _previousPosition.setFrom(destination);
    _velocity.setZero();
    _isOnGround = false;
  }

  void _applyPhysics(double dt) {
    if (_isTeleporting) {
      return;
    }
    _velocity.y += gameRef.gravity.y * dt;
    _velocity.x = horizontalInput * _moveSpeed;

    _moveHorizontally(dt);
    _moveVertically(dt);

    if (position.y > gameRef.levelBounds.bottom + 200) {
      respawn();
    }
  }

  void _moveHorizontally(double dt) {
    position.x += _velocity.x * dt;

    for (final platform in gameRef.platforms) {
      if (gameRef.shouldBypassTunnelCollision(this, platform.bounds)) {
        continue;
      }
      if (bounds.overlaps(platform.bounds)) {
        if (_velocity.x > 0) {
          position.x = platform.bounds.left - size.x;
        } else if (_velocity.x < 0) {
          position.x = platform.bounds.right;
        }
        _velocity.x = 0;
      }
    }

    for (final tunnel in gameRef.tunnels) {
      final currentBounds = bounds;
      if (currentBounds.bottom <= tunnel.bodyRect.top + 2) {
        continue;
      }

      if (_velocity.x > 0) {
        final wall = tunnel.leftWallRect;
        if (wall.width > 0 &&
            currentBounds.right > wall.left &&
            currentBounds.left < wall.right &&
            currentBounds.bottom > wall.top &&
            currentBounds.top < wall.bottom) {
          position.x = wall.left - size.x;
          _velocity.x = 0;
          continue;
        }
      } else if (_velocity.x < 0) {
        final wall = tunnel.rightWallRect;
        if (wall.width > 0 &&
            currentBounds.left < wall.right &&
            currentBounds.right > wall.left &&
            currentBounds.bottom > wall.top &&
            currentBounds.top < wall.bottom) {
          position.x = wall.right;
          _velocity.x = 0;
          continue;
        }
      }
    }
  }

  void _moveVertically(double dt) {
    position.y += _velocity.y * dt;
    _isOnGround = false;

    for (final platform in gameRef.platforms) {
      if (gameRef.shouldBypassTunnelCollision(this, platform.bounds)) {
        continue;
      }
      if (bounds.overlaps(platform.bounds)) {
        if (_velocity.y > 0) {
          position.y = platform.bounds.top - size.y;
          _isOnGround = true;
        } else if (_velocity.y < 0) {
          position.y = platform.bounds.bottom;
        }
        _velocity.y = 0;
      }
    }
  }

  void _keepWithinBounds() {
    final bounds = gameRef.levelBounds;
    if (position.x < bounds.left) {
      position.x = bounds.left;
    }
    if (position.x + size.x > bounds.right) {
      position.x = bounds.right - size.x;
    }
    if (position.y < bounds.top) {
      position.y = bounds.top;
      _velocity.y = 0;
    }
  }
}

class PlatformBlock extends PositionComponent {
  PlatformBlock({
    required super.position,
    required super.size,
    required this.color,
    super.priority,
  }) : super(anchor: Anchor.topLeft);

  final Color color;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & Size(size.x, size.y);
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );

    final topHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(12, 8),
      Offset(size.x - 12, 8),
      topHighlight,
    );
  }
}

class Star extends PositionComponent
    with HasGameRef<CutePlatformerGame>
    implements OpacityProvider {
  Star({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(30),
          anchor: Anchor.center,
        ) {
    _applyOpacityToPaints();
  }

  bool collected = false;
  static const _fillColor = Color(0xFFFFC857);
  static const _strokeColor = Color(0xFFF4A261);
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  double _opacity = 1.0;

  Rect get bounds => Rect.fromCenter(
        center: Offset(position.x, position.y),
        width: size.x,
        height: size.y,
      );

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value.clamp(0, 1);
    _applyOpacityToPaints();
  }

  void _applyOpacityToPaints() {
    _fillPaint.color = _fillColor.withValues(alpha: _opacity);
    _strokePaint.color = _strokeColor.withValues(alpha: _opacity);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!collected && bounds.overlaps(gameRef.player.bounds)) {
      gameRef.collectStar(this);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    final path = Path();
    final outerRadius = size.x / 2;
    final innerRadius = outerRadius * 0.5;
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, _fillPaint);
    canvas.drawPath(path, _strokePaint);
    canvas.restore();
  }

  void collect() {
    collected = true;
    add(
      OpacityEffect.to(
        0,
        EffectController(duration: 0.25),
        onComplete: removeFromParent,
      ),
    );
    add(
      ScaleEffect.to(
        Vector2.all(1.4),
        EffectController(duration: 0.25),
      ),
    );
  }
}

class Coin extends PositionComponent
    with HasGameRef<CutePlatformerGame>
    implements OpacityProvider {
  Coin({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(26),
          anchor: Anchor.center,
          priority: 2,
        ) {
    _applyOpacityToPaints();
  }

  bool collected = false;
  double _time = 0;
  static const _fillColor = Color(0xFFFFC300);
  static const _strokeColor = Color(0xFFB08904);
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  double _opacity = 1.0;

  Rect get bounds => Rect.fromCenter(
        center: Offset(position.x, position.y),
        width: size.x,
        height: size.y,
      );

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value.clamp(0, 1);
    _applyOpacityToPaints();
  }

  void _applyOpacityToPaints() {
    _fillPaint.color = _fillColor.withValues(alpha: _opacity);
    _strokePaint.color = _strokeColor.withValues(alpha: _opacity);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt * 6;

    if (!collected && bounds.overlaps(gameRef.player.bounds)) {
      gameRef.collectCoin(this);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    final pulse = 1 + math.sin(_time) * 0.06;
    canvas.scale(pulse, 1.0);

    final radius = size.x / 2;
    canvas.drawCircle(Offset.zero, radius, _fillPaint);
    canvas.drawCircle(Offset.zero, radius - 2, _strokePaint);

    final innerStroke = Paint()
      ..color = _strokePaint.color.withValues(alpha: _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, radius * 0.6, innerStroke);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: _opacity * 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-radius * 0.4, -radius * 0.2),
      Offset(-radius * 0.1, -radius * 0.4),
      highlightPaint,
    );

    canvas.restore();
  }

  void collect() {
    collected = true;
    add(
      OpacityEffect.to(
        0,
        EffectController(duration: 0.25),
        onComplete: removeFromParent,
      ),
    );
    add(
      ScaleEffect.to(
        Vector2.all(1.4),
        EffectController(duration: 0.25),
      ),
    );
  }
}

class TunnelPipe extends PositionComponent
    with HasGameRef<CutePlatformerGame>
    implements OpacityProvider {
  TunnelPipe({
    required Vector2 position,
    required Vector2 size,
    required this.exitSpawn,
    required this.color,
    this.entryInset = const EdgeInsets.fromLTRB(12, 14, 12, 6),
    this.cooldownDuration = 0.6,
    this.label,
    this.linkId,
    this.rememberEntryPosition = false,
    this.returnToRememberedEntry = false,
  })  : _opacity = 1,
        super(
          position: position,
          size: size,
          anchor: Anchor.topLeft,
          priority: -1,
        );

  final Vector2 exitSpawn;
  final Color color;
  final EdgeInsets entryInset;
  final double cooldownDuration;
  final String? label;
  final String? linkId;
  final bool rememberEntryPosition;
  final bool returnToRememberedEntry;

  double _cooldown = 0;
  double _opacity;
  bool _containsPlayer = false;

  Rect get openingRect => Rect.fromLTWH(
        position.x + entryInset.left,
        position.y + entryInset.top,
        size.x - entryInset.horizontal,
        size.y - entryInset.vertical,
      );

  Rect get bodyRect =>
      Rect.fromLTWH(position.x, position.y, size.x, size.y);

  Rect get leftWallRect => Rect.fromLTWH(
        position.x,
        position.y,
        entryInset.left,
        size.y,
      );

  Rect get rightWallRect => Rect.fromLTWH(
        position.x + size.x - entryInset.right,
        position.y,
        entryInset.right,
        size.y,
      );

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) {
      _cooldown = math.max(0, _cooldown - dt);
    }

    if (_containsPlayer &&
        (!gameRef.player.bounds.overlaps(openingRect) ||
            gameRef.player.isTeleporting)) {
      _containsPlayer = false;
    }
  }

  bool canTeleport(Player player) {
    if (_cooldown > 0 || player.isTeleporting) {
      return false;
    }
    final rect = openingRect;
    final playerRect = player.bounds;
    const tolerance = 4.0;
    final fullyInside = playerRect.left >= rect.left + tolerance &&
        playerRect.right <= rect.right - tolerance &&
        playerRect.top >= rect.top + tolerance &&
        playerRect.bottom <= rect.bottom - tolerance;
    if (!fullyInside) {
      return false;
    }

    if (!_containsPlayer) {
      const entryTolerance = 14.0;
      final enteredFromAbove =
          player.previousBottom <= rect.top + entryTolerance &&
              player.verticalVelocity >= 0;
      if (!enteredFromAbove) {
        return false;
      }
      _containsPlayer = true;
    }

    return true;
  }

  bool shouldBypassCollision(Player player, Rect platformRect) {
    if (player.isTeleporting) {
      return false;
    }

    final opening = openingRect;
    final playerRect = player.bounds;
    const double horizontalAllowance = 6.0;
    const double upperAllowance = 12.0;
    final double lowerAllowance = entryInset.bottom + 12.0;

    final Rect bypassRegion = Rect.fromLTRB(
      opening.left - horizontalAllowance,
      opening.top - upperAllowance,
      opening.right + horizontalAllowance,
      opening.bottom + lowerAllowance,
    );

    if (!platformRect.overlaps(bypassRegion)) {
      if (!playerRect.overlaps(bypassRegion)) {
        _containsPlayer = false;
      }
      return false;
    }

    if (!playerRect.overlaps(bypassRegion)) {
      _containsPlayer = false;
      return false;
    }

    final bool enteringFromTop =
        player.previousBottom <= opening.top + upperAllowance &&
            player.verticalVelocity >= 0;

    if (enteringFromTop) {
      _containsPlayer = true;
    }

    if (!_containsPlayer) {
      return false;
    }

    return player.verticalVelocity >= 0;
  }

  void triggerCooldown() {
    _cooldown = cooldownDuration;
    _containsPlayer = false;
  }

  Vector2 resolveExitFor(Vector2 playerSize) {
    final bounds = gameRef.levelBounds;
    final resolved = exitSpawn.clone();
    resolved.x = resolved.x
        .clamp(bounds.left, bounds.right - playerSize.x)
        .toDouble();
    resolved.y = resolved.y
        .clamp(bounds.top, bounds.bottom - playerSize.y)
        .toDouble();
    return resolved;
  }

  Vector2 surfaceReturnPosition(Vector2 playerSize) {
    final bounds = gameRef.levelBounds;
    final opening = openingRect;
    const double exitGap = 12.0;
    final double leftCandidate = opening.left - playerSize.x - exitGap;
    final double rightCandidate = opening.right + exitGap;

    double targetX;
    if (leftCandidate >= bounds.left) {
      targetX = leftCandidate;
    } else if (rightCandidate + playerSize.x <= bounds.right) {
      targetX = rightCandidate;
    } else {
      targetX = (opening.left + opening.right - playerSize.x) / 2;
    }

    final double targetY = position.y - playerSize.y;
    final double clampedX = targetX
        .clamp(bounds.left.toDouble(), bounds.right - playerSize.x)
        .toDouble();
    final double clampedY = targetY
        .clamp(bounds.top.toDouble(), bounds.bottom - playerSize.y)
        .toDouble();

    return Vector2(clampedX, clampedY);
  }

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value.clamp(0, 1);
  }

  @override
  void render(Canvas canvas) {
    final lipHeight = math.max(20.0, size.y * 0.22);
    final bodyRect = Rect.fromLTWH(0, lipHeight - 6, size.x, size.y - (lipHeight - 6));
    final lipRect = Rect.fromLTWH(-size.x * 0.08, 0, size.x * 1.16, lipHeight);

    final bodyPaint = Paint()
      ..color = color.withValues(alpha: _opacity)
      ..style = PaintingStyle.fill;
    final lipPaint = Paint()
      ..color = color.withValues(alpha: (_opacity * 0.9).clamp(0, 1))
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.save();
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect.shift(const Offset(2, 4)), const Radius.circular(18)),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lipRect, const Radius.circular(18)),
      lipPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(18)),
      bodyPaint,
    );

    final interior = Rect.fromLTWH(
      entryInset.left,
      entryInset.top,
      size.x - entryInset.horizontal,
      size.y - entryInset.vertical,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(interior, const Radius.circular(12)),
      Paint()
        ..color = Colors.black.withValues(alpha: _opacity * 0.35)
        ..style = PaintingStyle.fill,
    );

    canvas.drawLine(
      Offset(lipRect.left + 8, lipRect.bottom - 4),
      Offset(lipRect.right - 8, lipRect.bottom - 4),
      Paint()
        ..color = Colors.white.withValues(alpha: _opacity * 0.4)
        ..strokeWidth = 3,
    );

    canvas.restore();
  }
}

class Baddie extends PositionComponent
    with HasGameRef<CutePlatformerGame>
    implements OpacityProvider {
  Baddie({
    required Vector2 start,
    required this.patrolDistance,
    required this.speed,
    required this.color,
    this.startMovingRight = true,
  })  : _originX = start.x,
        _originY = start.y,
        super(
          position: start.clone(),
          size: Vector2(bodyWidth, bodyHeight),
          priority: 1,
        ) {
    _direction = startMovingRight ? 1 : -1;
    _updatePaints();
  }

  static const double bodyWidth = 46;
  static const double bodyHeight = 36;

  final double patrolDistance;
  final double speed;
  final Color color;
  final bool startMovingRight;

  final double _originX;
  final double _originY;
  double _direction = 1;
  bool _defeated = false;
  double _opacity = 1;

  late double _minX;
  late double _maxX;

  final Paint _bodyPaint = Paint();
  final Paint _eyePaint = Paint()..style = PaintingStyle.fill;
  final Paint _cheekPaint = Paint()..style = PaintingStyle.fill;
  final Paint _mouthPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  bool get isActive => !_defeated && !isRemoving;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  @override
  void onMount() {
    super.onMount();
    final bounds = gameRef.levelBounds;
    final levelLeft = bounds.left;
    final levelRight = bounds.right - size.x;
    _minX = math.max(levelLeft, _originX);
    _maxX = math.min(levelRight, _originX + patrolDistance);
    if (_maxX < _minX) {
      final anchor = math.max(bounds.left, math.min(_originX, levelRight));
      _minX = anchor;
      _maxX = anchor;
    }

    position.x = position.x.clamp(_minX, _maxX).toDouble();
    final levelBottom = bounds.bottom - size.y;
    position.y = _originY.clamp(bounds.top, levelBottom).toDouble();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_defeated || speed <= 0) {
      return;
    }
    if ((_maxX - _minX).abs() <= 0.01) {
      position.x = _minX;
      return;
    }

    final nextX = position.x + _direction * speed * dt;
    if (nextX <= _minX) {
      position.x = _minX;
      _direction = 1;
    } else if (nextX >= _maxX) {
      position.x = _maxX;
      _direction = -1;
    } else {
      position.x = nextX;
    }
  }

  @override
  void render(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & Size(size.x, size.y),
      const Radius.circular(12),
    );
    canvas.drawRRect(body, _bodyPaint);

    final eyeY = size.y * 0.4;
    final eyeRadius = 4.0;
    canvas.drawCircle(Offset(size.x * 0.32, eyeY), eyeRadius, _eyePaint);
    canvas.drawCircle(Offset(size.x * 0.68, eyeY), eyeRadius, _eyePaint);

    final cheekY = size.y * 0.62;
    final cheekRadius = 4.5;
    canvas.drawCircle(Offset(size.x * 0.28, cheekY), cheekRadius, _cheekPaint);
    canvas.drawCircle(Offset(size.x * 0.72, cheekY), cheekRadius, _cheekPaint);

    final mouthPath = Path()
      ..moveTo(size.x * 0.34, size.y * 0.72)
      ..quadraticBezierTo(
        size.x * 0.5,
        size.y * 0.8,
        size.x * 0.66,
        size.y * 0.72,
      );
    canvas.drawPath(mouthPath, _mouthPaint);
  }

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value.clamp(0, 1);
    _updatePaints();
  }

  void defeat() {
    if (_defeated) {
      return;
    }
    _defeated = true;
    _direction = 0;
    add(
      OpacityEffect.to(
        0,
        EffectController(duration: 0.25),
        onComplete: removeFromParent,
      ),
    );
    add(
      ScaleEffect.to(
        Vector2.all(0.4),
        EffectController(duration: 0.25),
      ),
    );
  }

  void _updatePaints() {
    _bodyPaint.color = color.withValues(alpha: _opacity);
    _eyePaint.color = const Color(0xFF1D3557).withValues(alpha: _opacity);
    _cheekPaint.color = const Color(0xFFFFD6E0).withValues(alpha: _opacity);
    _mouthPaint
      ..color = const Color(0xFF1D3557).withValues(alpha: _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
  }
}

class PastelBackground extends PositionComponent {
  PastelBackground({required Vector2 levelSize})
      : _levelSize = levelSize.clone(),
        super(priority: -10);

  final Vector2 _levelSize;

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & Size(_levelSize.x, _levelSize.y);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFEDF2FB),
          Color(0xFFD7E3FC),
          Color(0xFFFDE2E4),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    void drawCloud(double x, double y, double scale) {
      final center = Offset(x, y);
      canvas.drawCircle(center + Offset(-20 * scale, 0), 26 * scale, cloudPaint);
      canvas.drawCircle(center + Offset(20 * scale, 0), 24 * scale, cloudPaint);
      canvas.drawCircle(center + Offset(0, -18 * scale), 28 * scale, cloudPaint);
    }

    drawCloud(180, 120, 1.0);
    drawCloud(520, 80, 0.8);
    drawCloud(940, 140, 1.2);
    drawCloud(1320, 90, 0.9);
  }
}

class FloatingFriend extends PositionComponent {
  FloatingFriend({
    required super.position,
    required this.color,
    required this.amplitude,
    required this.speed,
  }) : super(size: Vector2(40, 40), anchor: Anchor.topLeft, priority: -1);

  final Color color;
  final double amplitude;
  final double speed;
  double _elapsed = 0;
  late final double _baseY;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _baseY = position.y;
  }

  @override
  void render(Canvas canvas) {
    final body = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.x, size.y),
        const Radius.circular(20),
      ),
      body,
    );

    final eyePaint = Paint()..color = const Color(0xFF344E41);
    canvas.drawCircle(Offset(size.x * 0.35, size.y * 0.4), 4, eyePaint);
    canvas.drawCircle(Offset(size.x * 0.65, size.y * 0.4), 4, eyePaint);

    final smilePaint = Paint()
      ..color = const Color(0xFF344E41)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final smile = Path()
      ..moveTo(size.x * 0.3, size.y * 0.6)
      ..quadraticBezierTo(size.x * 0.5, size.y * 0.7, size.x * 0.7, size.y * 0.6);
    canvas.drawPath(smile, smilePaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt * speed;
    position.y = _baseY + math.sin(_elapsed) * amplitude;
  }
}

class FloatingText extends TextComponent implements OpacityProvider {
  FloatingText({
    required String text,
    required Vector2 position,
    required Color color,
  })  : _baseColor = color,
        super(
          text: text,
          position: position,
          anchor: Anchor.center,
          priority: 5,
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ) {
    _rebuildTextRenderer();
    add(
      MoveByEffect(
        Vector2(0, -40),
        EffectController(duration: 0.6, curve: Curves.easeOut),
      ),
    );
    add(
      OpacityEffect.to(
        0,
        EffectController(duration: 0.6, curve: Curves.easeIn),
        onComplete: removeFromParent,
      ),
    );
  }

  final Color _baseColor;
  double _opacity = 1.0;

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value.clamp(0, 1);
    _rebuildTextRenderer();
  }

  void _rebuildTextRenderer() {
    final currentStyle = (textRenderer as TextPaint).style;
    textRenderer = TextPaint(
      style: currentStyle.copyWith(
        color: _baseColor.withValues(alpha: _opacity),
      ),
    );
  }
}
