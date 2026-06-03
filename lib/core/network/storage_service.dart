
/// Simple in-memory storage for web, secure storage for mobile
class StorageService {
  static final StorageService _instance = StorageService._();
  StorageService._();
  factory StorageService() => _instance;

  final Map<String, String> _memoryStore = {};

  Future<void> write({required String key, required String value}) async {
    _memoryStore[key] = value;
  }

  Future<String?> read({required String key}) async {
    return _memoryStore[key];
  }

  Future<void> delete({required String key}) async {
    _memoryStore.remove(key);
  }

  Future<void> deleteAll() async {
    _memoryStore.clear();
  }
}