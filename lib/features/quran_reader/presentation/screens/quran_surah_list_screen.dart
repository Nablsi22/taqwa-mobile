import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/surah_data.dart';
import '../../data/quran_cache_service.dart';
import 'quran_page_viewer_screen.dart';
import 'quran_download_screen.dart';

class QuranSurahListScreen extends StatefulWidget {
  const QuranSurahListScreen({super.key});

  @override
  State<QuranSurahListScreen> createState() => _QuranSurahListScreenState();
}

class _QuranSurahListScreenState extends State<QuranSurahListScreen> {
  final _searchController = TextEditingController();
  List<SurahInfo> _filteredSurahs = allSurahs;
  String _filter = 'all';
  bool _isDownloaded = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkDownload();
  }

  Future<void> _checkDownload() async {
    final downloaded = await QuranCacheService.instance.isDownloaded();
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        _isChecking = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filteredSurahs = allSurahs.where((s) {
        final matchesSearch = query.isEmpty ||
            s.nameArabic.contains(query) ||
            '${s.number}'.contains(query);
        final matchesFilter = _filter == 'all' ||
            (_filter == 'meccan' && s.revelationType == '\u0645\u0643\u064a\u0629') ||
            (_filter == 'medinan' && s.revelationType == '\u0645\u062f\u0646\u064a\u0629');
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _onSearch(_searchController.text);
    });
  }

 void _openSurah(SurahInfo surah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPageViewerScreen(initialPage: surah.startPage),
      ),
    );
  }

 void _openPageViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuranPageViewerScreen()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: CustomScrollView(
          slivers: [
            // ——— Gradient App Bar ———
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: TaqwaColors.domeBlue,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0E2F44),
                        Color(0xFF1B4F72),
                        Color(0xFF154360),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_book_rounded,
                                  color: Color(0xFFD4AC0D), size: 28),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  '\u0627\u0644\u0642\u0631\u0622\u0646 \u0627\u0644\u0643\u0631\u064a\u0645',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // FIX: Wrap text in Flexible, remove Spacer to prevent 49px right overflow
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '\u0661\u0661\u0664 \u0633\u0648\u0631\u0629  \u2022  \u0663\u0660 \u062c\u0632\u0621  \u2022  \u0666\u0660\u0664 \u0635\u0641\u062d\u0629',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_isChecking) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isDownloaded
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isDownloaded
                                            ? Icons.offline_pin_rounded
                                            : Icons.cloud_download_rounded,
                                        color: _isDownloaded
                                            ? Colors.green
                                            : Colors.orange,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isDownloaded
                                            ? '\u0645\u062a\u0627\u062d'
                                            : '\u062a\u062d\u0645\u064a\u0644',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: _isDownloaded
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ——— Open Page Viewer Button ———
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: GestureDetector(
                  onTap: _openPageViewer,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E2F44), Color(0xFF1B4F72)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: TaqwaColors.domeBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AC0D).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.auto_stories_rounded,
                              color: Color(0xFFD4AC0D), size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\u0641\u062a\u062d \u0627\u0644\u0645\u0635\u062d\u0641',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '\u062a\u0635\u0641\u062d \u0627\u0644\u0642\u0631\u0622\u0646 \u0635\u0641\u062d\u0629 \u0628\u0635\u0641\u062d\u0629',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded,
                            color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ——— Search + Filter ———
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      onChanged: _onSearch,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '\u0627\u0628\u062d\u062b \u0639\u0646 \u0633\u0648\u0631\u0629...',
                        hintStyle: TextStyle(
                            fontFamily: 'Cairo', color: Colors.grey.shade400),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _filterChip('\u0627\u0644\u0643\u0644', 'all'),
                        const SizedBox(width: 8),
                        _filterChip('\u0645\u0643\u064a\u0629', 'meccan'),
                        const SizedBox(width: 8),
                        _filterChip('\u0645\u062f\u0646\u064a\u0629', 'medinan'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ——— Surah List ———
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildSurahTile(context, _filteredSurahs[index]),
                  childCount: _filteredSurahs.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TaqwaColors.domeBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? TaqwaColors.domeBlue : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildSurahTile(BuildContext context, SurahInfo surah) {
    return GestureDetector(
      onTap: () => _openSurah(surah),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: surah.revelationType == '\u0645\u0643\u064a\u0629'
                      ? [const Color(0xFF1B4F72), const Color(0xFF2E86C1)]
                      : [const Color(0xFF1E8449), const Color(0xFF27AE60)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${surah.number}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u0633\u0648\u0631\u0629 ${surah.nameArabic}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.revelationType}  \u2022  ${surah.ayahCount} \u0622\u064a\u0629  \u2022  \u0635\u0641\u062d\u0629 ${surah.startPage}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: Colors.grey.shade300, size: 24),
          ],
        ),
      ),
    );
  }
}