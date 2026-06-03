import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/surah_data.dart';
import '../../data/quran_api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class QuranReaderScreen extends StatefulWidget {
  final SurahInfo surah;

  const QuranReaderScreen({super.key, required this.surah});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final _quranApi = QuranApiService.instance;
  List<Map<String, dynamic>> _ayahs = [];
  bool _isLoading = true;
  String? _error;
  double _fontSize = 24.0;

  @override
  void initState() {
    super.initState();
    _loadSurah();
  }

  Future<void> _loadSurah() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ayahs = await _quranApi.getSurahAyahs(widget.surah.number);
      setState(() {
        _ayahs = ayahs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF0), // Warm parchment-like bg
        appBar: AppBar(
          title: Text(
            'سورة ${widget.surah.nameArabic}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFF0E2F44),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // Font size controls
            IconButton(
              icon: const Icon(Icons.text_decrease_rounded, size: 20),
              onPressed: () {
                if (_fontSize > 16) setState(() => _fontSize -= 2);
              },
            ),
            IconButton(
              icon: const Icon(Icons.text_increase_rounded, size: 20),
              onPressed: () {
                if (_fontSize < 40) setState(() => _fontSize += 2);
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: TaqwaColors.domeBlue),
                    SizedBox(height: 16),
                    Text(
                      'جارٍ تحميل السورة...',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF5D6D7E),
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? _buildErrorState()
                : _buildQuranView(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.grey.shade300, size: 56),
            const SizedBox(height: 16),
            const Text(
              'لم نتمكن من تحميل السورة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من اتصالك بالإنترنت وحاول مجدداً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSurah,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuranView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          // ─── Surah Header Card ───
          _buildSurahHeader(),
          const SizedBox(height: 20),

          // ─── Bismillah (except for Surah At-Tawbah) ───
          if (widget.surah.number != 9 && widget.surah.number != 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GoogleFonts.amiri().fontFamily,
                  fontSize: _fontSize + 2,
                  color: const Color(0xFF1B4F72),
                  height: 2.0,
                ),
              ),
            ),

          // ─── Continuous Text Mode (Mushaf-like) ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4AC0D).withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: RichText(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              text: TextSpan(
                children: _ayahs.map((ayah) {
                  final ayahNum = ayah['ayahNumber'] as int? ?? 0;
                  // Convert to Arabic-Indic numerals
                  final arabicNum = _toArabicNumerals(ayahNum);

                  return TextSpan(
                    children: [
                      TextSpan(
                        text: '${ayah['text']} ',
                        style: TextStyle(
                          fontFamily: GoogleFonts.amiri().fontFamily,
                          fontSize: _fontSize,
                          color: const Color(0xFF2C3E50),
                          height: 2.2,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Ayah number marker
                      TextSpan(
                        text: '\uFD3F$arabicNum\uFD3E ',
                        style: TextStyle(
                          fontFamily: GoogleFonts.amiri().fontFamily,
                          fontSize: _fontSize - 4,
                          color: const Color(0xFFD4AC0D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Surah Info Footer ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TaqwaColors.domeBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip('عدد الآيات', '${widget.surah.ayahCount}'),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _infoChip('نوع السورة', widget.surah.revelationType),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _infoChip('الجزء', '${widget.surah.juzStart}'),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSurahHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF0E2F44),
            Color(0xFF1B4F72),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4F72).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Decorative top ornament
          Text(
            '﷽',
            style: TextStyle(
              fontSize: 18,
              color: const Color(0xFFD4AC0D).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سورة ${widget.surah.nameArabic}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AC0D),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _headerBadge(widget.surah.revelationType),
              const SizedBox(width: 12),
              _headerBadge('${widget.surah.ayahCount} آية'),
              const SizedBox(width: 12),
              _headerBadge('الجزء ${widget.surah.juzStart}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B4F72),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  /// Convert number to Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩)
  String _toArabicNumerals(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }
}
