import 'models.dart';

class AgeGroup {
  final String id;
  final String title;
  final int minAge;
  final int maxAge;

  /// Верхние границы весовых категорий (вес <= границы).
  final List<int> weights;

  const AgeGroup(this.id, this.title, this.minAge, this.maxAge, this.weights);
}

/// Возрастные группы и веса из положения.
/// Тяжелее последнего веса — категория «N+ кг» (у 18+ это 75+).
const ageGroups = <AgeGroup>[
  AgeGroup('6-7', '6–7 лет', 6, 7, [26]),
  AgeGroup('8-9', '8–9 лет', 8, 9, [27, 31, 36]),
  AgeGroup('10-11', '10–11 лет', 10, 11, [36, 40]),
  AgeGroup('12-13', '12–13 лет', 12, 13, [45, 50, 55]),
  AgeGroup('14-15', '14–15 лет', 14, 15, [50, 55, 60]),
  AgeGroup('16-17', '16–17 лет', 16, 17, [55, 60, 65, 70]),
  AgeGroup('18+', '18+ лет', 18, 200, [60, 65, 70, 75]),
];

class WeightCategory {
  final AgeGroup group;
  final int index;

  const WeightCategory(this.group, this.index);

  String get key => '${group.id}|$index';
  bool get isOverflow => index >= group.weights.length;
  String get weightLabel =>
      isOverflow ? '${group.weights.last}+ кг' : '${group.weights[index]} кг';
  String get title => '${group.title}, $weightLabel';
  int get sortOrder => ageGroups.indexOf(group) * 100 + index;

  static WeightCategory? fromKey(String key) {
    final parts = key.split('|');
    if (parts.length != 2) return null;
    final g = ageGroups.where((g) => g.id == parts[0]);
    final i = int.tryParse(parts[1]);
    if (g.isEmpty || i == null) return null;
    return WeightCategory(g.first, i);
  }
}

/// Возраст считается по году рождения (год турнира − год рождения).
int ageOf(Participant p, Tournament t) => t.date.year - p.birthYear;

AgeGroup? ageGroupFor(int age) {
  for (final g in ageGroups) {
    if (age >= g.minAge && age <= g.maxAge) return g;
  }
  return null;
}

WeightCategory? baseCategory(Participant p, Tournament t) {
  final g = ageGroupFor(ageOf(p, t));
  if (g == null) return null;
  var idx = g.weights.indexWhere((w) => p.weight <= w);
  if (idx < 0) idx = g.weights.length;
  return WeightCategory(g, idx);
}

class Assignment {
  /// Ключ категории -> участники (после переводов).
  final Map<String, List<Participant>> members = {};

  /// id участника -> пометка о переводе.
  final Map<String, String> notes = {};

  final List<Participant> unassigned = [];

  List<WeightCategory> get categories => members.keys
      .map((k) => WeightCategory.fromKey(k)!)
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
  final a = Assignment();
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

  for (final g in ageGroups) {
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
      final key = WeightCategory(g, idx).key;
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
