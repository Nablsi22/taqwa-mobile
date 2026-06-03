/// Quran Mushaf page service.
/// Pages load on-demand from mp3quran.net and cache automatically
/// via CachedNetworkImage. First view requires internet, then offline forever.
class QuranCacheService {
  QuranCacheService._();
  static final QuranCacheService instance = QuranCacheService._();

  /// Always true — pages load on demand.
  Future<bool> isDownloaded() async => true;

  /// Returns the URL for a real Mushaf page image.
  String getPageUrl(int pageNumber) {
    final padded = pageNumber.toString().padLeft(3, '0');
    return 'https://www.mp3quran.net/api/quran_pages_arabic/$padded.png';
  }

  /// Not needed — kept for compatibility.
  Future<String?> getPagePath(int pageNumber) async => null;
  String getPageAssetPath(int pageNumber) => '';
  Future<List<Map<String, dynamic>>> getPage(int pageNumber) async => [];
}
