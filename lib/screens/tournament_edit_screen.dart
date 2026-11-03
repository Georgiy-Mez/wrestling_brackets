import 'package:flutter/material.dart';

import '../models.dart';
import '../online.dart';
import '../state.dart';

/// Создание / редактирование турнира: название, место, дата,
/// возрастные группы и весовые категории.
class TournamentEditScreen extends StatefulWidget {
  final Tournament? existing;
  const TournamentEditScreen({super.key, this.existing});

  @override
  State<TournamentEditScreen> createState() => _TournamentEditScreenState();
}

class _GroupDraft {
  final String id;
  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController weights;
  String? error;

  _GroupDraft(this.id, {int? minAge, int? maxAge, List<double>? w})
      : min = TextEditingController(text: minAge?.toString() ?? ''),
        max = TextEditingController(text: maxAge?.toString() ?? ''),
        weights = TextEditingController(
            text: (w ?? const []).map(fmtWeight).join(', '));

  factory _GroupDraft.of(AgeGroup g, {bool keepId = true}) => _GroupDraft(
      keepId ? g.id : newId(),
      minAge: g.minAge,
      maxAge: g.maxAge,
      w: g.weights);

  void dispose() {
    min.dispose();
    max.dispose();
    weights.dispose();
  }
}

/// «27, 31, 36» → [27, 31, 36]. Дробные — через точку: 41.5
List<double>? parseWeights(String s) {
  final parts = s.split(RegExp(r'[,;\s]+')).where((e) => e.isNotEmpty);
  final res = <double>{};
  for (final p in parts) {
    final v = double.tryParse(p);
    if (v == null || v <= 0 || v > 300) return null;
    res.add(v);
  }
  return res.toList()..sort();
}

class _TournamentEditScreenState extends State<TournamentEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _place;
  late DateTime _date;
  final List<_GroupDraft> _groups = [];
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _date = e?.date ?? DateTime.now();
    if (e != null) _groups.addAll(e.ageGroups.map(_GroupDraft.of));
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  void _fill(List<AgeGroup> src) {
    setState(() {
      for (final g in _groups) {
        g.dispose();
      }
      _groups
        ..clear()
        ..addAll(src.map((g) => _GroupDraft.of(g, keepId: false)));
    });
  }

  void _addGroup() {
    int? from;
    if (_groups.isNotEmpty) {
      final last = int.tryParse(_groups.last.max.text.trim());
      if (last != null) from = last + 1;
    }
    setState(() => _groups.add(_GroupDraft(newId(), minAge: from)));
  }

  /// Проверяет черновик и возвращает готовые группы (или null при ошибке).
  List<AgeGroup>? _validate() {
    var ok = true;
    final res = <AgeGroup>[];
    for (final d in _groups) {
      d.error = null;
      final mn = int.tryParse(d.min.text.trim());
      final mxText = d.max.text.trim();
      final mx = mxText.isEmpty ? null : int.tryParse(mxText);
      final w = parseWeights(d.weights.text);
      if (mn == null || mn < 3 || mn > 99) {
        d.error = 'Укажите возраст «от» (3–99)';
      } else if (mxText.isNotEmpty && (mx == null || mx < mn || mx > 99)) {
        d.error = 'Возраст «до» должен быть не меньше «от»';
      } else if (w == null) {
        d.error = 'Веса — числа через запятую, дробные через точку: 41.5';
      } else if (w.isEmpty) {
        d.error = 'Укажите хотя бы одну весовую категорию';
      }
      if (d.error != null) {
        ok = false;
        continue;
      }
      res.add(AgeGroup(id: d.id, minAge: mn!, maxAge: mx, weights: w!));
    }
    if (!ok) return null;

    // пересечения возрастов
    res.sort((a, b) => a.minAge.compareTo(b.minAge));
    for (var i = 0; i + 1 < res.length; i++) {
      final a = res[i], b = res[i + 1];
      if (a.maxAge == null || a.maxAge! >= b.minAge) {
        _error = 'Группы «${a.title}» и «${b.title}» пересекаются по возрасту';
        return null;
      }
    }
    return res;
  }

  void _save() {
    setState(() => _error = null);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Введите название турнира');
      return;
    }
    if (_groups.isEmpty) {
      setState(() => _error = 'Добавьте хотя бы одну возрастную группу');
      return;
    }
    final groups = _validate();
    if (groups == null) {
      setState(() {});
      return;
    }

    final e = widget.existing;
    if (e == null) {
      app.add(Tournament(
        id: newId(),
        name: _name.text.trim(),
        date: _date,
        place: _place.text.trim(),
        ageGroups: groups,
      ));
    } else {
      e
        ..name = _name.text.trim()
        ..place = _place.text.trim()
        ..date = _date
        ..ageGroups = groups;
      app.save();
      pushTournamentInfo(e);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final others =
        app.tournaments.where((t) => t.id != widget.existing?.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Новый турнир' : 'Турнир'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: _name,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Место проведения'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('Дата: ${fmtDate(_date)}'),
            subtitle: const Text('Возраст считается по году турнира'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null && mounted) setState(() => _date = d);
            },
          ),
          const Divider(height: 24),
          Text('Возрастные группы и веса',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Веса — верхние границы через запятую. Тяжелее последнего веса '
            'автоматически будет категория «N+ кг». Поле «до» пустое — «и старше».',
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Заполнить по положению'),
              onPressed: () => _fill(builtInAgeGroups()),
            ),
            if (others.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: Text('Как в «${others.first.name}»',
                    overflow: TextOverflow.ellipsis),
                onPressed: () => _fill(others.first.ageGroups),
              ),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < _groups.length; i++) _groupCard(i, c),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Возрастная группа'),
            onPressed: _addGroup,
          ),
          if (!_isNew && widget.existing!.participants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'После изменения групп откройте «Сетки» и пересоздайте изменившиеся категории.',
                style: TextStyle(fontSize: 12, color: c.tertiary),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: c.error)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Сохранить'),
      ),
    );
  }

  Widget _groupCard(int i, ColorScheme c) {
    final d = _groups[i];
    final w = parseWeights(d.weights.text);
    String? preview;
    if (w != null && w.isNotEmpty) {
      preview = [
        ...w.map((x) => fmtWeight(x)),
        '${fmtWeight(w.last)}+',
      ].join(' · ');
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Возраст'),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: TextField(
                controller: d.min,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'от', isDense: true),
                onChanged: (_) => setState(() => d.error = null),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—'),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: d.max,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                    labelText: 'до', hintText: 'и ст.', isDense: true),
                onChanged: (_) => setState(() => d.error = null),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Удалить группу',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                _groups.removeAt(i).dispose();
              }),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 8),
            child: TextField(
              controller: d.weights,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Весовые категории, кг',
                hintText: '27, 31, 36',
                helperText: preview == null ? null : 'Категории: $preview',
                errorText: d.error,
                isDense: true,
              ),
              onChanged: (_) => setState(() => d.error = null),
            ),
          ),
        ]),
      ),
    );
  }
}
