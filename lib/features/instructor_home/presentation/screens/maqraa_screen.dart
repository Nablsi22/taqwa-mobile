import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/network/api_client.dart';
import '../../../recitation/data/recitation_api.dart';
import '../../../substitute/presentation/substitute_ui.dart';

class MaqraaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final String instructorId;

  /// Set when this مقرأة belongs to another حلقة («حلقات أخرى»): the screen
  /// then wears the by-proxy colours and names the instructor it is for, so
  /// it is never mistaken for your own حلقة. Either way the server records
  /// the account that saved it as the one who taught.
  final SubstituteMode? substitute;

  const MaqraaScreen({
    super.key,
    required this.students,
    required this.instructorId,
    this.substitute,
  });

  @override
  State<MaqraaScreen> createState() => _MaqraaScreenState();
}

class _MaqraaScreenState extends State<MaqraaScreen> {
  final _recitationApi = RecitationApi(ApiClient.instance);

  SubstituteMode? get _substitute => widget.substitute;
  bool get _byProxy => _substitute != null;

  /// Gold for your own مقرأة, violet when it is someone else's حلقة.
  Color get _accent =>
      _byProxy ? SubstituteColors.header : TaqwaColors.minaretGold;

  int? _selectedSuraNumber;
  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  // Student selection
  late Set<String> _selectedStudentIds;

  @override
  void initState() {
    super.initState();
    // Select all students by default
    _selectedStudentIds =
        widget.students.map((s) => s['studentId'] as String).toSet();
  }

  void _showSuraPicker() {
    final searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = suraList.where((s) {
            if (searchQuery.isEmpty) return true;
            return s.nameAr.contains(searchQuery) ||
                s.number.toString().contains(searchQuery);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.groups,
                            color: TaqwaColors.minaretGold, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'اختر سورة المقرأة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.domeBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن سورة...',
                        hintStyle: TextStyle(
                            fontFamily: 'Cairo', color: Colors.grey.shade400),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) =>
                          setSheetState(() => searchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final sura = filtered[index];
                        final isSelected =
                            _selectedSuraNumber == sura.number;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selected: isSelected,
                          selectedTileColor:
                              TaqwaColors.minaretGold.withValues(alpha: 0.08),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color:
                                  TaqwaColors.minaretGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${sura.number}',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: TaqwaColors.minaretGold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            sura.nameAr,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: TaqwaColors.islamicGreen)
                              : null,
                          onTap: () {
                            setState(
                                () => _selectedSuraNumber = sura.number);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TaqwaColors.domeBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (_selectedSuraNumber == null) {
      _showError('يرجى اختيار السورة');
      return;
    }
    if (_selectedStudentIds.isEmpty) {
      _showError('يرجى اختيار طالب واحد على الأقل');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // No page count is sent: a مقرأة awards no points, so there is
      // nothing for a page figure to influence.
      await _recitationApi.createBulkMaqraa(
        studentIds: _selectedStudentIds.toList(),
        surahNumber: _selectedSuraNumber!,
        date: dateStr,
      );

      if (mounted) {
        final suraName = getSuraName(_selectedSuraNumber!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل المقرأة ($suraName) لـ ${_selectedStudentIds.length} طالب',
              style: const TextStyle(fontFamily: 'Cairo'),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: TaqwaColors.islamicGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Cairo'),
            textDirection: TextDirection.rtl),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSura = _selectedSuraNumber != null
        ? getSuraByNumber(_selectedSuraNumber!)
        : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            _byProxy ? SubstituteColors.surface : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            _byProxy ? 'مقرأة حلقة أ. ${_substitute!.instructorName}' : 'مقرأة جماعية',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Whose حلقة this is — before anything that can be saved.
              if (_byProxy) ...[
                SubstituteBanner(
                  instructorName: _substitute!.instructorName,
                  subtitle: 'الطلاب يبقون في حلقتهم · يُحفظ باسمك كمسجِّل',
                  onSurface: true,
                ),
                const SizedBox(height: 14),
              ],
              // ── Info banner ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TaqwaColors.minaretGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: TaqwaColors.minaretGold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: TaqwaColors.minaretGold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'المقرأة: قراءة جماعية مع المعلم — تُسجل لجميع الطلاب المحددين',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Date ──
              _card(
                icon: Icons.calendar_today,
                title: 'التاريخ',
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_calendar,
                            color: TaqwaColors.domeBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Sura ──
              _card(
                icon: Icons.menu_book,
                title: 'السورة',
                child: InkWell(
                  onTap: _showSuraPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selectedSura != null
                          ? TaqwaColors.minaretGold.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedSura != null
                            ? TaqwaColors.minaretGold.withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (selectedSura != null) ...[
                          Text(
                            selectedSura.nameAr,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TaqwaColors.minaretGold,
                            ),
                          ),
                          const Spacer(),
                          Text('${selectedSura.totalPages} صفحة',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                        ] else
                          Text(
                            'اضغط لاختيار السورة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                color: Colors.grey.shade400),
                          ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── What a مقرأة is ──
              //
              // Group reading with the instructor. It is recorded so parents
              // can see the session happened; it is NOT memorisation and it
              // awards no points, up or down. There is deliberately no page
              // or verse field: a free-typed page count was the last place
              // where two students could end up scored differently for the
              // same session.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TaqwaColors.lightBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: TaqwaColors.domeBlue.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: TaqwaColors.domeBlue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'المقرأة إعلام لأولياء الأمور بأن جلسة قراءة جماعية جرت اليوم. '
                        'لا تُضاف ولا تُخصم أي نقاط.',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            height: 1.7,
                            color: TaqwaColors.domeBlue),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Student Selection ──
              _card(
                icon: Icons.people,
                title:
                    'الطلاب (${_selectedStudentIds.length}/${widget.students.length})',
                child: Column(
                  children: [
                    // Select all / deselect all
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedStudentIds = widget.students
                                  .map((s) => s['studentId'] as String)
                                  .toSet();
                            });
                          },
                          icon: const Icon(Icons.select_all, size: 16),
                          label: const Text('تحديد الكل',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12)),
                          style: TextButton.styleFrom(
                              foregroundColor: TaqwaColors.domeBlue),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedStudentIds.clear());
                          },
                          icon: const Icon(Icons.deselect, size: 16),
                          label: const Text('إلغاء الكل',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12)),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Student list
                    ...widget.students.map((student) {
                      final id = student['studentId'] as String;
                      final name = student['fullName'] as String? ?? 'طالب';
                      final isSelected = _selectedStudentIds.contains(id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? TaqwaColors.islamicGreen.withValues(alpha: 0.05)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          value: isSelected,
                          activeColor: TaqwaColors.islamicGreen,
                          checkboxShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedStudentIds.add(id);
                              } else {
                                _selectedStudentIds.remove(id);
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Save ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'تسجيل المقرأة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: TaqwaColors.minaretGold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.domeBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final days = [
      'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
      'الجمعة', 'السبت', 'الأحد',
    ];
    final months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month]} ${date.year}';
  }
}
