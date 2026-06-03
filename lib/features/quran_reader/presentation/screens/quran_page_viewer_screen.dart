import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/quran_cache_service.dart';
import '../../data/surah_data.dart';

class QuranPageViewerScreen extends StatefulWidget {
  final int initialPage;

  const QuranPageViewerScreen({super.key, this.initialPage = 1});

  @override
  State<QuranPageViewerScreen> createState() => _QuranPageViewerScreenState();
}

class _QuranPageViewerScreenState extends State<QuranPageViewerScreen> {
  late PageController _pageController;
  final _cache = QuranCacheService.instance;
  int _currentPage = 1;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _toArabicNum(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _pageController.jumpToPage(page - 1);
    setState(() => _currentPage = page);
  }

  void _showGoToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFFFFFDF5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFD4AC0D).withOpacity(0.4)),
          ),
          title: const Text('الانتقال إلى صفحة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 22),
            decoration: InputDecoration(
              hintText: '١ - ٦٠٤',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= 604) {
                  Navigator.pop(ctx);
                  _goToPage(page);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: TaqwaColors.domeBlue,
                  foregroundColor: Colors.white),
              child: const Text('انتقال', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showSurahListDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AC0D).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('❁', style: TextStyle(fontSize: 16,
                        color: const Color(0xFFD4AC0D).withOpacity(0.7))),
                    const SizedBox(width: 12),
                    const Text('فهرس السور',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 20,
                            fontWeight: FontWeight.bold, color: Color(0xFF1B4F72))),
                    const SizedBox(width: 12),
                    Text('❁', style: TextStyle(fontSize: 16,
                        color: const Color(0xFFD4AC0D).withOpacity(0.7))),
                  ],
                ),
              ),
              Divider(color: const Color(0xFFD4AC0D).withOpacity(0.3), height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: allSurahs.length,
                  itemBuilder: (_, index) {
                    final surah = allSurahs[index];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: const Color(0xFFD4AC0D).withOpacity(0.1)),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4F72).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFD4AC0D).withOpacity(0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Text(_toArabicNum(surah.number),
                              style: const TextStyle(fontFamily: 'Cairo',
                                  fontSize: 13, fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B4F72))),
                        ),
                        title: Text('سورة ${surah.nameArabic}',
                            style: const TextStyle(fontFamily: 'Cairo',
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${surah.revelationType} • ${surah.ayahCount} آية',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                                color: Colors.grey.shade500)),
                        trailing: Text('ص ${_toArabicNum(surah.startPage)}',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
                                color: const Color(0xFFD4AC0D).withOpacity(0.8))),
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToPage(surah.startPage);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSurahNameForPage(int page) {
    for (int i = allSurahs.length - 1; i >= 0; i--) {
      if (allSurahs[i].startPage <= page) {
        return 'سورة ${allSurahs[i].nameArabic}';
      }
    }
    return '';
  }

  int _getJuzForPage(int page) {
    const juzPages = [
      1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
      201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
      402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
    ];
    for (int i = juzPages.length - 1; i >= 0; i--) {
      if (page >= juzPages[i]) return i + 1;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // RTL so swiping left-to-right advances page (Arabic book style)
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF5),
        body: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [
              // ─── Page View (Arabic book direction) ───
              PageView.builder(
                controller: _pageController,
                reverse: false,
                itemCount: 604,
                onPageChanged: (index) {
                  setState(() => _currentPage = index + 1);
                },
                itemBuilder: (context, index) {
                  final pageNum = index + 1;
                  final url = _cache.getPageUrl(pageNum);
                  return _MushafPage(
                    key: ValueKey('mushaf_$pageNum'),
                    pageNumber: pageNum,
                    imageUrl: url,
                  );
                },
              ),

              // ─── Top Controls ───
              if (_showControls)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0E2F44).withOpacity(0.95),
                          const Color(0xFF0E2F44).withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(_getSurahNameForPage(_currentPage),
                                      style: const TextStyle(fontFamily: 'Cairo',
                                          fontSize: 16, fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  Text(
                                      'الجزء ${_toArabicNum(_getJuzForPage(_currentPage))}',
                                      style: TextStyle(fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7))),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.list_rounded,
                                  color: Colors.white),
                              onPressed: _showSurahListDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── Bottom Controls ───
              if (_showControls)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF0E2F44).withOpacity(0.95),
                          const Color(0xFF0E2F44).withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Row(
                          children: [
                            const Spacer(),
                            GestureDetector(
                              onTap: _showGoToPageDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFD4AC0D)
                                          .withOpacity(0.4)),
                                ),
                                child: Text(
                                  'صفحة ${_toArabicNum(_currentPage)} من ٦٠٤',
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Single Mushaf Page — downloads on first view, cached forever
// ═══════════════════════════════════════════════════════════════
class _MushafPage extends StatelessWidget {
  final int pageNumber;
  final String imageUrl;

  const _MushafPage({
    super.key,
    required this.pageNumber,
    required this.imageUrl,
  });

  String _toArabicNum(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFDF5),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'image/png,image/*,*/*',
          },
          // Loading indicator with progress
          progressIndicatorBuilder: (context, url, progress) => Center(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: progress.progress,
                      color: const Color(0xFFD4AC0D),
                      backgroundColor: const Color(0xFFD4AC0D).withOpacity(0.15),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('جارِ تحميل الصفحة ${_toArabicNum(pageNumber)}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                          color: Color(0xFF1B4F72))),
                  const SizedBox(height: 4),
                  Text('يتم الحفظ للتصفح بدون إنترنت',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                          color: Colors.grey.shade500)),
                  if (progress.progress != null) ...[
                    const SizedBox(height: 8),
                    Text('${(progress.progress! * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                            fontWeight: FontWeight.bold, color: Color(0xFFD4AC0D))),
                  ],
                ],
              ),
            ),
          ),
          // Error with retry hint
          errorWidget: (context, url, error) => Center(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 48,
                        color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    Text('تعذّر تحميل الصفحة ${_toArabicNum(pageNumber)}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('تحقق من اتصال الإنترنت وأعد المحاولة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                            color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text('$error',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
                            color: Colors.red.shade300),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
