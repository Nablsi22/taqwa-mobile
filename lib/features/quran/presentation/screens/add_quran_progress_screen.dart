import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/quran_api.dart';
import 'quran_overview_screen.dart';

class AddQuranProgressScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final int lastSurah;
  final int lastPage;
  final int lastJuz;

  const AddQuranProgressScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.lastSurah,
    required this.lastPage,
    required this.lastJuz,
  });

  @override
  State<AddQuranProgressScreen> createState() => _AddQuranProgressScreenState();
}

class _AddQuranProgressScreenState extends State<AddQuranProgressScreen> {
  final _quranApi = QuranApi(ApiClient.instance);
  bool _isSaving = false;

  late int _surahNumber;
  late int _pageNumber;
  late int _juzNumber;

  @override
  void initState() {
    super.initState();
    _surahNumber = widget.lastSurah > 0 ? widget.lastSurah : 1;
    _pageNumber = widget.lastPage > 0 ? widget.lastPage : 1;
    _juzNumber = widget.lastJuz > 0 ? widget.lastJuz : 1;
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);

    try {
      final result = await _quranApi.addProgress(
        studentId: widget.studentId,
        surahNumber: _surahNumber,
        pageNumber: _pageNumber,
        juzNumber: _juzNumber,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'تم تسجيل التقدم بنجاح',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'تسجيل تقدم الحفظ',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Student header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: TaqwaColors.domeBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.menu_book,
                        color: TaqwaColors.minaretGold, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      widget.studentName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.lastSurah > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'آخر تسجيل: سورة ${getSurahName(widget.lastSurah)} • صفحة ${widget.lastPage}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Surah selector
                    _buildSectionLabel('السورة'),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _surahNumber,
                          isExpanded: true,
                          items: List.generate(114, (i) {
                            final num = i + 1;
                            return DropdownMenuItem(
                              value: num,
                              child: Text(
                                '$num - ${getSurahName(num)}',
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _surahNumber = value);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Page number
                    _buildSectionLabel('رقم الصفحة'),
                    const SizedBox(height: 10),
                    _buildNumberSelector(
                      value: _pageNumber,
                      min: 1,
                      max: 604,
                      onChanged: (value) =>
                          setState(() => _pageNumber = value),
                      label: 'من 604 صفحة',
                    ),

                    const SizedBox(height: 24),

                    // Juz number
                    _buildSectionLabel('رقم الجزء'),
                    const SizedBox(height: 10),
                    _buildNumberSelector(
                      value: _juzNumber,
                      min: 1,
                      max: 30,
                      onChanged: (value) =>
                          setState(() => _juzNumber = value),
                      label: 'من 30 جزء',
                    ),

                    const SizedBox(height: 36),

                    // Submit
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TaqwaColors.islamicGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'تسجيل التقدم',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: TaqwaColors.minaretGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TaqwaColors.domeBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberSelector({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: value > min
                ? () => onChanged(value - 1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red,
            iconSize: 32,
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.domeBlue,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: value < max
                ? () => onChanged(value + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
            color: TaqwaColors.islamicGreen,
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}
