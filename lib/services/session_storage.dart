import 'session_storage_stub.dart'
    if (dart.library.html) 'session_storage_web.dart';

abstract class SessionStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

SessionStorage createSessionStorage() => SessionStorageImpl();
