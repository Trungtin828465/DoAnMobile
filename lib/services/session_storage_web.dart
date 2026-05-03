import 'dart:html' as html;

import 'session_storage.dart';

class SessionStorageImpl implements SessionStorage {
  @override
  String? read(String key) => html.window.sessionStorage[key];

  @override
  void write(String key, String value) {
    html.window.sessionStorage[key] = value;
  }

  @override
  void remove(String key) {
    html.window.sessionStorage.remove(key);
  }
}
