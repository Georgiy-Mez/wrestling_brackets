import 'package:flutter/material.dart';

import '../categories.dart';
import '../draw.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../state.dart';
import 'bracket_view.dart';
import 'home_screen.dart';

class BracketScreen extends StatefulWidget {
  final String tournamentId;
  final String categoryKey;
  const BracketScreen(
      {super.key, required this.tournamentId, required this.categoryKey});

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  int? selected;

  String get key => widget.categoryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = app.byId(widget.tournamentId);
      if (t == null) return;
      final members = assign(t).members[key] ?? [];
      if (t.brackets[key] == null && members.length >= 2) {
        t.brackets[key] = drawBracket(members);
        app.save();
      }
    });
  }

  void _redraw(Tournament t, List<Participant> members) {
    t.brackets[key] = drawBracket(members);
    selected = null;
    app.save();
  }

  void _tap(Tournament t, int i) {
    final s = t.brackets[key]!;
    if (selected == null) {
      if (s[i] == null) return; // начинаем выбор только с участника
      setState(() => selected = i);
      return;
    }
    if (selected == i) {
      setState(() => selected = null);
      return;
    }
    final a = selected!;
    final tmp = s[i];
    s[i] = s[a];
    s[a] = tmp;
    setState(() => selected = null);
    app.save();
  }

  void _info(Tournament t, Participant? p, String? note) {
    if (p == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (p.team.isNotEmpty) Text('Команда: ${p.team}'),
            Text('Год рождения: ${p.birthYear} (${ageOf(p, t)} лет)'),
            Text('Вес: ${fmtWeight(p.weight)} кг'),
            if (p.female) const Text('Девушка'),
            if (note != null) Text(note),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final t = app.byId(widget.tournamentId);
        final cat = WeightCategory.fromKey(key);
        if (t == null || cat == null) return const Scaffold();
        final asg = assign(t);
        final members = asg.members[key] ?? [];
        final slots = t.brackets[key];
        final byId = t.byId;
        final sc = Theme.of(context).colorScheme;

        final fights = slots == null
            ? 0
            : List.generate(slots.length ~/ 2, (j) => j)
                .where((j) => slots[2 * j] != null && slots[2 * j + 1] != null)
                .length;
        final conflicts =
            slots == null ? <int>{} : conflictPairs(slots, byId).toSet();
        final stale = slots != null && !bracketMatches(slots, members);

        return Scaffold(
          appBar: AppBar(
            title: Text(cat.title),
            actions: [
              IconButton(
                tooltip: 'Пережеребить',
                icon: const Icon(Icons.shuffle),
                onPressed: members.length < 2
                    ? null
                    : () async {
                        final ok = await confirm(context,
                            'Провести жеребьёвку заново? Ручные правки этой сетки пропадут.',
                            ok: 'Пережеребить');
                        if (ok) _redraw(t, members);
                      },
              ),
              IconButton(
                tooltip: 'PDF',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: slots == null || members.length < 2
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfPreviewScreen(
                              title: cat.title,
                              fileName:
                                  'setka_${cat.group.id}_${cat.weightLabel.replaceAll(' ', '')}.pdf',
                              builder: () => buildBracketsPdf(t, [cat]),
                            ),
                          ),
                        ),
              ),
            ],
          ),
          body: members.length < 2
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      members.isEmpty
                          ? 'В категории нет участников'
                          : 'В категории один участник (${members.first.name}) и в возрастной группе больше никого нет — соперника нет.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : slots == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(children: [
                      if (stale)
                        _banner(
                          sc.errorContainer,
                          sc.onErrorContainer,
                          'Состав категории изменился (добавили/удалили/перевесили участника).',
                          'Пересоздать',
                          () => _redraw(t, members),
                        ),
                      if (!stale && conflicts.isNotEmpty)
                        _banner(
                          sc.errorContainer,
                          sc.onErrorContainer,
                          'Одноклубники встречаются в первой схватке (выделено красным).',
                          null,
                          null,
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Row(children: [
                          Text('Участников: ${members.length}  ·  схваток в 1-м круге: $fights',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          selected == null
                              ? 'Нажмите на участника, затем на другое место — они поменяются. Долгое нажатие — карточка участника.'
                              : 'Выбран: ${byId[slots[selected!]]?.name ?? ''}. Нажмите, куда переставить.',
                          style: TextStyle(
                              fontSize: 12,
                              color: selected == null
                                  ? sc.onSurfaceVariant
                                  : sc.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      Expanded(
                        child: InteractiveViewer(
                          constrained: false,
                          minScale: 0.25,
                          maxScale: 3,
                          boundaryMargin: const EdgeInsets.all(200),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: BracketView(
                              slots: slots,
                              byId: byId,
                              selected: selected,
                              conflictPairs: conflicts,
                              onTapSlot: (i) => _tap(t, i),
                              onLongPressSlot: (i) {
                                final id = slots[i];
                                _info(t, id == null ? null : byId[id],
                                    id == null ? null : asg.notes[id]);
                              },
                            ),
                          ),
                        ),
                      ),
                    ]),
        );
      },
    );
  }

  Widget _banner(Color bg, Color fg, String text, String? action,
      VoidCallback? onAction) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(children: [
        Icon(Icons.warning_amber, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: fg))),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action)),
      ]),
    );
  }
}
