import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../online.dart';
import 'home_screen.dart';

/// Вкладка «Заявки»: онлайн-приём заявок с сайта.
class OnlineTab extends StatefulWidget {
  final Tournament t;
  const OnlineTab({super.key, required this.t});

  @override
  State<OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends State<OnlineTab> {
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    if (onlineReady) {
      _authSub = authChanges.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!onlineConfigured) {
      return const _Info(
        icon: Icons.cloud_off,
        title: 'Онлайн-заявки не настроены',
        text: 'Укажите адрес и ключ Supabase в lib/config.dart и пересоберите приложение.',
      );
    }
    if (!onlineReady) {
      return const _Info(
        icon: Icons.wifi_off,
        title: 'Сервер недоступен',
        text: 'Не удалось подключиться при запуске. Проверьте интернет и перезапустите приложение.',
      );
    }
    if (currentUser == null) return const _LoginCard();
    if (widget.t.onlineId == null) return _PublishCard(t: widget.t);
    return _EntriesView(t: widget.t);
  }
}

// ───────────────────────── Вход ─────────────────────────

class _LoginCard extends StatefulWidget {
  const _LoginCard();

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function(String, String) fn) async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _msg = 'Введите почту и пароль');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final r = await fn(_email.text, _pass.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _msg = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Вход организатора',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Нужен один раз — чтобы принимать заявки тренеров через сайт.',
                style: TextStyle(color: c.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Почта', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Пароль (от 6 символов)',
                  border: OutlineInputBorder()),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, style: TextStyle(color: c.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => _run(signIn),
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Войти'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _run(signUp),
              child: const Text('Регистрация'),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ───────────────────────── Публикация ─────────────────────────

Future<DateTime?> pickDeadline(BuildContext context, DateTime initial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime(2100),
    helpText: 'Приём заявок до',
  );
  if (d == null || !context.mounted) return null;
  final tm = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: 'Время окончания приёма',
  );
  if (tm == null) return null;
  return DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
}

String fmtDateTime(DateTime d) =>
    '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _PublishCard extends StatefulWidget {
  final Tournament t;
  const _PublishCard({required this.t});

  @override
  State<_PublishCard> createState() => _PublishCardState();
}

class _PublishCardState extends State<_PublishCard> {
  late DateTime _deadline;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // по умолчанию — за день до турнира, 23:59
    final d = widget.t.date.subtract(const Duration(days: 1));
    _deadline = DateTime(d.year, d.month, d.day, 23, 59);
    if (_deadline.isBefore(DateTime.now())) {
      _deadline = DateTime.now().add(const Duration(days: 1));
    }
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await publishTournament(widget.t, _deadline);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть приём: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.public, size: 48, color: c.primary),
            const SizedBox(height: 12),
            const Text('Онлайн-приём заявок',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Приложение создаст ссылку на форму. Отправьте её тренерам — '
              'заявки будут появляться здесь, а потом одной кнопкой попадут в участники.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text('Приём до: ${fmtDateTime(_deadline)}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await pickDeadline(context, _deadline);
                if (d != null && mounted) setState(() => _deadline = d);
              },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              label: const Text('Открыть приём заявок'),
              onPressed: _busy ? null : _publish,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                if (await confirm(context, 'Выйти из аккаунта организатора?',
                    ok: 'Выйти')) {
                  await signOut();
                }
              },
              child: Text('Аккаунт: ${currentUser?.email ?? ''} · выйти'),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ───────────────────────── Заявки ─────────────────────────

class _EntriesView extends StatefulWidget {
  final Tournament t;
  const _EntriesView({required this.t});

  @override
  State<_EntriesView> createState() => _EntriesViewState();
}

class _EntriesViewState extends State<_EntriesView> {
  late Stream<List<Entry>> _stream;
  bool? _open;
  DateTime? _deadline;
  final _hidden = <String>{}; // удалённые, пока стрим не обновился

  @override
  void initState() {
    super.initState();
    _stream = entriesStream(widget.t);
    _loadRemote();
  }

  Future<void> _loadRemote() async {
    try {
      final r = await fetchRemoteTournament(widget.t);
      if (!mounted || r == null) return;
      setState(() {
        _open = r['is_open'] as bool?;
        _deadline = DateTime.tryParse(r['deadline'] as String? ?? '')?.toLocal();
      });
    } catch (_) {}
  }

  String get _link => linkFor(widget.t.onlineSlug!);

  String get _shareText => 'Заявки на турнир «${widget.t.name}» '
      '(${fmtDate(widget.t.date)}${widget.t.place.isNotEmpty ? ', ${widget.t.place}' : ''})'
      '${_deadline != null ? ' принимаются до ${fmtDateTime(_deadline!)}' : ''}:\n$_link';

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareText)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: _shareText));
      if (mounted) _snack('WhatsApp не открылся — текст скопирован');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final c = Theme.of(context).colorScheme;
    final closedByTime = _deadline != null && _deadline!.isBefore(DateTime.now());

    return StreamBuilder<List<Entry>>(
      stream: _stream,
      builder: (context, snap) {
        final all = (snap.data ?? const <Entry>[])
            .where((e) => !_hidden.contains(e.id))
            .toList();
        final fresh = all.where((e) => !isImported(t, e)).toList();

        // группировка по клубам
        final byClub = <String, List<Entry>>{};
        for (final e in all) {
          byClub.putIfAbsent(e.club.isEmpty ? '—' : e.club, () => []).add(e);
        }
        final clubs = byClub.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            // ссылка
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(Icons.link, color: c.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(_link,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Копировать'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _shareText));
                          if (mounted) _snack('Ссылка скопирована');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('WhatsApp'),
                        onPressed: _whatsapp,
                      ),
                    ),
                  ]),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Приём заявок открыт'),
                    subtitle: Text(_deadline == null
                        ? '…'
                        : closedByTime
                            ? 'Срок истёк ${fmtDateTime(_deadline!)}'
                            : 'До ${fmtDateTime(_deadline!)}'),
                    value: (_open ?? true) && !closedByTime,
                    onChanged: _open == null || closedByTime
                        ? null
                        : (v) async {
                            setState(() => _open = v);
                            try {
                              await setRemoteOpen(t, v);
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _open = !v);
                              _snack('Ошибка: $e');
                            }
                          },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Изменить срок приёма'),
                    onPressed: () async {
                      final d = await pickDeadline(
                          context, _deadline ?? DateTime.now().add(const Duration(days: 1)));
                      if (d == null) return;
                      try {
                        await setRemoteDeadline(t, d);
                        if (mounted) setState(() => _deadline = d);
                      } catch (e) {
                        if (mounted) _snack('Ошибка: $e');
                      }
                    },
                  ),
                ]),
              ),
            ),

            // импорт
            const SizedBox(height: 8),
            if (snap.hasError)
              Card(
                color: c.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Нет связи с сервером: ${snap.error}',
                      style: TextStyle(color: c.onErrorContainer)),
                ),
              )
            else if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              FilledButton.icon(
                icon: const Icon(Icons.group_add),
                label: Text(fresh.isEmpty
                    ? 'Новых заявок нет'
                    : 'Добавить в участники: ${fresh.length}'),
                onPressed: fresh.isEmpty
                    ? null
                    : () {
                        final n = importEntries(t, fresh);
                        _snack('Добавлено участников: $n. Откройте «Сетки» → «Сформировать».');
                        setState(() {});
                      },
              ),
              const SizedBox(height: 4),
              Text(
                'Всего заявок: ${all.length} · клубов: ${clubs.length}. '
                'Новые появляются автоматически.',
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                      child: Text('Пока никто не подал заявку',
                          textAlign: TextAlign.center)),
                ),
              for (final club in clubs) ...[
                const SizedBox(height: 12),
                _clubHeader(context, club, byClub[club]!),
                for (final e in byClub[club]!) _entryTile(context, e),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _clubHeader(BuildContext context, String club, List<Entry> list) {
    final c = Theme.of(context).colorScheme;
    final e = list.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$club${e.city.isNotEmpty ? ' (${e.city})' : ''}  ·  ${list.length}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text([e.coach, e.coachPhone].where((s) => s.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
      ]),
    );
  }

  Widget _entryTile(BuildContext context, Entry e) {
    final c = Theme.of(context).colorScheme;
    final done = isImported(widget.t, e);
    return ListTile(
      dense: true,
      leading: Icon(done ? Icons.check_circle : Icons.fiber_new,
          color: done ? Colors.green : c.primary),
      title: Row(children: [
        Flexible(child: Text(e.fullName, overflow: TextOverflow.ellipsis)),
        if (e.female) ...[
          const SizedBox(width: 6),
          Icon(Icons.female, size: 18, color: c.tertiary),
        ],
      ]),
      subtitle: Text('${e.birthYear} г.р. · ${fmtWeight(e.weight)} кг'
          '${done ? ' · в турнире' : ''}'),
      trailing: IconButton(
        tooltip: 'Удалить заявку',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          if (!await confirm(context,
              'Удалить заявку «${e.fullName}» с сервера?\nУчастника в турнире это не удалит.')) {
            return;
          }
          setState(() => _hidden.add(e.id));
          try {
            await deleteEntry(e.id);
          } catch (err) {
            if (!mounted) return;
            setState(() => _hidden.remove(e.id));
            _snack('Ошибка: $err');
          }
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Info({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: c.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
