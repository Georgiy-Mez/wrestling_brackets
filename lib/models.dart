class Participant {
  final String id;
  String name;
  int birthYear;
  double weight;
  String team;
  bool female;

  /// id онлайн-заявки (Supabase), если участник пришёл с сайта.
  String? remoteId;

  Participant({
    required this.id,
    required this.name,
    required this.birthYear,
    required this.weight,
    this.team = '',
    this.female = false,
    this.remoteId,
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
        if (remoteId != null) 'remoteId': remoteId,
      };

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        birthYear: (j['birthYear'] as num).toInt(),
        weight: (j['weight'] as num).toDouble(),
        team: j['team'] as String? ?? '',
        female: j['female'] as bool? ?? false,
        remoteId: j['remoteId'] as String?,
      );
}

/// Возрастная группа турнира со своими весовыми категориями.
class AgeGroup {
  final String id;
  int minAge;

  /// null — «и старше».
  int? maxAge;

  /// Верхние границы весовых категорий по возрастанию (вес <= границы).
  /// Тяжелее последней — категория «N+ кг».
  List<double> weights;

  AgeGroup({
    required this.id,
    required this.minAge,
    this.maxAge,
    required this.weights,
  });

  String get title {
    if (maxAge == null) return '$minAge+ лет';
    if (maxAge == minAge) return '$minAge лет';
    return '$minAge–$maxAge лет';
  }

  bool contains(int age) => age >= minAge && (maxAge == null || age <= maxAge!);

  AgeGroup copy({String? newId}) => AgeGroup(
      id: newId ?? id, minAge: minAge, maxAge: maxAge, weights: [...weights]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'minAge': minAge,
        'maxAge': maxAge,
        'weights': weights,
      };

  factory AgeGroup.fromJson(Map<String, dynamic> j) => AgeGroup(
        id: j['id'] as String,
        minAge: (j['minAge'] as num).toInt(),
        maxAge: (j['maxAge'] as num?)?.toInt(),
        weights: ((j['weights'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
      );
}

/// Возрастные группы и веса из положения (шаблон «Заполнить по положению»).
/// id совпадают со старыми ключами сеток, чтобы старые турниры не сломались.
List<AgeGroup> builtInAgeGroups() => [
      AgeGroup(id: '6-7', minAge: 6, maxAge: 7, weights: [26]),
      AgeGroup(id: '8-9', minAge: 8, maxAge: 9, weights: [27, 31, 36]),
      AgeGroup(id: '10-11', minAge: 10, maxAge: 11, weights: [36, 40]),
      AgeGroup(id: '12-13', minAge: 12, maxAge: 13, weights: [45, 50, 55]),
      AgeGroup(id: '14-15', minAge: 14, maxAge: 15, weights: [50, 55, 60]),
      AgeGroup(id: '16-17', minAge: 16, maxAge: 17, weights: [55, 60, 65, 70]),
      AgeGroup(id: '18+', minAge: 18, maxAge: null, weights: [60, 65, 70, 75]),
    ];

class Tournament {
  final String id;
  String name;
  DateTime date;
  String place;
  final List<Participant> participants;

  /// Возрастные группы и веса, заданные организатором.
  List<AgeGroup> ageGroups;

  /// Ключ категории -> слоты первого круга (id участника или null = свободно).
  final Map<String, List<String?>> brackets;

  /// Онлайн-приём заявок: id и slug турнира в Supabase.
  String? onlineId;
  String? onlineSlug;

  Tournament({
    required this.id,
    required this.name,
    required this.date,
    this.place = '',
    List<Participant>? participants,
    List<AgeGroup>? ageGroups,
    Map<String, List<String?>>? brackets,
    this.onlineId,
    this.onlineSlug,
  })  : participants = participants ?? [],
        ageGroups = ageGroups ?? builtInAgeGroups(),
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
        'ageGroups': ageGroups.map((g) => g.toJson()).toList(),
        'brackets': brackets,
        if (onlineId != null) 'onlineId': onlineId,
        if (onlineSlug != null) 'onlineSlug': onlineSlug,
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
      // старые турниры без своих групп — по положению
      ageGroups: (j['ageGroups'] as List?)
          ?.map((e) => AgeGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      brackets: b,
      onlineId: j['onlineId'] as String?,
      onlineSlug: j['onlineSlug'] as String?,
    );
  }
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String fmtWeight(double w) =>
    w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
