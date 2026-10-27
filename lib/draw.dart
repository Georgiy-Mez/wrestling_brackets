import 'dart:math';

import 'models.dart';

int nextPow2(int n) {
  var s = 1;
  while (s < n) {
    s *= 2;
  }
  return s;
}

/// Стандартный порядок посева для m позиций (1, m, m/2+1, ...).
/// Используется, чтобы свободные места (проходы) равномерно разошлись по сетке.
List<int> seedOrder(int m) {
  var s = <int>[1];
  while (s.length < m) {
    final k = s.length * 2;
    s = [
      for (final x in s) ...[x, k + 1 - x]
    ];
  }
  return s;
}

/// Правило «одноклубники не встречаются в первой схватке»
/// не действует, если в весе 3 человека (и меньше).
bool enforceTeams(int n) => n >= 4;

bool sameTeam(Participant a, Participant b) =>
    a.teamKey.isNotEmpty && a.teamKey == b.teamKey;

/// Номера пар первого круга, где встречаются одноклубники.
List<int> conflictPairs(List<String?> slots, Map<String, Participant> byId) {
  final n = slots.where((s) => s != null).length;
  if (!enforceTeams(n)) return [];
  final res = <int>[];
  for (var j = 0; j * 2 + 1 < slots.length; j++) {
    final a = byId[slots[2 * j]];
    final b = byId[slots[2 * j + 1]];
    if (a != null && b != null && sameTeam(a, b)) res.add(j);
  }
  return res;
}

/// Совпадает ли состав сетки с текущим составом категории.
bool bracketMatches(List<String?>? slots, List<Participant> members) {
  if (slots == null) return false;
  final a = slots.whereType<String>().toSet();
  final b = members.map((p) => p.id).toSet();
  return a.length == b.length && a.containsAll(b);
}

/// Штраф за то, что одноклубники стоят в одной половине/четверти сетки
/// (чтобы по возможности встречались как можно позже).
int spreadPenalty(List<String?> slots, Map<String, Participant> byId) {
  var pen = 0;
  for (var seg = slots.length; seg >= 4; seg ~/= 2) {
    final half = seg ~/ 2;
    for (var start = 0; start < slots.length; start += seg) {
      final l = <String, int>{}, r = <String, int>{};
      for (var i = start; i < start + seg; i++) {
        final p = byId[slots[i]];
        if (p == null || p.teamKey.isEmpty) continue;
        final mp = i < start + half ? l : r;
        mp[p.teamKey] = (mp[p.teamKey] ?? 0) + 1;
      }
      for (final k in {...l.keys, ...r.keys}) {
        final d = ((l[k] ?? 0) - (r[k] ?? 0)).abs();
        if (d > 1) pen += d - 1;
      }
    }
  }
  return pen;
}

/// Жеребьёвка. Возвращает слоты первого круга длиной 2^k.
/// Пара — слоты (2j, 2j+1). null — свободное место (участник проходит дальше).
List<String?> drawBracket(List<Participant> ps, {Random? random}) {
  final rnd = random ?? Random();
  final n = ps.length;
  if (n == 0) return [];
  if (n == 1) return [ps.first.id];

  final size = nextPow2(n);
  final m = size ~/ 2;
  final byes = size - n;
  final enforce = enforceTeams(n);
  final byId = {for (final p in ps) p.id: p};

  final teamCount = <String, int>{};
  for (final p in ps) {
    teamCount[p.teamKey] = (teamCount[p.teamKey] ?? 0) + 1;
  }

  final seeds = seedOrder(m);
  final byePos = <int>[];
  final fightPos = <int>[];
  for (var i = 0; i < m; i++) {
    (seeds[i] <= byes ? byePos : fightPos).add(i);
  }

  List<String?>? best;
  var bestScore = 1 << 30;

  for (var attempt = 0; attempt < 800; attempt++) {
    final pool = List<Participant>.of(ps)..shuffle(rnd);

    // Каждую вторую попытку проходы отдаём в первую очередь членам
    // самых больших команд — так легче развести остальных.
    if (enforce && attempt.isOdd) {
      final key = {
        for (final p in pool)
          p.id: (p.teamKey.isEmpty ? 0 : teamCount[p.teamKey]!) * 1000 +
              rnd.nextInt(1000)
      };
      pool.sort((a, b) => key[b.id]!.compareTo(key[a.id]!));
    }

    final byeFighters = pool.sublist(0, byes);
    final remaining = pool.sublist(byes);
    final pairs = <List<Participant>>[];
    var conflicts = 0;

    while (remaining.isNotEmpty) {
      // Берём участника из самой большой оставшейся команды
      final cnt = <String, int>{};
      for (final p in remaining) {
        if (p.teamKey.isNotEmpty) cnt[p.teamKey] = (cnt[p.teamKey] ?? 0) + 1;
      }
      var ai = 0;
      var bestC = -1;
      for (var i = 0; i < remaining.length; i++) {
        final c = cnt[remaining[i].teamKey] ?? 0;
        if (c > bestC) {
          bestC = c;
          ai = i;
        }
      }
      final a = remaining.removeAt(ai);

      final cand = <int>[
        for (var i = 0; i < remaining.length; i++)
          if (!enforce || !sameTeam(a, remaining[i])) i
      ];
      int bi;
      if (cand.isEmpty) {
        bi = rnd.nextInt(remaining.length);
        conflicts++;
      } else {
        bi = cand[rnd.nextInt(cand.length)];
      }
      final b = remaining.removeAt(bi);
      pairs.add(rnd.nextBool() ? [a, b] : [b, a]);
    }

    pairs.shuffle(rnd);
    final slots = List<String?>.filled(size, null);
    for (var k = 0; k < pairs.length; k++) {
      final pos = fightPos[k];
      slots[2 * pos] = pairs[k][0].id;
      slots[2 * pos + 1] = pairs[k][1].id;
    }
    for (var k = 0; k < byeFighters.length; k++) {
      slots[2 * byePos[k]] = byeFighters[k].id;
    }

    final score = conflicts * 100000 + spreadPenalty(slots, byId);
    if (score < bestScore) {
      bestScore = score;
      best = slots;
    }
    if (score == 0) break;
  }

  return best!;
}
