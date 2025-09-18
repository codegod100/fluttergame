import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'cute_platformer_game.dart';

class CuteHud extends StatefulWidget {
  const CuteHud({super.key, required this.game});

  final CutePlatformerGame game;

  @override
  State<CuteHud> createState() => _CuteHudState();
}

class _CuteHudState extends State<CuteHud> {
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
    return SizedBox.expand(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge([widget.game.score, widget.game.coins]),
                builder: (_, __) {
                  final stars = widget.game.score.value;
                  final totalStars = widget.game.totalStars;
                  final coinCount = widget.game.coins.value;
                  final totalCoins = widget.game.totalCoins;
                  final coinSegment = totalCoins > 0
                      ? ' • Coins: $coinCount / $totalCoins'
                      : '';
                  return Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Level ${widget.game.currentLevel + 1}/${widget.game.levelCount} • '
                      'Stars: $stars / $totalStars$coinSegment',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3A0CA3),
                      ),
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
                valueListenable: widget.game.score,
                builder: (_, score, __) {
                  final totalStars = widget.game.totalStars;
                  if (totalStars == 0 || score < totalStars) {
                    return const SizedBox.shrink();
                  }
                  final isLastLevel =
                      widget.game.currentLevel >= widget.game.levelCount - 1;
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
                        onPressed: () {
                          widget.game.resetLevel();
                        },
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
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;
                  if (isCompact) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ControlButton(
                              label: '<',
                              pressed: _leftDown,
                              onChanged: (value) {
                                setState(() => _leftDown = value);
                                widget.game.setLeftPressed(value);
                              },
                            ),
                            const SizedBox(width: 16),
                            _ControlButton(
                              label: '>',
                              pressed: _rightDown,
                              onChanged: (value) {
                                setState(() => _rightDown = value);
                                widget.game.setRightPressed(value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ControlButton(
                          label: 'Jump',
                          pressed: _jumpDown,
                          wide: true,
                          onChanged: (value) {
                            setState(() => _jumpDown = value);
                            if (value) {
                              widget.game.triggerJump();
                            }
                          },
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _ControlButton(
                            label: '<',
                            pressed: _leftDown,
                            onChanged: (value) {
                              setState(() => _leftDown = value);
                              widget.game.setLeftPressed(value);
                            },
                          ),
                          const SizedBox(width: 16),
                          _ControlButton(
                            label: '>',
                            pressed: _rightDown,
                            onChanged: (value) {
                              setState(() => _rightDown = value);
                              widget.game.setRightPressed(value);
                            },
                          ),
                        ],
                      ),
                      _ControlButton(
                        label: 'Jump',
                        pressed: _jumpDown,
                        wide: true,
                        onChanged: (value) {
                          setState(() => _jumpDown = value);
                          if (value) {
                            widget.game.triggerJump();
                          }
                        },
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

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.label,
    required this.onChanged,
    this.pressed = false,
    this.wide = false,
  });

  final String label;
  final ValueChanged<bool> onChanged;
  final bool pressed;
  final bool wide;

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
          horizontal: widget.wide ? 28 : 18,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: _isPressed ? const Color(0xFF5E60CE) : const Color(0xFFBBD0FF),
          borderRadius: BorderRadius.circular(18),
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
            fontSize: widget.wide ? 16 : 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
