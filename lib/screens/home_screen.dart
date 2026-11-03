import 'package:flutter/material.dart';

import '../models.dart';
import '../online.dart';
import '../state.dart';
import 'tournament_edit_screen.dart';
import 'tournament_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.tournaments;
        return Scaffold(
          appBar: AppBar(title: const Text('Сетки по борьбе')),
          body: list.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.emoji_events_outlined)),
                        title: Text(t.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          fmtDate(t.date),
                          if (t.place.isNotEmpty) t.place,
                          'участников: ${t.participants.length}',
                        ].join(' · ')),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TournamentScreen(id: t.id)),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              showTournamentDialog(context, existing: t);
                            } else if (v == 'delete') {
                              final ok = await confirm(context,
                                  'Удалить турнир «${t.name}» со всеми участниками и сетками?');
                              if (ok) {
                                deleteRemoteTournament(t);
                                app.remove(t);
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Изменить')),
                            PopupMenuItem(value: 'delete', child: Text('Удалить')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showTournamentDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Турнир'),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_kabaddi, size: 72, color: c.primary),
          const SizedBox(height: 16),
          const Text('Пока нет турниров',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Создайте турнир, внесите участников —\nприложение само разложит их по категориям и сделает сетки.',
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String text,
    {String ok = 'Удалить'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// Открывает экран создания / редактирования турнира.
Future<void> showTournamentDialog(BuildContext context,
    {Tournament? existing}) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
        builder: (_) => TournamentEditScreen(existing: existing)),
  );
}
