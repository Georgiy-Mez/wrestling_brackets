import 'models.dart';

class WeightCategory {
  final AgeGroup group;
  final int index;

  /// Порядок группы в турнире (для сортировки).
  final int groupOrder;

  const WeightCategory(this.group, this.index, this.groupOrder);

  String get key => '${group.id}|$index';
  bool get isOverflow => index >= group.weights.length;
  String get weightLabel {
    if (group.weights.isEmpty) return 'абсолютная';
    return isOverflow
        ? '${fmtWeight(group.weights.last)}+ кг'
        : '${fmtWeight(group.weights[index])} кг';
  }

  String get title => '${group.title}, $weightLabel';
  int get sortOrder => groupOrder * 1000 + index;

  static WeightCategory? fromKey(String key, Tournament t) {
    final parts = key.split('|');
    if (parts.length != 2) return null;
    final gi = t.ageGroups.indexWhere((g) => g.id == parts[0]);
    final i = int.tryParse(parts[1]);
    if (gi < 0 || i == null) return null;
    return WeightCategory(t.ageGroups[gi], i, gi);
  }
}

/// Возраст считается по году рождения (год турнира − год рождения).
int ageOf(Participant p, Tournament t) => t.date.year - p.birthYear;

int ageGroupIndex(int age, Tournament t) =>
    t.ageGroups.indexWhere((g) => g.contains(age));

WeightCategory? baseCategory(Participant p, Tournament t) {
  final gi = ageGroupIndex(ageOf(p, t), t);
  if (gi < 0) return null;
  final g = t.ageGroups[gi];
  var idx = g.weights.indexWhere((w) => p.weight <= w);
  if (idx < 0) idx = g.weights.length;
  return WeightCategory(g, idx, gi);
}

class Assignment {
  /// Ключ категории -> участники (после переводов).
  final Map<String, List<Participant>> members = {};

  /// id участника -> пометка о переводе.
  final Map<String, String> notes = {};

  final List<Participant> unassigned = [];

  final Tournament t;
  Assignment(this.t);

  List<WeightCategory> get categories => members.keys
      .map((k) => WeightCategory.fromKey(k, t)!)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  String? categoryOf(String pid) {
    for (final e in members.entries) {
      if (e.value.any((p) => p.id == pid)) return e.key;
    }
    return null;
  }
}

/// Распределяет участников по категориям.
/// Если в весе один человек — он переводится в ближайшую категорию выше,
/// где есть участники (если выше никого нет — в ближайшую ниже).
Assignment assign(Tournament t) {
  final a = Assignment(t);
  final perGroup = <String, Map<int, List<Participant>>>{};

  for (final p in t.participants) {
    final c = baseCategory(p, t);
    if (c == null) {
      a.unassigned.add(p);
      continue;
    }
    perGroup
        .putIfAbsent(c.group.id, () => {})
        .putIfAbsent(c.index, () => [])
        .add(p);
  }

  for (var gi = 0; gi < t.ageGroups.length; gi++) {
    final g = t.ageGroups[gi];
    final cats = perGroup[g.id];
    if (cats == null) continue;

    var changed = true;
    while (changed) {
      changed = false;
      final keys = cats.keys.toList()..sort();
      if (keys.length < 2) break;
      for (var i = 0; i < keys.length; i++) {
        final list = cats[keys[i]]!;
        if (list.length != 1) continue;
        final target = i + 1 < keys.length ? keys[i + 1] : keys[i - 1];
        cats.remove(keys[i]);
        cats[target]!.add(list.first);
        changed = true;
        break;
      }
    }

    cats.forEach((idx, list) {
      final key = WeightCategory(g, idx, gi).key;
      a.members[key] = list;
      for (final p in list) {
        final base = baseCategory(p, t)!;
        if (base.key != key) {
          a.notes[p.id] = 'переведён из ${base.weightLabel} (нет соперника)';
        }
      }
    });
  }

  return a;
}
