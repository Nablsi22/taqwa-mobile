import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/constants/quran_metadata.dart';

/// Result returned when the user confirms a selection.
class SuraMultiSelectResult {
  final List<int> selectedSurahNumbers;
  final double totalPages;

  const SuraMultiSelectResult({
    required this.selectedSurahNumbers,
    required this.totalPages,
  });
}

/// Professional multi-select surah picker with animations and live
/// page-count calculation based on the local Madinah-mushaf metadata.
class SuraMultiSelectPicker extends StatefulWidget {
  final List<int> initialSelection;

  const SuraMultiSelectPicker({
    super.key,
    this.initialSelection = const [],
  });

  /// Opens the picker as a full-height modal bottom sheet.
  /// Returns null if the user cancels.
  static Future<SuraMultiSelectResult?> show({
    required BuildContext context,
    List<int> initialSelection = const [],
  }) {
    return showModalBottomSheet<SuraMultiSelectResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => SuraMultiSelectPicker(
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  State<SuraMultiSelectPicker> createState() => _SuraMultiSelectPickerState();
}

class _SuraMultiSelectPickerState extends State<SuraMultiSelectPicker>
    with TickerProviderStateMixin {
  late final Set<int> _selected;
  late final TextEditingController _searchController;
  late final AnimationController _fadeController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelection);
    _searchController = TextEditingController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ─── Derived values ──────────────────────────────────────

  double get _totalPages {
    double total = 0;
    for (final s in suraList) {
      if (_selected.contains(s.number)) {
        total += s.totalPages.toDouble();
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  List<SuraInfo> get _filteredSuras {
    if (_searchQuery.isEmpty) return suraList;
    return suraList.where((s) => s.nameAr.contains(_searchQuery)).toList();
  }

  // ─── Actions ─────────────────────────────────────────────

  void _toggleSurah(int number) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(number)) {
        _selected.remove(number);
      } else {
        _selected.add(number);
      }
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() => _selected.clear());
  }

  void _confirm() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى اختيار سورة واحدة على الأقل',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Preserve ascending order from suraList
    final ordered = <int>[];
    for (final s in suraList) {
      if (_selected.contains(s.number)) ordered.add(s.number);
    }

    Navigator.pop(
      context,
      SuraMultiSelectResult(
        selectedSurahNumbers: ordered,
        totalPages: _totalPages,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height * 0.92;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _fadeController,
          curve: Curves.easeOut,
        ),
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              _buildSearchBar(),
              _buildStatsBar(),
              Expanded(child: _buildSurahList()),
              _buildConfirmBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 44,
      height: 4.5,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TaqwaColors.domeBlue,
                  TaqwaColors.domeBlue.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: TaqwaColors.domeBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر السور',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue,
                  ),
                ),
                Text(
                  'يمكنك اختيار أكثر من سورة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.black54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'ابحث عن سورة...',
            hintStyle: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: TaqwaColors.domeBlue,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    color: Colors.grey,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.check_circle_rounded,
              iconColor: TaqwaColors.islamicGreen,
              label: 'السور المحددة',
              value: '${_selected.length}',
              isDecimal: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              icon: Icons.description_rounded,
              iconColor: TaqwaColors.domeBlue,
              label: 'إجمالي الصفحات',
              value: _totalPages.toString(),
              isDecimal: true,
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(width: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _clearAll,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.red.shade400,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDecimal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: double.tryParse(value) ?? 0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (_, animatedValue, __) {
                    final display = isDecimal
                        ? (animatedValue.truncateToDouble() == animatedValue
                            ? animatedValue.toInt().toString()
                            : animatedValue.toStringAsFixed(2))
                        : animatedValue.toInt().toString();
                    return Text(
                      display,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList() {
    final suras = _filteredSuras;

    if (suras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      itemCount: suras.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final sura = suras[index];
        final isSelected = _selected.contains(sura.number);
        return _buildSuraTile(sura: sura, isSelected: isSelected);
      },
    );
  }

  Widget _buildSuraTile({required SuraInfo sura, required bool isSelected}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? TaqwaColors.skyBlue.withValues(alpha: 0.14)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? TaqwaColors.domeBlue.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: TaqwaColors.domeBlue.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _toggleSurah(sura.number),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              TaqwaColors.domeBlue,
                              TaqwaColors.domeBlue.withValues(alpha: 0.8),
                            ]
                          : [
                              TaqwaColors.minaretGold.withValues(alpha: 0.14),
                              TaqwaColors.minaretGold.withValues(alpha: 0.08),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${sura.number}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : TaqwaColors.minaretGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sura.nameAr,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? TaqwaColors.domeBlue
                              : const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_rounded,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'الجزء ${sura.juzStart}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.description_outlined,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatPages(sura.totalPages.toDouble()),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TaqwaColors.islamicGreen
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? TaqwaColors.islamicGreen
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPages(double pages) {
    if (pages == pages.truncateToDouble()) {
      return '${pages.toInt()} صفحة';
    }
    return '${pages.toStringAsFixed(2)} صفحة';
  }

  Widget _buildConfirmBar() {
    final enabled = _selected.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: enabled ? 1.0 : 0.55,
              child: ElevatedButton(
                onPressed: enabled ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TaqwaColors.domeBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: TaqwaColors.domeBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: enabled ? 4 : 0,
                  shadowColor: TaqwaColors.domeBlue.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      enabled
                          ? 'تأكيد (${_selected.length})'
                          : 'اختر على الأقل سورة',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}