import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar.dart';
import '../services/leaderboard_repository.dart';
import '../services/rewards.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/reward_feedback.dart';
import 'shell.dart';

/// Lleva al apartado de Recompensas desde cualquier pantalla.
void openRewards(BuildContext context) {
  context.read<AppState>().selectTab(AppTab.recompensas);
  Navigator.of(context).popUntil((r) => r.isFirst);
}

/// Apartado de gamificación: tu avatar, la tienda y el ranking.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recompensas'),
          actions: [
            IconButton(
              tooltip: '¿Cómo gano bellotas?',
              onPressed: () => showRewardsHelp(context),
              icon: const Icon(Icons.help_outline_rounded),
            ),
            const ProfileButton(),
          ],
        ),
        body: const Column(
          children: [
            Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 4), child: _Header()),
            TabBar(
              tabs: [
                Tab(icon: Icon(Icons.checkroom_rounded), text: 'Mi avatar'),
                Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Ranking'),
              ],
            ),
            Expanded(child: TabBarView(children: [_Shop(), _Ranking()])),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final nickname = state.account?.nickname;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AvatarView(state.avatar, size: 100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nickname != null)
                    Text(
                      '@$nickname',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  Text('Nivel ${state.level}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: state.levelProgress),
                      duration: const Duration(milliseconds: 700),
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Faltan ${state.toNextLevel} para el nivel ${state.level + 1}', style: t.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Pill(
                        icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B83D)),
                        text: '${state.points} pts',
                      ),
                      _Pill(icon: const BellotaIcon(size: 15), text: '${state.bellotas}'),
                      _Pill(
                        icon: Icon(Icons.local_fire_department_rounded, size: 16, color: c.creative),
                        text: '${state.streakDays} ${state.streakDays == 1 ? 'día' : 'días'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ],
    ),
  );
}

// ---------------- Tienda ----------------

class _Shop extends StatefulWidget {
  const _Shop();

  @override
  State<_Shop> createState() => _ShopState();
}

class _ShopState extends State<_Shop> {
  AvatarSlot _slot = AvatarSlot.animal;

  @override
  Widget build(BuildContext context) {
    final items = AvatarCatalog.ofSlot(_slot);
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            children: [
              for (final slot in AvatarSlot.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(slot.label),
                    selected: slot == _slot,
                    onSelected: (_) => setState(() => _slot = slot),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisExtent: 156,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _ItemCard(items[i]),
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard(this.item);
  final AvatarItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final owned = state.owns(item);
    final equipped = state.isEquipped(item);
    final locked = !owned && state.isLocked(item);

    final Widget status;
    if (equipped) {
      status = _Status(Icons.check_circle_rounded, item.slot.optional ? 'Puesto · quitar' : 'Puesto', c.success);
    } else if (owned) {
      status = _Status(null, 'Tuyo · ponerlo', scheme.primary);
    } else if (locked) {
      status = _Status(Icons.lock_rounded, 'Nivel ${item.level}', scheme.onSurfaceVariant);
    } else {
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BellotaIcon(size: 16),
          const SizedBox(width: 3),
          Text(
            '${item.price}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: state.bellotas >= item.price ? c.creative : scheme.error,
            ),
          ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: equipped ? c.success : Colors.transparent, width: 2.5),
      ),
      child: InkWell(
        onTap: () => owned ? state.toggleEquip(item) : _showBuyDialog(context, item),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Opacity(
                opacity: locked ? .45 : 1,
                child: AvatarView(state.avatar.withItem(item.slot, item.id), size: 84),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.1),
              ),
              const Spacer(),
              status,
            ],
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.icon, this.text, this.color);
  final IconData? icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 3)],
      Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    ],
  );
}

Future<void> _showBuyDialog(BuildContext context, AvatarItem item) async {
  final state = context.read<AppState>();
  final locked = state.isLocked(item);
  final missing = item.price - state.bellotas;
  final String? reason = locked
      ? 'Se desbloquea en el nivel ${item.level}. Sigue estudiando y completando tareas para subir de nivel.'
      : missing > 0
      ? 'Te faltan $missing bellotas. Completa un ciclo de estudio o una tarea para ganarlas.'
      : null;
  final bought = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(item.name, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarView(state.avatar.withItem(item.slot, item.id), size: 150),
          if (item.hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BellotaIcon(size: 22),
              const SizedBox(width: 4),
              Text('${item.price} bellotas', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          if (reason != null) ...[const SizedBox(height: 8), Text(reason, textAlign: TextAlign.center)],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
        FilledButton(
          onPressed: reason != null ? null : () => Navigator.pop(ctx, state.buyItem(item)),
          child: const Text('COMPRAR'),
        ),
      ],
    ),
  );
  if (bought == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('¡Listo! Ya tienes ${item.name} y te lo pusimos.')));
  }
}

// ---------------- Ranking ----------------

class _Ranking extends StatefulWidget {
  const _Ranking();

  @override
  State<_Ranking> createState() => _RankingState();
}

class _RankingState extends State<_Ranking> {
  LeaderboardPeriod _period = LeaderboardPeriod.semana;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final board = state.leaderboard;
    if (board == null) {
      return const Center(child: Text('Inicia sesión para ver el ranking.'));
    }
    final myId = state.account?.id;
    return FutureBuilder<List<LeaderboardEntry>>(
      // Se vuelve a pedir cuando cambian tus puntos o el periodo.
      key: ValueKey('${_period.name}-${state.points}-${state.avatar}'),
      future: board.fetch(_period),
      builder: (context, snap) {
        final list = snap.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Center(
              child: SegmentedButton<LeaderboardPeriod>(
                showSelectedIcon: false,
                segments: [for (final p in LeaderboardPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            ),
            const SizedBox(height: 12),
            if (list == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _MyPosition(list: list, myId: myId, period: _period),
              const SizedBox(height: 12),
              _Podium(top: list.take(3).toList(), myId: myId, period: _period),
              const SizedBox(height: 8),
              for (var i = 3; i < list.length; i++)
                _RankRow(rank: i + 1, entry: list[i], me: list[i].accountId == myId, period: _period),
              const SizedBox(height: 12),
              Text(
                'Los puntos son las bellotas que ganas estudiando y cumpliendo tareas (gastarlas no te quita puntos). '
                'Mientras conectamos la base de datos, el ranking muestra las cuentas de este celular y estudiantes de ejemplo.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MyPosition extends StatelessWidget {
  const _MyPosition({required this.list, required this.myId, required this.period});
  final List<LeaderboardEntry> list;
  final String? myId;
  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final i = list.indexWhere((e) => e.accountId == myId);
    if (i < 0) return const SizedBox.shrink();
    final me = list[i];
    final scheme = Theme.of(context).colorScheme;
    final String message;
    if (i == 0) {
      message = '¡Vas de primero! Sigue así para no perder la corona.';
    } else {
      final ahead = list[i - 1];
      final gap = ahead.pointsFor(period) - me.pointsFor(period) + 1;
      message = 'Te faltan $gap puntos para pasar a @${ahead.nickname}.';
    }
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              '#${i + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu posición · ${me.pointsFor(period)} pts',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  Text(message, style: TextStyle(color: Colors.white.withValues(alpha: .9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.myId, required this.period});
  final List<LeaderboardEntry> top;
  final String? myId;
  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    // Orden visual: 2.º, 1.º, 3.º
    const order = [1, 0, 2];
    const heights = [92.0, 64.0, 44.0];
    const colors = [Color(0xFFFFC93C), Color(0xFFC9CED6), Color(0xFFE0A16A)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(
            child: i >= top.length
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      if (i == 0) const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFC93C), size: 28),
                      AvatarView(top[i].avatar, size: i == 0 ? 88 : 72),
                      const SizedBox(height: 4),
                      Text(
                        '@${top[i].nickname}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: top[i].accountId == myId ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      Text('${top[i].pointsFor(period)} pts', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        height: heights[i],
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: colors[i],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border.all(color: const Color(0xFF2B2433), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF2B2433)),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry, required this.me, required this.period});
  final int rank;
  final LeaderboardEntry entry;
  final bool me;
  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: me ? scheme.primaryContainer : null,
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 82,
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              AvatarView(entry.avatar, size: 42),
            ],
          ),
        ),
        title: Text(
          '@${entry.nickname}${me ? ' (tú)' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: entry.demo ? const Text('Estudiante de ejemplo') : null,
        trailing: Text('${entry.pointsFor(period)} pts', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Explica cómo se ganan bellotas, los puntos y los niveles.
Future<void> showRewardsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Row(
      children: [
        BellotaIcon(size: 26),
        SizedBox(width: 8),
        Expanded(child: Text('¿Cómo gano bellotas?')),
      ],
    ),
    content: const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Rule('Ciclo completo (Pomodoro o Flowtime)', '+${Rewards.cycle}'),
          _Rule('Cada ${Rewards.focusMinutesPerBellota} min de enfoque', '+1'),
          _Rule('Tarea completada', '+${Rewards.task}'),
          _Rule('…y entregada a tiempo', '+${Rewards.taskOnTime}'),
          _Rule(
            'Racha: tu primer ciclo del día da ${Rewards.streakPerDay} por cada día seguido',
            'hasta +${Rewards.streakMax}',
          ),
          SizedBox(height: 10),
          Text(
            'El ciclo solo da bellotas si el enfoque duró al menos ${Rewards.minCycleFocusMinutes} minutos, '
            'y cada tarea paga una sola vez aunque la desmarques y la vuelvas a marcar.\n\n'
            'Cada bellota ganada también es un punto del ranking. Gastarlas en la tienda no te quita puntos ni '
            'te baja de nivel (subes uno cada ${Rewards.perLevel} puntos). Algunos animales, disfraces y '
            'efectos piden un nivel mínimo.',
          ),
        ],
      ),
    ),
    actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
  ),
);

class _Rule extends StatelessWidget {
  const _Rule(this.text, this.amount);
  final String text;
  final String amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(text)),
        const SizedBox(width: 8),
        Text(
          amount,
          style: TextStyle(fontWeight: FontWeight.w900, color: context.colors.creative),
        ),
      ],
    ),
  );
}
