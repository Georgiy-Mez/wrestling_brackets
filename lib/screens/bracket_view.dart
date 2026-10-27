import 'package:flutter/material.dart';

import '../layout.dart';
import '../models.dart';

/// Отрисовка сетки. Слоты 1-й колонки кликабельны (для обмена местами).
class BracketView extends StatelessWidget {
  final List<String?> slots;
  final Map<String, Participant> byId;
  final int? selected;
  final Set<int> conflictPairs;
  final void Function(int slot)? onTapSlot;
  final void Function(int slot)? onLongPressSlot;

  const BracketView({
    super.key,
    required this.slots,
    required this.byId,
    this.selected,
    this.conflictPairs = const {},
    this.onTapSlot,
    this.onLongPressSlot,
  });

  @override
  Widget build(BuildContext context) {
    final g = BracketGeometry(slots.length, slots);
    final sc = Theme.of(context).colorScheme;
    final children = <Widget>[];

    for (var k = 0; k <= g.rounds; k++) {
      children.add(Positioned(
        left: g.cols[k].first.x,
        top: 0,
        width: g.boxW,
        child: Text(
          roundTitle(k, g.rounds),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w700, color: sc.primary, fontSize: 13),
        ),
      ));
    }

    for (final s in g.lines) {
      children.add(Positioned(
        left: s.x,
        top: s.y,
        width: s.w,
        height: s.h,
        child: ColoredBox(color: sc.outline),
      ));
    }

    for (final l in g.labels) {
      children.add(Positioned(
        left: l.x + 3,
        top: l.y - 15,
        child: Text('№${l.number}',
            style: TextStyle(fontSize: 10, color: sc.onSurfaceVariant)),
      ));
    }

    for (var k = 0; k <= g.rounds; k++) {
      for (var j = 0; j < g.cols[k].length; j++) {
        final pos = g.cols[k][j];
        final id = shownId(k, j, slots);
        final p = id == null ? null : byId[id];
        final isSlot = k == 0;
        final isSel = isSlot && selected == j;
        final isConf = isSlot && conflictPairs.contains(j ~/ 2);

        Color border = sc.outlineVariant;
        double bw = 1;
        Color bg = sc.surface;
        if (isConf) {
          border = sc.error;
          bw = 1.6;
          bg = sc.errorContainer.withAlpha(90);
        }
        if (isSel) {
          border = sc.primary;
          bw = 2.4;
          bg = sc.primaryContainer;
        }
        if (k == g.rounds && g.rounds > 0) bg = sc.tertiaryContainer.withAlpha(102);

        children.add(Positioned(
          left: pos.x,
          top: pos.y,
          width: g.boxW,
          height: g.boxH,
          child: GestureDetector(
            onTap: isSlot ? () => onTapSlot?.call(j) : null,
            onLongPress: isSlot ? () => onLongPressSlot?.call(j) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border, width: bw),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.centerLeft,
              child: p == null
                  ? (isSlot
                      ? Text('— свободно —',
                          style: TextStyle(
                              fontSize: 11, color: sc.onSurfaceVariant))
                      : const SizedBox.shrink())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                        if (p.team.isNotEmpty)
                          Text(p.team,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: sc.onSurfaceVariant)),
                      ],
                    ),
            ),
          ),
        ));
      }
    }

    return SizedBox(
      width: g.width + 24,
      height: g.height + 8,
      child: Stack(children: children),
    );
  }
}
