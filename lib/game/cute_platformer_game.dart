import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CutePlatformerGame extends FlameGame with KeyboardEvents {
  CutePlatformerGame()
      : score = ValueNotifier<int>(0),
        gravity = Vector2(0, 900);

  final ValueNotifier<int> score;
  final Vector2 gravity;

  late final Player _player;
  final List<PlatformBlock> _platforms = [];
  late final List<Vector2> _starSpawns;
  late Rect _levelBounds;

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

    camera.viewport = FixedResolutionViewport(resolution: Vector2(800, 480));

    const levelWidth = 1600.0;
    const levelHeight = 600.0;
    _levelBounds = const Rect.fromLTWH(0, 0, levelWidth, levelHeight);

    add(PastelBackground(levelSize: Vector2(levelWidth, levelHeight)));

    _platforms.addAll([
      PlatformBlock(
        position: Vector2(0, levelHeight - 56),
        size: Vector2(levelWidth, 56),
        color: const Color(0xFFBEE3DB),
        priority: -2,
      ),
      PlatformBlock(
        position: Vector2(140, levelHeight - 160),
        size: Vector2(220, 32),
        color: const Color(0xFFF0A6CA),
      ),
      PlatformBlock(
        position: Vector2(430, levelHeight - 250),
        size: Vector2(160, 28),
        color: const Color(0xFF9AD0EC),
      ),
      PlatformBlock(
        position: Vector2(680, levelHeight - 210),
        size: Vector2(220, 30),
        color: const Color(0xFFFFD6BA),
      ),
      PlatformBlock(
        position: Vector2(960, levelHeight - 320),
        size: Vector2(180, 28),
        color: const Color(0xFFCAFFBF),
      ),
      PlatformBlock(
        position: Vector2(1230, levelHeight - 220),
        size: Vector2(200, 32),
        color: const Color(0xFFFDE2E4),
      ),
    ]);

    await addAll(_platforms);

    _player = Player(spawnPoint: Vector2(100, levelHeight - 120));
    await add(_player);

    camera.follow(_player);
    _applyCameraBounds(levelWidth: levelWidth, levelHeight: levelHeight);

    _starSpawns = [
      Vector2(220, levelHeight - 210),
      Vector2(520, levelHeight - 300),
      Vector2(760, levelHeight - 260),
      Vector2(1020, levelHeight - 360),
      Vector2(1340, levelHeight - 260),
    ];
    _spawnStars();

    addAll([
      FloatingFriend(
        position: Vector2(360, levelHeight - 110),
        color: const Color(0xFF8EECF5),
        amplitude: 8,
        speed: 1.2,
      ),
      FloatingFriend(
        position: Vector2(880, levelHeight - 150),
        color: const Color(0xFFFFE3E3),
        amplitude: 10,
        speed: 0.8,
      ),
    ]);
  }

  void _spawnStars() {
    for (final spawn in _starSpawns) {
      add(Star(position: spawn.clone()));
    }
  }

  void _applyCameraBounds({required double levelWidth, required double levelHeight}) {
    const halfViewWidth = 400.0;
    const halfViewHeight = 240.0;

    final minX = levelWidth <= halfViewWidth * 2
        ? levelWidth / 2
        : halfViewWidth;
    final maxX = levelWidth <= halfViewWidth * 2
        ? levelWidth / 2
        : levelWidth - halfViewWidth;

    final minY = levelHeight <= halfViewHeight * 2
        ? levelHeight / 2
        : halfViewHeight;
    final maxY = levelHeight <= halfViewHeight * 2
        ? levelHeight / 2
        : levelHeight - halfViewHeight;

    camera.viewfinder.add(
      BoundedPositionBehavior(
        bounds: Rectangle.fromLTRB(minX, minY, maxX, maxY),
      ),
    );
  }

  void collectStar(Star star) {
    if (star.collected) {
      return;
    }
    score.value += 1;
    star.collect();

    if (hasFinishedLevel) {
      add(FloatingText(
        text: 'All stars collected! \u2728',
        position: _player.position.clone() - Vector2(0, 60),
        color: const Color(0xFF5E60CE),
      ));
    }
  }

  void resetLevel() {
    score.value = 0;

    for (final star in children.whereType<Star>().toList()) {
      star.removeFromParent();
    }
    _spawnStars();
    _player.respawn();
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
          position: spawnPoint,
          size: Vector2.all(52),
        );

  final Vector2 _spawnPoint;
  final Vector2 _velocity = Vector2.zero();
  double horizontalInput = 0;
  bool _isOnGround = false;

  static const _moveSpeed = 220.0;
  static const _jumpSpeed = 420.0;

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
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(12, 8),
      Offset(size.x - 12, 8),
      topHighlight,
    );
  }
}

class Star extends PositionComponent with HasGameRef<CutePlatformerGame> {
  Star({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(30),
          anchor: Anchor.topLeft,
        );

  bool collected = false;
  final Paint _fillPaint = Paint()..color = const Color(0xFFFFC857);
  final Paint _strokePaint = Paint()
    ..color = const Color(0xFFF4A261)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

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

    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.5);
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

class FloatingText extends TextComponent {
  FloatingText({
    required String text,
    required Vector2 position,
    required Color color,
  }) : super(
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
}
