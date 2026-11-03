import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';
import 'state.dart';

/// Онлайн-заявка, пришедшая с сайта.
class Entry {
  final String id;
  final String club;
  final String city;
  final String coach;
  final String coachPhone;
  final String fullName;
  final int birthYear;
  final bool female;
  final double weight;
  final DateTime createdAt;

  Entry.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        club = (m['club'] as String? ?? '').trim(),
        city = (m['city'] as String? ?? '').trim(),
        coach = (m['coach'] as String? ?? '').trim(),
        coachPhone = (m['coach_phone'] as String? ?? '').trim(),
        fullName = (m['full_name'] as String? ?? '').trim(),
        birthYear = (m['birth_year'] as num).toInt(),
        female = m['gender'] == 'F',
        weight = (m['weight'] as num).toDouble(),
        createdAt =
            DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now();

  String get dedupKey => '${_norm(fullName)}|$birthYear';
}

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

SupabaseClient get _db => Supabase.instance.client;

/// true, если Supabase настроен и успешно запущен.
bool onlineReady = false;

Future<void> initOnline() async {
  if (!onlineConfigured) return;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  onlineReady = true;
}

User? get currentUser => onlineReady ? _db.auth.currentUser : null;

Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

/// Возвращает текст ошибки или null при успехе.
Future<String?> signIn(String email, String password) async {
  try {
    await _db.auth.signInWithPassword(email: email.trim(), password: password);
    return null;
  } on AuthException catch (e) {
    return _authError(e.message);
  } catch (e) {
    return 'Нет связи с сервером';
  }
}

/// Возвращает текст ошибки / подсказку или null, если сразу вошли.
Future<String?> signUp(String email, String password) async {
  try {
    final r = await _db.auth.signUp(email: email.trim(), password: password);
    if (r.session == null) {
      return 'Проверьте почту и подтвердите регистрацию, затем нажмите «Войти»';
    }
    return null;
  } on AuthException catch (e) {
    return _authError(e.message);
  } catch (e) {
    return 'Нет связи с сервером';
  }
}

Future<void> signOut() => _db.auth.signOut();

String _authError(String m) {
  final l = m.toLowerCase();
  if (l.contains('invalid login')) return 'Неверная почта или пароль';
  if (l.contains('already registered')) return 'Такой пользователь уже есть — нажмите «Войти»';
  if (l.contains('password')) return 'Пароль минимум 6 символов';
  if (l.contains('email')) return 'Проверьте адрес почты';
  return m;
}

String linkFor(String slug) => '$siteUrl?t=$slug';

String _newSlug() {
  const abc = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(8, (_) => abc[r.nextInt(abc.length)]).join();
}

String _dateOnly(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Создаёт турнир в Supabase и сохраняет его id/slug локально.
Future<void> publishTournament(Tournament t, DateTime deadline) async {
  final slug = _newSlug();
  final row = await _db
      .from('tournaments')
      .insert({
        'slug': slug,
        'title': t.name,
        'date': _dateOnly(t.date),
        'place': t.place,
        'deadline': deadline.toUtc().toIso8601String(),
        'is_open': true,
      })
      .select('id')
      .single();
  t
    ..onlineId = row['id'] as String
    ..onlineSlug = slug;
  await app.save();
}

/// Подтягивает название/дату/место после правки турнира в приложении.
Future<void> pushTournamentInfo(Tournament t) async {
  if (t.onlineId == null || currentUser == null) return;
  try {
    await _db.from('tournaments').update({
      'title': t.name,
      'date': _dateOnly(t.date),
      'place': t.place,
    }).eq('id', t.onlineId!);
  } catch (_) {}
}

Future<Map<String, dynamic>?> fetchRemoteTournament(Tournament t) async {
  if (t.onlineId == null) return null;
  return _db
      .from('tournaments')
      .select('is_open,deadline')
      .eq('id', t.onlineId!)
      .maybeSingle();
}

Future<void> setRemoteOpen(Tournament t, bool open) async {
  await _db.from('tournaments').update({'is_open': open}).eq('id', t.onlineId!);
}

Future<void> setRemoteDeadline(Tournament t, DateTime deadline) async {
  await _db
      .from('tournaments')
      .update({'deadline': deadline.toUtc().toIso8601String()})
      .eq('id', t.onlineId!);
}

/// Удаляет турнир и все его заявки с сервера (локальные данные не трогает).
Future<void> deleteRemoteTournament(Tournament t) async {
  if (t.onlineId == null || currentUser == null) return;
  try {
    await _db.from('tournaments').delete().eq('id', t.onlineId!);
  } catch (_) {}
}

/// Заявки турнира в реальном времени.
Stream<List<Entry>> entriesStream(Tournament t) => _db
    .from('entries')
    .stream(primaryKey: ['id'])
    .eq('tournament_id', t.onlineId!)
    .order('created_at')
    .map((rows) => rows.map(Entry.fromMap).toList());

Future<void> deleteEntry(String id) async {
  await _db.from('entries').delete().eq('id', id);
}

/// Заявка уже есть в турнире: по id заявки или по ФИО + году рождения
/// (если организатор успел внести человека вручную).
bool isImported(Tournament t, Entry e) => t.participants.any((p) =>
    p.remoteId == e.id ||
    '${_norm(p.name)}|${p.birthYear}' == e.dedupKey);

/// Переносит новые заявки в участники турнира. Возвращает количество добавленных.
int importEntries(Tournament t, Iterable<Entry> entries) {
  var n = 0;
  for (final e in entries) {
    if (isImported(t, e)) continue;
    t.participants.add(Participant(
      id: newId(),
      name: e.fullName,
      birthYear: e.birthYear,
      weight: e.weight,
      team: e.club,
      female: e.female,
      remoteId: e.id,
    ));
    n++;
  }
  if (n > 0) app.save();
  return n;
}
