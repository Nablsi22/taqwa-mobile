import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/widgets/points_display.dart';
import '../../../../core/constants/quran_ayat_metadata.dart';
import '../../../recitation/data/recitation_api.dart';
import '../../../../core/network/api_client.dart';
import '../../../terms/presentation/widgets/term_selector.dart';

// ╔═══════════════════════════════════════════════════════════════════╗
// WHY THERE IS NO "WHOLE SURA" MODE ANY MORE
//
// Whole-sura entries used a per-surah page table while aya ranges were
// measured against the mushaf page map, and the two disagreed badly — an
// audit of production data put whole-sura entries 40-75% above the exact
// figure for the same content. Two students who memorised the same ayat
// could end up with very different points depending on which button their
// instructor pressed.
//
// A segment is now always a verse range: سورة + من آية + إلى آية. One
// measurement, one formula, identical for everyone. The backend refuses the
// old shape outright, so this is not merely a hidden button.
// ╚═══════════════════════════════════════════════════════════════════╝

/// Top-level branch selector: Quran recitation (existing flow) vs the
/// Nawawi-40 hadith flow. Default is [quran] so the screen opens exactly
/// as before.
enum _RecitationTab { quran, hadith }

/// One memorization segment: a verse range inside a single sura.
///
/// Each segment carries its OWN `rating` (VERY_GOOD / GOOD / REPEAT).
/// DID_NOT_MEMORIZE is a session-level state (the "لم يحفظ اليوم" toggle) —
/// never a per-segment rating.
class _RecitationSegment {
  _RecitationSegment({
    required this.id,
    this.ayaSurah,
    this.startAya = 1,
    this.endAya = 1,
    this.rating = '',
  });

  final int id;
  int? ayaSurah;
  int startAya;
  int endAya;
  String rating;

  /// Ayat in this segment — THE definition, matching the backend's
  /// getVerseCount() exactly:  verseCount = endAya - startAya + 1.
  /// No rounding, no estimation, no dependence on which sura it is.
  int get verseCount {
    if (ayaSurah == null) return 0;
    if (startAya < 1 || endAya < startAya) return 0;
    return endAya - startAya + 1;
  }

  /// Mushaf pages this segment spans. Display only — the server recomputes
  /// it from the same range before awarding a single point, so a tampered or
  /// out-of-date client cannot inflate a score.
  double get pages {
    if (ayaSurah != null && endAya >= startAya) {
      return calculateLocalPages(ayaSurah!, startAya, endAya);
    }
    return 0;
  }

  /// True only when the range is filled AND a rating is selected.
  bool get isValid => rating.isNotEmpty && hasContent;

  /// A sura and a range that is the right way round. The ceiling (endAya
  /// within the sura's ayah count) is held by the stepper's max and
  /// re-checked server-side by validateRange().
  bool get hasContent =>
      ayaSurah != null && startAya >= 1 && endAya >= startAya;

  /// Payload consumed by the backend batch endpoint.
  Map<String, dynamic> toBackendPayload() {
    return {
      'type': 'AYA_RANGE',
      'rating': rating,
      'startSurah': ayaSurah!,
      'startAya': startAya,
      'endAya': endAya,
    };
  }
}

class AddRecitationScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AddRecitationScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AddRecitationScreen> createState() => _AddRecitationScreenState();
}

class _AddRecitationScreenState extends State<AddRecitationScreen> {
  final _recitationApi = RecitationApi(ApiClient.instance);
  final _homeworkController = TextEditingController();

  // Session-level state
  DateTime _selectedDate = DateTime.now();
  bool _didNotMemorize = false;
  bool _isSaving = false;
  bool _loadingSuggestion = false;

  // Segments
  final List<_RecitationSegment> _segments = [];
  int _nextSegmentId = 0;

  // ── Hadith (Nawawi 40) branch state. All additive — the Quran flow
  //    never reads these. ──
  _RecitationTab _tab = _RecitationTab.quran;
  List<HadithRule> _hadithRules = [];
  bool _loadingRules = false;
  bool _rulesLoaded = false;
  int? _selectedHadith;
  bool _savingHadith = false;

  /// Memorization map for THIS student — which ahadith are already
  /// recorded (cumulative across terms). Loaded together with the rules
  /// the first time the hadith tab is opened. On fetch failure it stays
  /// empty so the picker still opens (backend UNIQUE constraint remains
  /// the final safety net against duplicates).
  HadithProgress _hadithProgress = const HadithProgress.empty();

  /// Per-segment rating options (DID_NOT_MEMORIZE is intentionally absent —
  /// it's a session-level state, not a segment rating).
  static const List<Map<String, dynamic>> _segmentRatings = [
    {'value': 'VERY_GOOD', 'label': 'جيد جداً', 'icon': Icons.star, 'color': Color(0xFF1E8449)},
    {'value': 'GOOD',      'label': 'جيد',     'icon': Icons.thumb_up, 'color': Color(0xFF2E86C1)},
    {'value': 'REPEAT',    'label': 'إعادة',   'icon': Icons.replay, 'color': Color(0xFFD4AC0D)},
  ];

  // ── Arabic UI strings for the Hadith branch, built from verified
  //    codepoint arrays (String.fromCharCodes) per project convention.
  //    Each array's hex was round-trip verified before insertion. ──
  static final String _kQuranTab = String.fromCharCodes(
      [0x0627, 0x0644, 0x0642, 0x0631, 0x0622, 0x0646, 0x0020, 0x0627, 0x0644, 0x0643, 0x0631, 0x064a, 0x0645]);
  static final String _kHadithTab = String.fromCharCodes(
      [0x0627, 0x0644, 0x0623, 0x0631, 0x0628, 0x0639, 0x064a, 0x0646, 0x0020, 0x0627, 0x0644, 0x0646, 0x0648, 0x0648, 0x064a, 0x0629]);
  static final String _kChooseHadith = String.fromCharCodes(
      [0x0627, 0x062e, 0x062a, 0x0631, 0x0020, 0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b]);
  static final String _kTapToChoose = String.fromCharCodes(
      [0x0627, 0x0636, 0x063a, 0x0637, 0x0020, 0x0644, 0x0627, 0x062e, 0x062a, 0x064a, 0x0627, 0x0631, 0x0020, 0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b]);
  static final String _kHadithWord = String.fromCharCodes(
      [0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b]);
  static final String _kSavedOk = String.fromCharCodes(
      [0x062a, 0x0645, 0x0020, 0x062a, 0x0633, 0x062c, 0x064a, 0x0644, 0x0020, 0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b, 0x0020, 0x0628, 0x0646, 0x062c, 0x0627, 0x062d]);
  static final String _kAlreadyRecorded = String.fromCharCodes(
      [0x062a, 0x0645, 0x0020, 0x062a, 0x0633, 0x062c, 0x064a, 0x0644, 0x0020, 0x0647, 0x0630, 0x0627, 0x0020, 0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b, 0x0020, 0x0645, 0x0633, 0x0628, 0x0642, 0x0627, 0x064b, 0x0020, 0x0644, 0x0647, 0x0630, 0x0627, 0x0020, 0x0627, 0x0644, 0x0637, 0x0627, 0x0644, 0x0628]);
  static final String _kLoadError = String.fromCharCodes(
      [0x062a, 0x0639, 0x0630, 0x0651, 0x0631, 0x0020, 0x062a, 0x062d, 0x0645, 0x064a, 0x0644, 0x0020, 0x0642, 0x0627, 0x0626, 0x0645, 0x0629, 0x0020, 0x0627, 0x0644, 0x0623, 0x062d, 0x0627, 0x062f, 0x064a, 0x062b]);
  static final String _kPleaseChoose = String.fromCharCodes(
      [0x064a, 0x0631, 0x062c, 0x0649, 0x0020, 0x0627, 0x062e, 0x062a, 0x064a, 0x0627, 0x0631, 0x0020, 0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b]);
  static final String _kSearchHint = String.fromCharCodes(
      [0x0628, 0x062d, 0x062b, 0x002e, 0x002e, 0x002e]);
  static final String _kLoading = String.fromCharCodes(
      [0x062c, 0x0627, 0x0631, 0x064a, 0x0020, 0x0627, 0x0644, 0x062a, 0x062d, 0x0645, 0x064a, 0x0644, 0x002e, 0x002e, 0x002e]);
  static final String _kSaveLabel = String.fromCharCodes(
      [0x062d, 0x0641, 0x0638, 0x0020, 0x0627, 0x0644, 0x062a, 0x0633, 0x0645, 0x064a, 0x0639]);
  static final String _kGenericError = String.fromCharCodes(
      [0x062d, 0x062f, 0x062b, 0x0020, 0x062e, 0x0637, 0x0623]);

  // ── Nawawi memorization-map strings (same codepoint-array convention).
  //    _kAlreadyMemorized = «هذا الحديث محفوظ مسبقاً»
  //    _kMemorizedBadge   = «محفوظ مسبقاً»
  //    _kMemorizedWord    = «محفوظ»
  //    _kOfWord           = «من» ──
  static final String _kAlreadyMemorized = String.fromCharCodes(
      [0x0647, 0x0630, 0x0627, 0x0020, 0x0627, 0x0644, 0x062d, 0x062f, 0x064a, 0x062b, 0x0020, 0x0645, 0x062d, 0x0641, 0x0648, 0x0638, 0x0020, 0x0645, 0x0633, 0x0628, 0x0642, 0x0627, 0x064b]);
  static final String _kMemorizedBadge = String.fromCharCodes(
      [0x0645, 0x062d, 0x0641, 0x0648, 0x0638, 0x0020, 0x0645, 0x0633, 0x0628, 0x0642, 0x0627, 0x064b]);
  static final String _kMemorizedWord = String.fromCharCodes(
      [0x0645, 0x062d, 0x0641, 0x0648, 0x0638]);
  static final String _kOfWord = String.fromCharCodes([0x0645, 0x0646]);

  @override
  void initState() {
    super.initState();
    // The first segment is pre-filled from where the student left off, which
    // is the most common recitation pattern. The suggestion spans courses:
    // memorisation continues even though points restart.
    _segments.add(_RecitationSegment(id: _nextSegmentId++));
    _loadNextSuggestionForFirstSegment();
  }

  @override
  void dispose() {
    _homeworkController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Suggestion — only the first aya-range segment
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _loadNextSuggestionForFirstSegment() async {
    setState(() => _loadingSuggestion = true);
    try {
      final s = await _recitationApi.getNextSuggestion(widget.studentId);
      final surah = s['suggestedSurah'] as int?;
      final aya = s['suggestedAya'] as int?;
      if (mounted && surah != null && aya != null && _segments.isNotEmpty) {
        setState(() {
          final first = _segments.first;
          first.ayaSurah = surah;
          first.startAya = aya;
          first.endAya = aya;
        });
      }
    } catch (_) {
      // Suggestion is a convenience, never a gate: fall back to الفاتحة 1
      // so the instructor can still pick a sura by hand.
      if (mounted && _segments.isNotEmpty) {
        setState(() {
          final first = _segments.first;
          first.ayaSurah = 1;
          first.startAya = 1;
          first.endAya = 1;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSuggestion = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Segment management
  // ═══════════════════════════════════════════════════════════════════
  void _addSegment() {
    setState(() {
      _segments.add(_RecitationSegment(id: _nextSegmentId++));
    });
  }

  void _removeSegment(int id) {
    if (_segments.length <= 1) return;
    setState(() => _segments.removeWhere((s) => s.id == id));
  }

  double get _totalPages =>
      _segments.fold<double>(0, (sum, s) => sum + s.pages);

  int get _totalVerses =>
      _segments.fold<int>(0, (sum, s) => sum + s.verseCount);

  // ═══════════════════════════════════════════════════════════════════
  // Surah pickers
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _openAyaSurahPicker(_RecitationSegment seg) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AyaSurahPickerSheet(currentSurah: seg.ayaSurah),
    );
    if (picked != null) {
      setState(() {
        seg.ayaSurah = picked;
        seg.startAya = 1;
        seg.endAya = 1;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Date picker
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TaqwaColors.domeBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: TaqwaColors.domeBlue),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Save — batch payload with per-segment ratings
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _save() async {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    String? sessionRating;
    List<Map<String, dynamic>> payloadSegments = [];

    if (_didNotMemorize) {
      // Placeholder path — backend creates a marker row, awards no points.
      sessionRating = 'DID_NOT_MEMORIZE';
    } else {
      if (_segments.isEmpty) {
        return _showError('يجب إضافة مقطع واحد على الأقل');
      }
      for (int i = 0; i < _segments.length; i++) {
        final seg = _segments[i];
        // Client-side mirror of the backend's validateRange(). It exists to
        // give the instructor an immediate, specific message; the server and
        // the recitations_verse_range_chk constraint remain the authority.
        if (seg.ayaSurah == null) {
          return _showError('المقطع ${i + 1}: يرجى اختيار السورة');
        }
        final surahInfo = getAyaSurah(seg.ayaSurah!);
        if (surahInfo == null) {
          return _showError('المقطع ${i + 1}: رقم السورة غير صالح');
        }
        if (seg.startAya < 1) {
          return _showError(
              'المقطع ${i + 1}: آية البداية يجب أن تكون 1 أو أكثر');
        }
        if (seg.endAya > surahInfo.numAyas) {
          return _showError(
              'المقطع ${i + 1}: سورة ${surahInfo.nameAr} عدد آياتها '
              '${surahInfo.numAyas} فقط');
        }
        if (seg.endAya < seg.startAya) {
          return _showError('المقطع ${i + 1}: «إلى آية» يجب ألا تقل عن «من آية»');
        }
        if (seg.rating.isEmpty) {
          return _showError('المقطع ${i + 1}: يرجى اختيار التقييم');
        }
      }
      payloadSegments = _segments.map((s) => s.toBackendPayload()).toList();
    }

    setState(() => _isSaving = true);
    try {
      await _recitationApi.createRecitationBatch(
        studentId: widget.studentId,
        date: dateStr,
        rating: sessionRating,
        homework: _homeworkController.text.isNotEmpty
            ? _homeworkController.text
            : null,
        segments: payloadSegments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('تم تسجيل التسميع بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
              textDirection: TextDirection.rtl),
          backgroundColor: TaqwaColors.islamicGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontFamily: 'Cairo'),
          textDirection: TextDirection.rtl),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text('تسميع - ${widget.studentName}',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeToggle(),
              const SizedBox(height: 12),
              // Which course this entry is filed under — always the ACTIVE
              // one, shown before the form so a session can't be logged
              // against the wrong course without anyone noticing.
              const ActiveTermRecordingBanner(),
              const SizedBox(height: 12),
              if (_tab == _RecitationTab.quran) ...[
                _buildDateCard(),
                const SizedBox(height: 12),
                _buildDidNotMemorizeToggle(),
                const SizedBox(height: 12),
                if (!_didNotMemorize) ...[
                  for (int i = 0; i < _segments.length; i++) ...[
                    _buildSegmentCard(i, _segments[i]),
                    const SizedBox(height: 12),
                  ],
                  _buildAddSegmentButton(),
                  const SizedBox(height: 12),
                  if (_totalVerses > 0) _buildTotalPagesCard(),
                  if (_totalVerses > 0) const SizedBox(height: 12),
                ],
                _buildHomeworkSection(),
                const SizedBox(height: 24),
                _buildSaveButton(),
                const SizedBox(height: 32),
              ] else ...[
                _buildHadithPickerCard(),
                const SizedBox(height: 12),
                if (_selectedHadith != null) ...[
                  _buildHadithSelectedCard(),
                  const SizedBox(height: 12),
                ],
                _buildHadithSaveButton(),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Top-level branch toggle: Quran | Nawawi-40 Hadith ──
  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _tabChip(
            label: _kQuranTab,
            icon: Icons.menu_book_rounded,
            selected: _tab == _RecitationTab.quran,
            onTap: () => setState(() => _tab = _RecitationTab.quran),
          ),
          _tabChip(
            label: _kHadithTab,
            icon: Icons.auto_stories_rounded,
            selected: _tab == _RecitationTab.hadith,
            onTap: () {
              setState(() => _tab = _RecitationTab.hadith);
              _ensureHadithRulesLoaded();
            },
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? TaqwaColors.domeBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HADITH (Nawawi 40) branch — lazy rule load, picker, preview, save
  // ═══════════════════════════════════════════════════════════════════

  /// Lazily fetch the 42 rules AND the student's memorization map the
  /// first time the hadith tab is opened. Guarded by
  /// [_rulesLoaded]/[_loadingRules] so it runs at most once.
  ///
  /// The two requests run in parallel. A progress-fetch failure is
  /// swallowed (map stays empty, no checkmarks) so recording is never
  /// blocked — the backend UNIQUE(student_id, hadith_number) constraint
  /// still rejects duplicates as the final safety net.
  Future<void> _ensureHadithRulesLoaded() async {
    if (_rulesLoaded || _loadingRules) return;
    setState(() => _loadingRules = true);

    final rulesFuture = _recitationApi.getHadithRules();
    final progressFuture = _recitationApi
        .getStudentHadithProgress(widget.studentId)
        .catchError((Object _) => const HadithProgress.empty());

    try {
      final rules = await rulesFuture;
      final progress = await progressFuture;
      if (!mounted) return;
      setState(() {
        _hadithRules = rules;
        _hadithProgress = progress;
        _rulesLoaded = true;
        _loadingRules = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRules = false);
      _showError(_kLoadError);
    }
  }

  /// The rule matching the current selection, or null.
  HadithRule? get _selectedRule {
    final n = _selectedHadith;
    if (n == null) return null;
    for (final r in _hadithRules) {
      if (r.hadithNumber == n) return r;
    }
    return null;
  }

  Future<void> _openHadithPicker() async {
    if (_hadithRules.isEmpty) {
      await _ensureHadithRulesLoaded();
      if (!mounted || _hadithRules.isEmpty) return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HadithPickerSheet(
        rules: _hadithRules,
        currentHadith: _selectedHadith,
        progress: _hadithProgress,
      ),
    );
    if (picked != null) {
      setState(() => _selectedHadith = picked);
    }
  }

  Widget _buildHadithPickerCard() {
    final hasSelection = _selectedHadith != null;
    return _buildSectionCard(
      icon: Icons.auto_stories_rounded,
      title: _kChooseHadith,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _loadingRules ? null : _openHadithPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasSelection
                    ? TaqwaColors.domeBlue.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasSelection
                        ? TaqwaColors.domeBlue.withValues(alpha: 0.2)
                        : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                      hasSelection
                          ? Icons.menu_book_rounded
                          : Icons.touch_app,
                      color: hasSelection
                          ? TaqwaColors.domeBlue
                          : Colors.grey.shade400,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _loadingRules
                        ? Text(_kLoading,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                color: Colors.grey.shade500))
                        : Text(
                            hasSelection
                                ? '$_kHadithWord $_selectedHadith'
                                : _kTapToChoose,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14.5,
                                fontWeight: hasSelection
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: hasSelection
                                    ? TaqwaColors.domeBlue
                                    : Colors.grey.shade400),
                          ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),

          // Memorization counter — «محفوظ N من 42» — rendered once the
          // rules + progress fetch has completed.
          if (_rulesLoaded) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: TaqwaColors.islamicGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        TaqwaColors.islamicGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: TaqwaColors.islamicGreen),
                  const SizedBox(width: 6),
                  Text(
                    '$_kMemorizedWord ${_hadithProgress.count} $_kOfWord ${_hadithProgress.total}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.islamicGreen),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 90,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _hadithProgress.total == 0
                            ? 0
                            : _hadithProgress.count /
                                _hadithProgress.total,
                        minHeight: 6,
                        backgroundColor: TaqwaColors.islamicGreen
                            .withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(
                            TaqwaColors.islamicGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Selected hadith + its base points, rendered via [PointsDisplay].
  Widget _buildHadithSelectedCard() {
    final rule = _selectedRule;
    if (rule == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TaqwaColors.islamicGreen.withValues(alpha: 0.10),
            TaqwaColors.islamicGreen.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: TaqwaColors.islamicGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: TaqwaColors.islamicGreen,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('$_kHadithWord ${rule.hadithNumber}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue)),
          ),
          PointsDisplay(
            value: rule.basePoints,
            size: PointsDisplaySize.large,
            showLabel: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHadithSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _savingHadith ? null : _saveHadith,
        style: ElevatedButton.styleFrom(
          backgroundColor: TaqwaColors.islamicGreen,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _savingHadith
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.save, size: 20),
                const SizedBox(width: 8),
                Text(_kSaveLabel,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
      ),
    );
  }

  Future<void> _saveHadith() async {
    final hadithNumber = _selectedHadith;
    if (hadithNumber == null) {
      return _showError(_kPleaseChoose);
    }
    // Client-side guard — normally unreachable because the picker blocks
    // memorized ahadith, but kept as defense in depth (e.g. stale state).
    if (_hadithProgress.isMemorized(hadithNumber)) {
      return _showError(_kAlreadyMemorized);
    }
    setState(() => _savingHadith = true);
    try {
      final result = await _recitationApi.recordHadithRecitation(
        studentId: widget.studentId,
        hadithNumber: hadithNumber,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Text(_kSavedOk,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  textDirection: TextDirection.rtl),
              const SizedBox(width: 8),
              PointsDisplay(
                value: result.pointsAwarded,
                showLabel: true,
                colorize: false,
                color: Colors.white,
              ),
            ],
          ),
          backgroundColor: TaqwaColors.islamicGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _showError(_kAlreadyRecorded);
      } else {
        _showError(_kGenericError);
      }
    } catch (_) {
      _showError(_kGenericError);
    } finally {
      if (mounted) setState(() => _savingHadith = false);
    }
  }

  // ── Date ──
  Widget _buildDateCard() {
    return _buildSectionCard(
      icon: Icons.calendar_today,
      title: 'التاريخ',
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_calendar,
                  color: TaqwaColors.domeBlue, size: 20),
              const SizedBox(width: 10),
              Text(_formatDateArabic(_selectedDate),
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── "Did not memorize today" toggle ──
  Widget _buildDidNotMemorizeToggle() {
    final activeColor = const Color(0xFFE74C3C);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
        border: _didNotMemorize
            ? Border.all(color: activeColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: SwitchListTile(
        value: _didNotMemorize,
        onChanged: (v) => setState(() => _didNotMemorize = v),
        activeColor: activeColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text('لم يحفظ اليوم',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        subtitle: Text(
            _didNotMemorize
                ? 'لن يتم احتساب أي نقاط'
                : 'فعّل هذا الخيار عند عدم تسميع الطالب اليوم',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade600)),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _didNotMemorize
                ? activeColor.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
              _didNotMemorize
                  ? Icons.cancel
                  : Icons.cancel_outlined,
              color: _didNotMemorize ? activeColor : Colors.grey.shade400,
              size: 22),
        ),
      ),
    );
  }

  // ── Segment card (header + per-segment mode toggle + body + per-segment rating) ──
  Widget _buildSegmentCard(int index, _RecitationSegment seg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
        border: Border.all(color: TaqwaColors.domeBlue.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: segment number + trash
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TaqwaColors.domeBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              const Text('مقطع',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.domeBlue)),
              const Spacer(),
              if (_segments.length > 1)
                IconButton(
                  tooltip: 'حذف المقطع',
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFE74C3C)),
                  onPressed: () => _removeSegment(seg.id),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Verse range — the only accepted shape.
          ..._buildAyaRangeBody(seg, isFirst: index == 0),

          // Per-segment rating — only shown once the segment has content,
          // to keep the UI clean for empty/just-added segments.
          if (seg.hasContent) ...[
            const SizedBox(height: 14),
            _buildSegmentRatingPicker(seg),
          ],
        ],
      ),
    );
  }

  // ── Per-segment rating picker ──
  Widget _buildSegmentRatingPicker(_RecitationSegment seg) {
    final hasRating = seg.rating.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasRating
            ? TaqwaColors.domeBlue.withValues(alpha: 0.04)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasRating
                ? TaqwaColors.domeBlue.withValues(alpha: 0.15)
                : const Color(0xFFD4AC0D).withValues(alpha: 0.35),
            width: hasRating ? 1 : 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  hasRating
                      ? Icons.star_half
                      : Icons.error_outline,
                  size: 16,
                  color: hasRating
                      ? TaqwaColors.domeBlue
                      : const Color(0xFFD4AC0D)),
              const SizedBox(width: 8),
              Text(
                hasRating ? 'تقييم هذا المقطع' : 'يرجى اختيار تقييم لهذا المقطع',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: hasRating
                        ? Colors.grey.shade700
                        : const Color(0xFF7E5800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _segmentRatings.map((r) {
              final isSelected = seg.rating == r['value'];
              final Color color = r['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => seg.rating = r['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.6)
                            : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(r['icon'] as IconData,
                        size: 14,
                        color:
                            isSelected ? color : Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(r['label'] as String,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? color
                                : Colors.grey.shade700)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Body: aya range ──
  List<Widget> _buildAyaRangeBody(_RecitationSegment seg,
      {required bool isFirst}) {
    final surah = seg.ayaSurah != null ? getAyaSurah(seg.ayaSurah!) : null;
    return [
      InkWell(
        onTap: () => _openAyaSurahPicker(seg),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surah != null
                ? TaqwaColors.domeBlue.withValues(alpha: 0.04)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: surah != null
                    ? TaqwaColors.domeBlue.withValues(alpha: 0.2)
                    : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.library_books_rounded,
                  color: surah != null
                      ? TaqwaColors.domeBlue
                      : Colors.grey.shade400,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: (isFirst && _loadingSuggestion)
                    ? Text('جاري الاقتراح...',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: Colors.grey.shade500))
                    : Text(
                        surah != null
                            ? '${surah.nameAr}  (${surah.numAyas} آية)'
                            : 'اضغط لاختيار السورة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.5,
                            fontWeight: surah != null
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: surah != null
                                ? TaqwaColors.domeBlue
                                : Colors.grey.shade400),
                      ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
      if (surah != null) ...[
        const SizedBox(height: 12),
        _ayaStepperRow('من آية', seg.startAya, 1, surah.numAyas, (v) {
          setState(() {
            seg.startAya = v;
            if (seg.endAya < seg.startAya) seg.endAya = seg.startAya;
          });
        }),
        const SizedBox(height: 10),
        _ayaStepperRow('إلى آية', seg.endAya, seg.startAya, surah.numAyas, (v) {
          setState(() => seg.endAya = v);
        }),
        const SizedBox(height: 12),
        _buildSegmentMeasurePill(seg),
      ],
    ];
  }

  /// What this segment actually measures: the ayah count (the exact figure
  /// the points formula is built on) and the mushaf pages it spans. Both are
  /// shown so the instructor can sanity-check the range before saving.
  Widget _buildSegmentMeasurePill(_RecitationSegment seg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TaqwaColors.domeBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TaqwaColors.domeBlue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_list_numbered,
              size: 18, color: TaqwaColors.domeBlue),
          const SizedBox(width: 8),
          Text('${seg.verseCount} آية',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.domeBlue)),
          const Spacer(),
          Icon(Icons.description, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('${_formatPages(seg.pages)} ص',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  // ── Add-segment button ──
  Widget _buildAddSegmentButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addSegment,
        icon: const Icon(Icons.add, color: TaqwaColors.domeBlue),
        label: const Text('إضافة مقطع',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: TaqwaColors.domeBlue)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: TaqwaColors.domeBlue.withValues(alpha: 0.3)),
          backgroundColor: TaqwaColors.domeBlue.withValues(alpha: 0.04),
        ),
      ),
    );
  }

  // ── Total pages summary ──
  Widget _buildTotalPagesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TaqwaColors.islamicGreen.withValues(alpha: 0.10),
            TaqwaColors.islamicGreen.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: TaqwaColors.islamicGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: TaqwaColors.islamicGreen,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calculate_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي التسميع',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text('$_totalVerses آية',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.islamicGreen)),
                Text('${_formatPages(_totalPages)} صفحة من المصحف',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (_segments.length > 1)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_segments.length} مقاطع',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
            ),
        ],
      ),
    );
  }

  // ── Aya stepper ──
  Widget _ayaStepperRow(String label, int value, int min, int max,
      ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
        const SizedBox(width: 8),
        _pageButton(
            icon: Icons.remove,
            onTap: () {
              if (value > min) onChanged(value - 1);
            }),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await _promptForAyaNumber(value, min, max);
              if (picked != null) onChanged(picked);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text('$value',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue)),
              ),
            ),
          ),
        ),
        _pageButton(
            icon: Icons.add,
            onTap: () {
              if (value < max) onChanged(value + 1);
            }),
      ],
    );
  }

  Future<int?> _promptForAyaNumber(int current, int min, int max) async {
    final controller = TextEditingController(text: '$current');
    return showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('رقم الآية',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.domeBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أدخل رقماً بين $min و $max',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: TaqwaColors.domeBlue)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                if (n == null || n < min || n > max) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: const Text('رقم غير صالح',
                        style: TextStyle(fontFamily: 'Cairo'),
                        textDirection: TextDirection.rtl),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: const Text('موافق',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Homework / Save ──
  Widget _buildHomeworkSection() {
    return _buildSectionCard(
      icon: Icons.assignment,
      title: 'الواجب',
      child: TextField(
        controller: _homeworkController,
        textDirection: TextDirection.rtl,
        maxLines: 3,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'أدخل الواجب للطالب (اختياري)...',
          hintStyle:
              TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TaqwaColors.domeBlue)),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: TaqwaColors.islamicGreen,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.save, size: 20),
                SizedBox(width: 8),
                Text('حفظ التسميع',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
      ),
    );
  }

  // ── Misc helpers ──
  Widget _buildSectionCard({
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
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: TaqwaColors.domeBlue),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.domeBlue)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _pageButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: TaqwaColors.domeBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: TaqwaColors.domeBlue)),
      ),
    );
  }

  String _formatPages(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _formatDateArabic(DateTime date) {
    final dayNames = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    final months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${dayNames[date.weekday - 1]} ${date.day} ${months[date.month]} ${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// AYA-MODE SURAH PICKER (single-select bottom sheet)
// ═══════════════════════════════════════════════════════════════════
class _AyaSurahPickerSheet extends StatefulWidget {
  final int? currentSurah;
  const _AyaSurahPickerSheet({this.currentSurah});

  @override
  State<_AyaSurahPickerSheet> createState() => _AyaSurahPickerSheetState();
}

class _AyaSurahPickerSheetState extends State<_AyaSurahPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = kAyaSurahs.where((s) {
      if (_query.isEmpty) return true;
      return s.nameAr.contains(_query) || s.number.toString().contains(_query);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('اختر السورة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'بحث...',
                  hintStyle: const TextStyle(fontFamily: 'Cairo'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TaqwaColors.domeBlue)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  final selected = s.number == widget.currentSurah;
                  return ListTile(
                    onTap: () => Navigator.pop(context, s.number),
                    leading: CircleAvatar(
                      backgroundColor: selected
                          ? TaqwaColors.domeBlue
                          : TaqwaColors.domeBlue.withValues(alpha: 0.1),
                      child: Text('${s.number}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Colors.white
                                  : TaqwaColors.domeBlue)),
                    ),
                    title: Text(s.nameAr,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                    subtitle: Text('${s.numAyas} آية',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.grey.shade600)),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: TaqwaColors.islamicGreen)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HADITH PICKER (single-select bottom sheet) — Nawawi 40
//
// Modeled on _AyaSurahPickerSheet. Filters by hadith number or title;
// each row shows «الحديث N» with its base points «— M نقطة» rendered
// through the design-system PointsDisplay widget.
//
// MEMORIZATION MAP: rows whose hadith is already memorized (per the
// [progress] map, cumulative across terms) are rendered with an
// islamicGreen check and CANNOT be selected — tapping one shows an
// informational snackbar instead. The sheet header shows the
// «محفوظ N من 42» counter.
// ═══════════════════════════════════════════════════════════════════
class _HadithPickerSheet extends StatefulWidget {
  final List<HadithRule> rules;
  final int? currentHadith;
  final HadithProgress progress;
  const _HadithPickerSheet({
    required this.rules,
    this.currentHadith,
    this.progress = const HadithProgress.empty(),
  });

  @override
  State<_HadithPickerSheet> createState() => _HadithPickerSheetState();
}

class _HadithPickerSheetState extends State<_HadithPickerSheet> {
  String _query = '';

  void _showMemorizedNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_AddRecitationScreenState._kAlreadyMemorized,
          style: const TextStyle(fontFamily: 'Cairo'),
          textDirection: TextDirection.rtl),
      backgroundColor: TaqwaColors.islamicGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.rules.where((r) {
      if (_query.isEmpty) return true;
      final title = r.title ?? '';
      return r.hadithNumber.toString().contains(_query) ||
          title.contains(_query);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(_AddRecitationScreenState._kChooseHadith,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue)),
            const SizedBox(height: 6),

            // «محفوظ N من 42» counter chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TaqwaColors.islamicGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: TaqwaColors.islamicGreen),
                  const SizedBox(width: 4),
                  Text(
                    '${_AddRecitationScreenState._kMemorizedWord} ${widget.progress.count} ${_AddRecitationScreenState._kOfWord} ${widget.progress.total}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.islamicGreen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: _AddRecitationScreenState._kSearchHint,
                  hintStyle: const TextStyle(fontFamily: 'Cairo'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: TaqwaColors.domeBlue)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final r = filtered[i];
                  final selected = r.hadithNumber == widget.currentHadith;
                  final memorized =
                      widget.progress.isMemorized(r.hadithNumber);
                  return ListTile(
                    onTap: memorized
                        ? () => _showMemorizedNotice(context)
                        : () => Navigator.pop(context, r.hadithNumber),
                    tileColor: memorized
                        ? TaqwaColors.islamicGreen.withValues(alpha: 0.05)
                        : null,
                    shape: memorized
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))
                        : null,
                    leading: CircleAvatar(
                      backgroundColor: memorized
                          ? TaqwaColors.islamicGreen
                          : selected
                              ? TaqwaColors.domeBlue
                              : TaqwaColors.domeBlue
                                  .withValues(alpha: 0.1),
                      child: Text('${r.hadithNumber}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: (memorized || selected)
                                  ? Colors.white
                                  : TaqwaColors.domeBlue)),
                    ),
                    title: Text(
                        '${_AddRecitationScreenState._kHadithWord} ${r.hadithNumber}',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: memorized
                                ? TaqwaColors.islamicGreen
                                : null)),
                    subtitle: memorized
                        ? Text(_AddRecitationScreenState._kMemorizedBadge,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: TaqwaColors.islamicGreen))
                        : (r.title != null && r.title!.isNotEmpty)
                            ? Text(r.title!,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.grey.shade600))
                            : null,
                    trailing: memorized
                        ? const Icon(Icons.check_circle,
                            color: TaqwaColors.islamicGreen, size: 24)
                        : PointsDisplay(
                            value: r.basePoints,
                            size: PointsDisplaySize.small,
                            showLabel: true,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}