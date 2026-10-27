import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrestling_brackets/categories.dart';
import 'package:wrestling_brackets/draw.dart';
import 'package:wrestling_brackets/models.dart';

void main() {
  final t = Tournament(id: 't', name: 'Тест', date: DateTime(2026, 11, 1));

  Participant p(String id, int year, double w, String team) =>
      Participant(id: id, name: id, birthYear: year, weight: w, team: team);

  test('категории по году рождения и весу', () {
    expect(baseCategory(p('a', 2013, 44.5, ''), t)!.title, '12–13 лет, 45 кг');
    expect(baseCategory(p('b', 2013, 45, ''), t)!.title, '12–13 лет, 45 кг');
    expect(baseCategory(p('c', 2000, 80, ''), t)!.title, '18+ лет, 75+ кг');
    expect(baseCategory(p('d', 2022, 20, ''), t), isNull);
  });

  test('одиночка переводится в категорию выше', () {
    final tt = Tournament(id: 'x', name: 'x', date: DateTime(2026), participants: [
      p('a', 2013, 44, ''),
      p('b', 2013, 54, ''),
      p('c', 2013, 53, ''),
    ]);
    final a = assign(tt);
    expect(a.members['12-13|2']!.length, 3);
    expect(a.notes.containsKey('a'), true);
  });

  test('одноклубники разведены в первой схватке', () {
    final rnd = Random(42);
    for (var n = 4; n <= 32; n++) {
      final ps = [
        for (var i = 0; i < n; i++) p('$i', 2012, 50, 'Команда ${i % 3}')
      ];
      final slots = drawBracket(ps, random: rnd);
      expect(slots.whereType<String>().length, n);
      expect(conflictPairs(slots, {for (final x in ps) x.id: x}), isEmpty);
    }
  });

  test('при трёх участниках ограничение не действует', () {
    final ps = [p('a', 2012, 50, 'A'), p('b', 2012, 50, 'A'), p('c', 2012, 50, 'A')];
    final slots = drawBracket(ps);
    expect(slots.length, 4);
    expect(conflictPairs(slots, {for (final x in ps) x.id: x}), isEmpty);
  });
}
