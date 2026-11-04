import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Small per-user display preferences, saved on the user's Firestore record
/// (`users/{uid}`) so they survive restarts and follow the user.
class UiPreferences extends ChangeNotifier {
  UiPreferences._();

  static final UiPreferences instance = UiPreferences._();

  String? _userId;
  bool _moveShortcuts = true;
  bool _autoDownloadMedia = true;

  /// Chat photos load straight away; when off they wait for a tap.
  bool get autoDownloadMedia => _autoDownloadMedia;

  bool _notifications = true;
  String _language = 'English';
  String _themeMode = 'system';
  String _textSize = 'medium';
  String _startTab = 'home';
  double _alertRadiusKm = 2;

  /// Saved for when push notifications are added.
  bool get notifications => _notifications;

  /// Saved choice; the app's text is not translated yet.
  String get language => _language;

  /// 'system', 'light' or 'dark' for screens that follow dark mode.
  String get themeMode => _themeMode;

  /// 'small', 'medium' or 'large': scales text across the app.
  String get textSize => _textSize;
  double get textScale => switch (_textSize) {
    'small' => .9,
    'large' => 1.15,
    _ => 1.0,
  };

  /// Tab the app opens on: 'home', 'map' or 'messages'.
  String get startTab => _startTab;

  /// How far around you counts as "near you" for reports and neighbours.
  double get alertRadiusKm => _alertRadiusKm;

  /// Home shortcut buttons swap places every few seconds.
  bool get moveShortcuts => _moveShortcuts;

  Future<void> load(String? userId) async {
    _userId = (userId == null || userId.isEmpty) ? null : userId;
    if (_userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      var changed = false;
      final move = data['moveShortcuts'];
      if (move is bool && move != _moveShortcuts) {
        _moveShortcuts = move;
        changed = true;
      }
      final media = data['autoDownloadMedia'];
      if (media is bool && media != _autoDownloadMedia) {
        _autoDownloadMedia = media;
        changed = true;
      }
      T? read<T>(String key) => data[key] is T ? data[key] as T : null;
      _notifications = read<bool>('notificationsEnabled') ?? _notifications;
      _language = read<String>('language') ?? _language;
      _themeMode = read<String>('themeMode') ?? _themeMode;
      _textSize = read<String>('textSize') ?? _textSize;
      _startTab = read<String>('startTab') ?? _startTab;
      _alertRadiusKm =
          (read<num>('alertRadiusKm'))?.toDouble() ?? _alertRadiusKm;
      changed = true;
      if (changed) notifyListeners();
    } catch (_) {
      // Keep the defaults if the saved values cannot be read.
    }
  }

  void setMoveShortcuts(bool value) {
    if (value == _moveShortcuts) return;
    _moveShortcuts = value;
    notifyListeners();
    _save({'moveShortcuts': value});
  }

  void setAutoDownloadMedia(bool value) {
    if (value == _autoDownloadMedia) return;
    _autoDownloadMedia = value;
    notifyListeners();
    _save({'autoDownloadMedia': value});
  }

  void setNotifications(bool value) {
    _notifications = value;
    notifyListeners();
    _save({'notificationsEnabled': value});
  }

  void setLanguage(String value) {
    _language = value;
    notifyListeners();
    _save({'language': value});
  }

  void setThemeMode(String value) {
    _themeMode = value;
    notifyListeners();
    _save({'themeMode': value});
  }

  void setTextSize(String value) {
    _textSize = value;
    notifyListeners();
    _save({'textSize': value});
  }

  void setStartTab(String value) {
    _startTab = value;
    notifyListeners();
    _save({'startTab': value});
  }

  /// Updates the radius while dragging; [save] writes it when done.
  void setAlertRadiusKm(double value, {bool save = true}) {
    _alertRadiusKm = value;
    notifyListeners();
    if (save) _save({'alertRadiusKm': value});
  }

  void _save(Map<String, Object> fields) {
    final userId = _userId;
    if (userId == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set(fields, SetOptions(merge: true))
        .catchError((_) {});
  }
}
