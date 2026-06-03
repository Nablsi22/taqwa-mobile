import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/quran_api.dart';
import 'add_quran_progress_screen.dart';

// Surah names in Arabic (114 surahs)
const List<String> surahNames = [
  '', 'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف',
  'الأنفال', 'التوبة', 'يونس', 'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه', 'الأنبياء', 'الحج', 'المؤمنون',
  'النور', 'الفرقان', 'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم', 'لقمان',
  'السجدة', 'الأحزاب', 'سبأ', 'فاطر', 'يس', 'الصافات', 'ص', 'الزمر',
  'غافر', 'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية', 'الأحقاف', 'محمد',
  'الفتح', 'الحجرات', 'ق', 'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة', 'الصف', 'الجمعة', 'المنافقون',
  'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج', 'نوح',
  'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات',
  'عبس', 'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج', 'الطارق', 'الأعلى',
  'الغاشية', 'الفجر', 'البلد', 'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات', 'القارعة', 'التكاثر', 'العصر',
  'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر', 'المسد',
  'الإخلاص', 'الفلق', 'الناس',
];

String getSurahName(int number) {
  if (number >= 1 && number <= 114) return surahNames[number];
  return 'سورة $number';
}

class QuranOverviewScreen extends StatefulWidget {
  const QuranOverviewScreen({super.key});

  @override
  State<QuranOverviewScreen> createState() => _QuranOverviewScreenState();
}

class _QuranOverviewScreenState extends State<QuranOverviewScreen> {
  final _quranApi = QuranApi(ApiClient.instance);
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _quranApi.getOverview();
      setState(() {
        _students = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToAddProgress(Map<String, dynamic> student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddQuranProgressScreen(
          studentId: student['studentId'] as String,
          studentName: student['fullName'] as String,
          lastSurah: student['lastSurah'] as int? ?? 1,
          lastPage: student['lastPage'] as int? ?? 1,
          lastJuz: student['lastJuz'] as int? ?? 1,
        ),
      ),
    );
    if (result == true) _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'متابعة حفظ القرآن',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOverview,
                          child: const Text('إعادة المحاولة',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  )
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book,
                                size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد طلاب مسجلين',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOverview,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            return _buildStudentCard(_students[index]);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final fullName = student['fullName'] as String? ?? '';
    final lastSurah = student['lastSurah'] as int? ?? 0;
    final lastPage = student['lastPage'] as int? ?? 0;
    final lastJuz = student['lastJuz'] as int? ?? 0;
    final progressPercent = student['progressPercent'] as int? ?? 0;
    final totalEntries = student['totalEntries'] as int? ?? 0;
    final memorizedCount = student['memorizedSurahCount'] as int? ?? 0;
    final didNotMemorize = student['didNotMemorize'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _navigateToAddProgress(student),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar with progress ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          value: progressPercent / 100,
                          strokeWidth: 4,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressPercent >= 50
                                ? TaqwaColors.islamicGreen
                                : TaqwaColors.skyBlue,
                          ),
                        ),
                      ),
                      // ─── Show warning icon if last entry was "did not memorize" ───
                      didNotMemorize
                          ? const Icon(Icons.cancel_rounded,
                              color: Colors.red, size: 22)
                          : Text(
                              fullName.isNotEmpty ? fullName[0] : '?',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: TaqwaColors.domeBlue,
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ),
                            // ─── "Did not memorize" badge on last entry ───
                            if (didNotMemorize)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'لم يحفظ',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (lastSurah > 0)
                          Text(
                            'آخر سورة: ${getSurahName(lastSurah)} • صفحة $lastPage • جزء $lastJuz',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else
                          Text(
                            'لم يبدأ بعد',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Progress badge — now shows surah count
                  Column(
                    children: [
                      Text(
                        '$progressPercent%',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: progressPercent >= 50
                              ? TaqwaColors.islamicGreen
                              : TaqwaColors.skyBlue,
                        ),
                      ),
                      Text(
                        '$memorizedCount / 114',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressPercent >= 50
                        ? TaqwaColors.islamicGreen
                        : TaqwaColors.skyBlue,
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
