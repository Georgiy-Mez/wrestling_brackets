import 'package:flutter/material.dart';

import '../categories.dart';
import '../draw.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../state.dart';
import 'bracket_screen.dart';
import 'home_screen.dart';
import 'participant_form.dart';

class TournamentScreen extends StatelessWidget {
  final String id;
  const TournamentScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final t = app.byId(id);
        if (t == null) return const Scaffold();
        final asg = assign(t);
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t.name),
              actions: [
                IconButton(
                  tooltip: 'Изменить турнир',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showTournamentDialog(context, existing: t),
                ),
              ],
              bottom: TabBar(tabs: [
                Tab(text: 'Участники (${t.participants.length})'),
                Tab(text: 'Сетки (${asg.members.length})'),
              ]),
            ),
            body: TabBarView(children: [
              _ParticipantsTab(t: t, asg: asg),
              _BracketsTab(t: t, asg: asg),
            ]),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Участники ─────────────────────────

class _ParticipantsTab extends StatefulWidget {
  final Tournament t;
  final Assignment asg;
  const _ParticipantsTab({required this.t, required this.asg});

  @override
  State<_ParticipantsTab> createState() => _ParticipantsTabState();
}

class _ParticipantsTabState extends State<_ParticipantsTab> {
  String query = '';

  bool _match(Participant p) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return p.name.toLowerCase().contains(q) || p.teamKey.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t, asg = widget.asg;
    final sections = <Widget>[];

    for (final c in asg.categories) {
      final list = asg.members[c.key]!.where(_match).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (list.isEmpty) continue;
      sections.add(_header(context, c.title, asg.members[c.key]!.length));
      sections.addAll(list.map((p) => _tile(context, t, p, asg.notes[p.id])));
    }
    final un = asg.unassigned.where(_match).toList();
    if (un.isNotEmpty) {
      sections.add(_header(context, 'Вне возрастных групп', un.length,
          warn: true));
      sections.addAll(un.map((p) => _tile(context, t, p, null)));
    }

    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск по ФИО или команде',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => query = v.trim()),
          ),
        ),
        Expanded(
          child: t.participants.isEmpty
              ? const Center(
                  child: Text('Добавьте участников кнопкой ниже',
                      textAlign: TextAlign.center))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: sections,
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ParticipantForm(tournamentId: t.id)),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Участник'),
      ),
    );
  }

  Widget _header(BuildContext context, String title, int count,
      {bool warn = false}) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: warn ? c.errorContainer : c.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text('$title  ·  $count',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: warn ? c.onErrorContainer : c.onSurface)),
    );
  }

  Widget _tile(BuildContext context, Tournament t, Participant p, String? note) {
    final c = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: c.onError),
      ),
      confirmDismiss: (_) => confirm(context, 'Удалить ${p.name}?'),
      onDismissed: (_) {
        t.participants.removeWhere((x) => x.id == p.id);
        app.save();
      },
      child: ListTile(
        title: Row(children: [
          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
          if (p.female) ...[
            const SizedBox(width: 6),
            Icon(Icons.female, size: 18, color: c.tertiary),
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([
            if (p.team.isNotEmpty) p.team,
            '${p.birthYear} г.р. (${ageOf(p, t)} л.)',
            '${fmtWeight(p.weight)} кг',
          ].join(' · ')),
          if (note != null)
            Text(note, style: TextStyle(color: c.tertiary, fontSize: 12)),
        ]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ParticipantForm(tournamentId: t.id, participantId: p.id)),
        ),
      ),
    );
  }
}

// ───────────────────────── Сетки ─────────────────────────

class _BracketsTab extends StatelessWidget {
  final Tournament t;
  final Assignment asg;
  const _BracketsTab({required this.t, required this.asg});

  /// Создаёт сетки там, где их нет или состав изменился. Ручные правки не трогает.
  int _generateMissing() {
    var made = 0;
    for (final c in asg.categories) {
      final members = asg.members[c.key]!;
      if (!bracketMatches(t.brackets[c.key], members)) {
        t.brackets[c.key] = drawBracket(members);
        made++;
      }
    }
    if (made > 0) app.save();
    return made;
  }

  @override
  Widget build(BuildContext context) {
    final cats = asg.categories;
    final byId = t.byId;
    final sc = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Сформировать'),
              onPressed: cats.isEmpty
                  ? null
                  : () {
                      final n = _generateMissing();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(n == 0
                              ? 'Все сетки уже актуальны'
                              : 'Сформировано сеток: $n')));
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF всех'),
              onPressed: cats.isEmpty
                  ? null
                  : () {
                      _generateMissing();
                      final printable = cats
                          .where((c) => asg.members[c.key]!.length >= 2)
                          .toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewScreen(
                            title: 'Все сетки',
                            fileName: 'setki_${fmtDate(t.date)}.pdf',
                            builder: () => buildBracketsPdf(t, printable),
                          ),
                        ),
                      );
                    },
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '«Сформировать» создаёт только новые и изменившиеся сетки — ручные правки сохраняются.',
          style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant),
        ),
        if (asg.unassigned.isNotEmpty)
          Card(
            color: sc.errorContainer,
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Вне возрастных групп: ${asg.unassigned.length} чел. — проверьте год рождения.',
                style: TextStyle(color: sc.onErrorContainer),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (cats.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('Нет участников')),
          ),
        for (final c in cats) _catTile(context, c, byId, sc),
      ],
    );
  }

  Widget _catTile(BuildContext context, WeightCategory c,
      Map<String, Participant> byId, ColorScheme sc) {
    final members = asg.members[c.key]!;
    final slots = t.brackets[c.key];
    String status;
    Color color;
    IconData icon;

    if (members.length < 2) {
      status = 'Нет соперника';
      color = sc.onSurfaceVariant;
      icon = Icons.person_off_outlined;
    } else if (slots == null) {
      status = 'Сетка не сформирована';
      color = sc.onSurfaceVariant;
      icon = Icons.grid_off;
    } else if (!bracketMatches(slots, members)) {
      status = 'Состав изменился — пересоздайте';
      color = sc.error;
      icon = Icons.sync_problem;
    } else if (conflictPairs(slots, byId).isNotEmpty) {
      status = 'Одноклубники в 1-й схватке';
      color = sc.error;
      icon = Icons.warning_amber;
    } else {
      status = 'Готова';
      color = Colors.green;
      icon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${members.length}')),
        title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(status, style: TextStyle(color: color))),
        ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  BracketScreen(tournamentId: t.id, categoryKey: c.key)),
        ),
      ),
    );
  }
}
