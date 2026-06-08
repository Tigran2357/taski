import 'package:shared_preferences/shared_preferences.dart';

/// Per-user, per-device color overrides for **public** folders.
///
/// A public folder's color is a personal view preference: each member can tint
/// the shared folder for themselves without affecting anyone else. Stored
/// locally (not synced), keyed by folder id.
class FolderColorPrefs {
  static const _prefix = 'folderColor_';

  Future<Map<String, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final v = prefs.getString(key);
        if (v != null) map[key.substring(_prefix.length)] = v;
      }
    }
    return map;
  }

  Future<void> setColor(String folderId, String? color) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$folderId';
    if (color == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, color);
    }
  }
}
