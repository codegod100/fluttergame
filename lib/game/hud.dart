import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'cute_platformer_game.dart';

class CuteHud extends StatelessWidget {
  const CuteHud({super.key, required this.game});

  final CutePlatformerGame game;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  game.score,
                  game.coins,
                  game.lives,
                ]),
                builder: (_, __) {
                  final stars = game.score.value;
                  final totalStars = game.totalStars;
                  final coinCount = game.coins.value;
                  final totalCoins = game.totalCoins;
                  final coinSegment =
                      totalCoins > 0 ? ' • Coins: $coinCount / $totalCoins' : '';
                  final livesRemaining = game.lives.value;
                  final maxLives = game.maxLives;

                  return Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Level ${game.currentLevel + 1}/${game.levelCount} • '
                          'Stars: $stars / $totalStars$coinSegment',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A0CA3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(maxLives, (index) {
                            final isFilled = index < livesRemaining;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Icon(
                                Icons.favorite,
                                size: 18,
                                color: isFilled
                                    ? const Color(0xFFE63946)
                                    : const Color(0xFFE1E1E1),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(top: 110),
              child: ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (_, score, __) {
                  final totalStars = game.totalStars;
                  if (totalStars == 0 || score < totalStars) {
                    return const SizedBox.shrink();
                  }
                  final isLastLevel = game.currentLevel >= game.levelCount - 1;
                  if (!isLastLevel) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB388EB).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Level complete! Next stage is on the way...'
                        '\n(Press R to restart if you need a do-over)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB388EB).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'All levels complete! Press R or tap restart to begin again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: game.resetLevel,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5E60CE),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Restart Adventure'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CuteControlsPanel extends StatefulWidget {
  const CuteControlsPanel({super.key, required this.game});

  final CutePlatformerGame game;

  @override
  State<CuteControlsPanel> createState() => _CuteControlsPanelState();
}

class _CuteControlsPanelState extends State<CuteControlsPanel> {
  bool _leftDown = false;
  bool _rightDown = false;
  bool _jumpDown = false;

  @override
  void dispose() {
    widget.game
      ..setLeftPressed(false)
      ..setRightPressed(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controlScale = (constraints.maxWidth / 540).clamp(0.7, 1.0);
          final spacingBase = constraints.maxWidth < 420 ? 18.0 : 28.0;
          final spacing = spacingBase * controlScale;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ControlButton(
                      label: '<',
                      pressed: _leftDown,
                      scale: controlScale,
                      onChanged: (value) {
                        setState(() => _leftDown = value);
                        widget.game.setLeftPressed(value);
                      },
                    ),
                    SizedBox(width: spacing),
                    _ControlButton(
                      label: '>',
                      pressed: _rightDown,
                      scale: controlScale,
                      onChanged: (value) {
                        setState(() => _rightDown = value);
                        widget.game.setRightPressed(value);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ControlButton(
                    label: 'Jump',
                    pressed: _jumpDown,
                    wide: true,
                    scale: controlScale,
                    onChanged: (value) {
                      setState(() => _jumpDown = value);
                      if (value) {
                        widget.game.triggerJump();
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.label,
    required this.onChanged,
    this.pressed = false,
    this.wide = false,
    this.scale = 1.0,
  });

  final String label;
  final ValueChanged<bool> onChanged;
  final bool pressed;
  final bool wide;
  final double scale;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  late bool _isPressed;

  @override
  void initState() {
    super.initState();
    _isPressed = widget.pressed;
  }

  @override
  void didUpdateWidget(covariant _ControlButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressed != widget.pressed) {
      _isPressed = widget.pressed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveScale = widget.scale.clamp(0.6, 1.2).toDouble();
    final horizontalPadding = (widget.wide ? 42.0 : 34.0) * effectiveScale;
    final verticalPadding = (widget.wide ? 26.0 : 30.0) * effectiveScale;
    final minWidth = (widget.wide ? 180.0 : 96.0) * effectiveScale;
    final minHeight = 88.0 * effectiveScale;
    final borderRadius = 24.0 * effectiveScale;
    final fontSize = (widget.wide ? 20.0 : 30.0) * effectiveScale;

    return Listener(
      onPointerDown: (_) {
        if (!_isPressed) {
          setState(() => _isPressed = true);
          widget.onChanged(true);
        }
      },
      onPointerUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
          widget.onChanged(false);
        }
      },
      onPointerCancel: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
          widget.onChanged(false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        constraints: BoxConstraints(
          minWidth: minWidth,
          minHeight: minHeight,
        ),
        decoration: BoxDecoration(
          color: _isPressed ? const Color(0xFF5E60CE) : const Color(0xFFBBD0FF),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: _isPressed
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 8),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _isPressed ? Colors.white : const Color(0xFF3A0CA3),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
