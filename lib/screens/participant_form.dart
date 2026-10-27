import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../categories.dart';
import '../models.dart';
import '../state.dart';
import 'home_screen.dart';

class ParticipantForm extends StatefulWidget {
  final String tournamentId;
  final String? participantId;
  const ParticipantForm(
      {super.key, required this.tournamentId, this.participantId});

  @override
  State<ParticipantForm> createState() => _ParticipantFormState();
}

class _ParticipantFormState extends State<ParticipantForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _team = TextEditingController();
  final _year = TextEditingController();
  final _weight = TextEditingController();
  final _teamFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _female = false;
  int _added = 0;

  Tournament get t => app.byId(widget.tournamentId)!;
  Participant? get existing {
    final id = widget.participantId;
    if (id == null) return null;
    for (final p in t.participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final p = existing;
    if (p != null) {
      _name.text = p.name;
      _team.text = p.team;
      _year.text = '${p.birthYear}';
      _weight.text = fmtWeight(p.weight);
      _female = p.female;
    }
    for (final c in [_name, _year, _weight]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _team, _year, _weight]) {
      c.dispose();
    }
    _teamFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  double? _parseWeight(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  String? _preview() {
    final y = int.tryParse(_year.text.trim());
    final w = _parseWeight(_weight.text);
    if (y == null || w == null) return null;
    final tmp = Participant(id: '_', name: '', birthYear: y, weight: w);
    final c = baseCategory(tmp, t);
    if (c == null) return 'Возраст ${t.date.year - y} — вне возрастных групп';
    return 'Категория: ${c.title}';
  }

  bool _save() {
    if (!_form.currentState!.validate()) return false;
    final p = existing;
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final year = int.parse(_year.text.trim());
    final weight = _parseWeight(_weight.text)!;
    final team = _team.text.trim();
    if (p == null) {
      t.participants.add(Participant(
        id: newId(),
        name: name,
        birthYear: year,
        weight: weight,
        team: team,
        female: _female,
      ));
    } else {
      p
        ..name = name
        ..birthYear = year
        ..weight = weight
        ..team = team
        ..female = _female;
    }
    app.save();
    return true;
  }

  void _saveAndNext() {
    if (!_save()) return;
    setState(() {
      _added++;
      _name.clear();
      _weight.clear();
      _year.clear();
      _female = false;
    });
    _nameFocus.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('Добавлено: $_added')));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = existing != null;
    final preview = _preview();
    final sc = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Участник' : 'Новый участник'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final p = existing!;
                if (await confirm(context, 'Удалить ${p.name}?')) {
                  t.participants.removeWhere((x) => x.id == p.id);
                  app.save();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Фамилия Имя', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите ФИО' : null,
            ),
            const SizedBox(height: 12),
            RawAutocomplete<String>(
              textEditingController: _team,
              focusNode: _teamFocus,
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                final teams = t.teams;
                if (q.isEmpty) return teams;
                return teams.where((x) => x.toLowerCase().contains(q));
              },
              fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextFormField(
                controller: ctrl,
                focusNode: focus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Команда / клуб',
                  helperText: 'Одноклубники не встретятся в первой схватке',
                  border: OutlineInputBorder(),
                ),
              ),
              optionsViewBuilder: (ctx, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 220, maxWidth: 360),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                              dense: true,
                              title: Text(o),
                              onTap: () => onSelected(o)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Год рождения', border: OutlineInputBorder()),
                  validator: (v) {
                    final y = int.tryParse(v ?? '');
                    if (y == null || y < 1940 || y > DateTime.now().year) {
                      return 'Неверный год';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Вес, кг',
                      border: OutlineInputBorder()),
                  validator: (v) {
                    final w = _parseWeight(v ?? '');
                    if (w == null || w <= 0 || w > 250) return 'Неверный вес';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!isEdit) _saveAndNext();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false, label: Text('Юноша'), icon: Icon(Icons.male)),
                ButtonSegment(
                    value: true,
                    label: Text('Девушка'),
                    icon: Icon(Icons.female)),
              ],
              selected: {_female},
              onSelectionChanged: (s) => setState(() => _female = s.first),
            ),
            const SizedBox(height: 16),
            if (preview != null)
              Card(
                color: sc.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(preview,
                      style: TextStyle(
                          color: sc.onSecondaryContainer,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: 16),
            if (!isEdit) ...[
              FilledButton.icon(
                onPressed: _saveAndNext,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Сохранить и добавить ещё'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  if (_save()) Navigator.pop(context);
                },
                child: const Text('Сохранить и закрыть'),
              ),
            ] else
              FilledButton(
                onPressed: () {
                  if (_save()) Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
          ],
        ),
      ),
    );
  }
}
