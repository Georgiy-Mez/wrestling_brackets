import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

final app = AppState();
final _rnd = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(99999)}';

class AppState extends ChangeNotifier {
  static const _key = 'tournaments_v1';
  final List<Tournament> tournaments = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      tournaments
        ..clear()
        ..addAll(list.map((e) => Tournament.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
    }
  }

  Future<void> save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(tournaments.map((t) => t.toJson()).toList()));
  }

  Tournament? byId(String id) {
    for (final t in tournaments) {
      if (t.id == id) return t;
    }
    return null;
  }

  void add(Tournament t) {
    tournaments.insert(0, t);
    save();
  }

  void remove(Tournament t) {
    tournaments.remove(t);
    save();
  }
}
