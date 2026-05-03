import 'session_storage.dart';

class SessionStorageImpl implements SessionStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  String? read(String key) => _store[key];

  @override
  void write(String key, String value) {
    _store[key] = value;
  }

  @override
  void remove(String key) {
    _store.remove(key);
  }
}
