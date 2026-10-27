class Participant {
  final String id;
  String name;
  int birthYear;
  double weight;
  String team;
  bool female;

  Participant({
    required this.id,
    required this.name,
    required this.birthYear,
    required this.weight,
    this.team = '',
    this.female = false,
  });

  /// Ключ команды для сравнения (без регистра и пробелов по краям).
  String get teamKey => team.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthYear': birthYear,
        'weight': weight,
        'team': team,
        'female': female,
      };

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        birthYear: (j['birthYear'] as num).toInt(),
        weight: (j['weight'] as num).toDouble(),
        team: j['team'] as String? ?? '',
        female: j['female'] as bool? ?? false,
      );
}

class Tournament {
  final String id;
  String name;
  DateTime date;
  String place;
  final List<Participant> participants;

  /// Ключ категории -> слоты первого круга (id участника или null = свободно).
  final Map<String, List<String?>> brackets;

  Tournament({
    required this.id,
    required this.name,
    required this.date,
    this.place = '',
    List<Participant>? participants,
    Map<String, List<String?>>? brackets,
  })  : participants = participants ?? [],
        brackets = brackets ?? {};

  Map<String, Participant> get byId => {for (final p in participants) p.id: p};

  List<String> get teams {
    final map = <String, String>{};
    for (final p in participants) {
      if (p.team.trim().isNotEmpty) map[p.teamKey] ??= p.team.trim();
    }
    return map.values.toList()..sort();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'place': place,
        'participants': participants.map((p) => p.toJson()).toList(),
        'brackets': brackets,
      };

  factory Tournament.fromJson(Map<String, dynamic> j) {
    final rawB = (j['brackets'] as Map?) ?? const {};
    final b = <String, List<String?>>{};
    rawB.forEach((k, v) {
      b[k as String] = (v as List).map((e) => e as String?).toList();
    });
    return Tournament(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      place: j['place'] as String? ?? '',
      participants: ((j['participants'] as List?) ?? const [])
          .map((e) => Participant.fromJson(e as Map<String, dynamic>))
          .toList(),
      brackets: b,
    );
  }
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String fmtWeight(double w) =>
    w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
