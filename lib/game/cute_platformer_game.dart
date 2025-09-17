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
    this.floatingFriends = const [],
  });

  final Vector2 size;
  final Vector2 playerSpawn;
  final List<PlatformSpec> platforms;
  final List<StarPlacement> starPlacements;
  final List<FloatingFriendSpec> floatingFriends;
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

class CutePlatformerGame extends FlameGame with KeyboardEvents {
  CutePlatformerGame()
      : score = ValueNotifier<int>(0),
        gravity = Vector2(0, 900);

  static const double _viewportWidth = 800;
  static const double _viewportHeight = 480;

  final ValueNotifier<int> score;
  final Vector2 gravity;

  late final Player _player;
  final List<PlatformBlock> _platforms = [];
  final List<FloatingFriend> _floatingFriends = [];
  List<Vector2> _starSpawns = [];
  late Rect _levelBounds;
  PastelBackground? _background;
  int _currentLevelIndex = 0;
  bool _playerAdded = false;
  bool _levelTransitionPending = false;
  CameraTarget? _cameraTarget;

  final List<LevelDefinition> _levels = [
    LevelDefinition(
      size: Vector2(1600, 600),
      playerSpawn: Vector2(100, 480),
      platforms: [
        PlatformSpec(
          position: Vector2(0, 544),
          size: Vector2(1600, 56),
          color: const Color(0xFFBEE3DB),
          priority: -2,
        ),
        PlatformSpec(
          position: Vector2(140, 440),
          size: Vector2(220, 32),
          color: const Color(0xFFF0A6CA),
        ),
        PlatformSpec(
          position: Vector2(430, 350),
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
      ],
    ),
    LevelDefinition(
      size: Vector2(1800, 640),
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
          position: Vector2(520, 440),
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
      ],
    ),
    LevelDefinition(
      size: Vector2(2000, 680),
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
      ],
    ),
  ];

  double _keyboardDirection = 0;
  bool _leftButtonDown = false;
  bool _rightButtonDown = false;
  double _buttonDirection = 0;

  Rect get levelBounds => _levelBounds;
  List<PlatformBlock> get platforms => _platforms;
  double get horizontalDirection =>
      _buttonDirection != 0 ? _buttonDirection : _keyboardDirection;
  int get totalStars => _starSpawns.length;
  bool get hasFinishedLevel => score.value >= totalStars;
  Player get player => _player;
  int get currentLevel => _currentLevelIndex;
  int get levelCount => _levels.length;

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
}

class Player extends PositionComponent with HasGameRef<CutePlatformerGame> {
  Player({required Vector2 spawnPoint})
      : _spawnPoint = spawnPoint.clone(),
        super(
          position: spawnPoint.clone(),
          size: Vector2.all(52),
        );

  final Vector2 _spawnPoint;
  final Vector2 _velocity = Vector2.zero();
  double horizontalInput = 0;
  bool _isOnGround = false;

  static const _moveSpeed = 220.0;
  static const _jumpSpeed = 520.0;

  final Paint _bodyPaint = Paint()..color = const Color(0xFF8ECAE6);
  final Paint _bellyPaint = Paint()..color = const Color(0xFFEFF7F6);
  final Paint _cheekPaint = Paint()..color = const Color(0xFFFFB5A7);
  final Paint _eyePaint = Paint()..color = const Color(0xFF1D3557);

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
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
    super.update(dt);
    _applyPhysics(dt);
    _keepWithinBounds();
  }

  void jump() {
    if (_isOnGround) {
      _velocity.y = -_jumpSpeed;
      _isOnGround = false;
    }
  }

  void respawn() {
    position.setFrom(_spawnPoint);
    _velocity.setZero();
    _isOnGround = false;
  }

  void setSpawnPoint(Vector2 spawnPoint) {
    _spawnPoint.setFrom(spawnPoint);
  }

  void _applyPhysics(double dt) {
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
      if (bounds.overlaps(platform.bounds)) {
        if (_velocity.x > 0) {
          position.x = platform.bounds.left - size.x;
        } else if (_velocity.x < 0) {
          position.x = platform.bounds.right;
        }
        _velocity.x = 0;
      }
    }
  }

  void _moveVertically(double dt) {
    position.y += _velocity.y * dt;
    _isOnGround = false;

    for (final platform in gameRef.platforms) {
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
