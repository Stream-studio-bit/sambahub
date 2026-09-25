// CHANGELOG
// 2026-09-20: Criado DeviceIdService. Gera (uuid v4) e persiste no
// shared_preferences (localStorage no Flutter Web) um id anônimo do
// dispositivo, usado nos favoritos da campanha pública (a página não exige
// login). 36 caracteres, dentro do limite 16-64 do banco. Se o storage
// falhar (ex.: navegador bloqueando), usa um id em memória válido só na
// sessão.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final class DeviceIdService {
  const DeviceIdService._();

  static const String _key = 'sambahub_device_id';
  static String? _cached;

  static Future<String> getOrCreate() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored != null && stored.length >= 16 && stored.length <= 64) {
        return _cached = stored;
      }
      final created = const Uuid().v4();
      await prefs.setString(_key, created);
      return _cached = created;
    } catch (_) {
      return _cached = const Uuid().v4();
    }
  }
}