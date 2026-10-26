import 'package:flutter/material.dart';

import '../services/rewards.dart';

/// Bellota en pixel art (la moneda de la tienda del avatar).
class BellotaIcon extends StatelessWidget {
  const BellotaIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _BellotaPainter()),
  );
}

class _BellotaPainter extends CustomPainter {
  const _BellotaPainter();

  static const _rows = [
    '.....kk.....',
    '....kk......',
    '..kkkkkkkk..',
    '.kCCCCCCCCk.',
    '.kCcCcCcCCk.',
    '..kkkkkkkk..',
    '..kNNNNNNk..',
    '..kNwNNNNk..',
    '..kNwNNNNk..',
    '...kNNNNk...',
    '....kNNk....',
    '.....kk.....',
  ];
  static const _colors = {
    'k': Color(0xFF2B2433),
    'C': Color(0xFF8B5A33),
    'c': Color(0xFF6E4426),
    'N': Color(0xFFE0954B),
    'w': Color(0xFFFFE3C2),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / _rows.length;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < _rows.length; y++) {
      for (var x = 0; x < _rows[y].length; x++) {
        final c = _colors[_rows[y][x]];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell * 1.04, cell * 1.04), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BellotaPainter old) => false;
}

/// "+N bellotas" con su ícono, para la pantalla de logro y los avisos.
class RewardBadge extends StatelessWidget {
  const RewardBadge(this.reward, {super.key});
  final Reward reward;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF8B5A33));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .4, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFFFE9C7), borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BellotaIcon(size: 22),
            const SizedBox(width: 6),
            Text('+${reward.bellotas} bellotas', style: style),
            if (reward.streakBonus > 0) Text('  +${reward.streakBonus} por racha', style: style.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Aviso con las bellotas ganadas (y si se subió de nivel).
void showRewardSnack(BuildContext context, Reward reward, {required String message, SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        action: action,
        content: Row(
          children: [
            if (!reward.isEmpty) ...[const BellotaIcon(size: 22), const SizedBox(width: 8)],
            Expanded(
              child: Text(
                [
                  message,
                  if (!reward.isEmpty) '+${reward.total} bellotas.',
                  if (reward.newLevel != null) '¡Subiste a nivel ${reward.newLevel}!',
                ].join(' '),
              ),
            ),
          ],
        ),
      ),
    );
}
