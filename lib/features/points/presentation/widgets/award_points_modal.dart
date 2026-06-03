import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/points_api.dart';

/// Modal sheet that lets an instructor award (or deduct) points to a
/// specific student. The student is pre-filled. The instructor either:
///   1. Picks a predefined rule (amount is locked to the rule's value), OR
///   2. Uses the "نقاط مخصصة" section to enter a custom amount AND a
///      required reason.
///
/// In both cases the backend logs the entry as `sourceType = 'MANUAL'`
/// with a meaningful description, so the admin's points tab will show
/// it as "نقاط خاصة" with the rule name (or the custom reason) as the
/// title.
class AwardPointsModal extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AwardPointsModal({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String studentId,
    required String studentName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => AwardPointsModal(
        studentId: studentId,
        studentName: studentName,
      ),
    );
  }

  @override
  State<AwardPointsModal> createState() => _AwardPointsModalState();
}

class _AwardPointsModalState extends State<AwardPointsModal>
    with TickerProviderStateMixin {
  static const int _maxCustomPoints = 9999;

  final _pointsApi = PointsApi(ApiClient.instance);

  final _customAmountController = TextEditingController();
  final _customReasonController = TextEditingController();
  late final AnimationController _fadeController;

  List<Map<String, dynamic>> _earnRules = [];
  List<Map<String, dynamic>> _deductRules = [];
  bool _loadingRules = true;
  bool _isSaving = false;

  String? _selectedRuleId;
  bool _customMode = false;
  bool _customIsEarn = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _customAmountController.addListener(_onCustomFieldChanged);
    _customReasonController.addListener(_onCustomFieldChanged);
    _loadRules();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _customReasonController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadRules() async {
    try {
      final rules = await _pointsApi.getManualRules();
      if (!mounted) return;

      final earn = <Map<String, dynamic>>[];
      final deduct = <Map<String, dynamic>>[];
      for (final r in rules) {
        final pts = ((r['points'] as num?) ?? 0).toInt();
        if (pts >= 0) {
          earn.add(r);
        } else {
          deduct.add(r);
        }
      }
      earn.sort((a, b) =>
          ((b['points'] as num?) ?? 0).compareTo((a['points'] as num?) ?? 0));
      deduct.sort((a, b) =>
          ((a['points'] as num?) ?? 0).compareTo((b['points'] as num?) ?? 0));

      setState(() {
        _earnRules = earn;
        _deductRules = deduct;
        _loadingRules = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRules = false);
      _showError('فشل تحميل القواعد: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SELECTION
  // ═══════════════════════════════════════════════════════════
  void _onRuleSelected(Map<String, dynamic> rule) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRuleId = rule['id'] as String?;
      _customMode = false;
      _customAmountController.clear();
      _customReasonController.clear();
    });
  }

  void _activateCustomMode() {
    if (_customMode && _selectedRuleId == null) return;
    setState(() {
      _customMode = true;
      _selectedRuleId = null;
    });
  }

  void _onEarnDeductTapped(bool isEarn) {
    HapticFeedback.selectionClick();
    setState(() {
      _customIsEarn = isEarn;
      _customMode = true;
      _selectedRuleId = null;
    });
  }

  void _onCustomFieldChanged() {
    if (_customAmountController.text.isNotEmpty ||
        _customReasonController.text.isNotEmpty) {
      if (!_customMode || _selectedRuleId != null) {
        setState(() {
          _customMode = true;
          _selectedRuleId = null;
        });
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  // ═══════════════════════════════════════════════════════════
  // VALIDATION + SUBMIT
  // ═══════════════════════════════════════════════════════════
  bool get _canSubmit {
    if (_isSaving) return false;
    if (_selectedRuleId != null) return true;
    if (_customMode) {
      final amount = int.tryParse(_customAmountController.text.trim()) ?? 0;
      final reason = _customReasonController.text.trim();
      return amount > 0 && reason.isNotEmpty;
    }
    return false;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSaving = true);

    try {
      if (_selectedRuleId != null) {
        await _pointsApi.awardManualPoints(
          studentId: widget.studentId,
          ruleId: _selectedRuleId,
        );
      } else {
        final rawAmount =
            int.tryParse(_customAmountController.text.trim()) ?? 0;
        if (rawAmount <= 0) throw 'يرجى إدخال عدد نقاط صالح';
        if (rawAmount > _maxCustomPoints) {
          throw 'الحد الأقصى $_maxCustomPoints نقطة';
        }
        final reason = _customReasonController.text.trim();
        if (reason.isEmpty) throw 'يرجى إدخال السبب';
        final signedAmount = _customIsEarn ? rawAmount : -rawAmount;

        await _pointsApi.awardManualPoints(
          studentId: widget.studentId,
          amount: signedAmount,
          reason: reason,
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = mq.size.height * 0.92;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _fadeController, curve: Curves.easeOut),
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
              Expanded(
                child: _loadingRules
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: TaqwaColors.domeBlue),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_earnRules.isNotEmpty) ...[
                              _buildSectionLabel(
                                'إضافة نقاط',
                                TaqwaColors.islamicGreen,
                                Icons.add_circle_outline,
                              ),
                              const SizedBox(height: 10),
                              _buildRulesGrid(
                                  _earnRules, TaqwaColors.islamicGreen),
                              const SizedBox(height: 22),
                            ],
                            if (_deductRules.isNotEmpty) ...[
                              _buildSectionLabel(
                                'خصم نقاط',
                                Colors.red,
                                Icons.remove_circle_outline,
                              ),
                              const SizedBox(height: 10),
                              _buildRulesGrid(_deductRules, Colors.red),
                              const SizedBox(height: 22),
                            ],
                            _buildSectionLabel(
                              'نقاط مخصصة',
                              TaqwaColors.minaretGold,
                              Icons.edit_note_rounded,
                            ),
                            const SizedBox(height: 10),
                            _buildCustomSection(),
                          ],
                        ),
                      ),
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TaqwaColors.minaretGold,
                  TaqwaColors.minaretGold.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: TaqwaColors.minaretGold.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.star_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إضافة نقاط',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue,
                  ),
                ),
                Text(
                  widget.studentName,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              child: const Icon(Icons.close,
                  size: 18, color: Colors.black54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRulesGrid(List<Map<String, dynamic>> rules, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rules.map((rule) {
        final isSelected = _selectedRuleId == rule['id'];
        final pts = ((rule['points'] as num?) ?? 0).toInt();
        final nameAr = (rule['nameAr'] as String?) ?? '';
        final isPerPage = (rule['isPerPage'] as bool?) ?? false;

        return GestureDetector(
          onTap: () => _onRuleSelected(rule),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.14)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : (pts >= 0
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline),
                  size: 17,
                  color: isSelected ? color : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    nameAr,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isPerPage
                      ? '(${pts >= 0 ? '+' : ''}$pts/ص)'
                      : '(${pts >= 0 ? '+' : ''}$pts)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomSection() {
    final isActive = _customMode;
    final accent = isActive
        ? (_customIsEarn ? TaqwaColors.islamicGreen : Colors.red)
        : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildEarnDeductButton(
                  label: 'إضافة +',
                  icon: Icons.add_circle,
                  color: TaqwaColors.islamicGreen,
                  selected: isActive && _customIsEarn,
                  onTap: () => _onEarnDeductTapped(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildEarnDeductButton(
                  label: 'خصم −',
                  icon: Icons.remove_circle,
                  color: Colors.red,
                  selected: isActive && !_customIsEarn,
                  onTap: () => _onEarnDeductTapped(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customAmountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onTap: _activateCustomMode,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'عدد النقاط',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              hintText: 'مثال: 10',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(Icons.numbers, color: accent),
              filled: true,
              fillColor: const Color(0xFFFAFAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customReasonController,
            maxLines: 2,
            maxLength: 200,
            onTap: _activateCustomMode,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            decoration: InputDecoration(
              labelText: 'السبب *',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              hintText: 'اكتب سبب إضافة أو خصم النقاط',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(Icons.edit_note, color: accent),
              filled: true,
              fillColor: const Color(0xFFFAFAFB),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'السبب مطلوب — سيظهر لمشرف النظام لمعرفة سبب التعديل',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnDeductButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? color : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmBar() {
    final enabled = _canSubmit;
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
              onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                onPressed: enabled ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TaqwaColors.islamicGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: TaqwaColors.islamicGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: enabled ? 4 : 0,
                  shadowColor:
                      TaqwaColors.islamicGreen.withValues(alpha: 0.4),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'تأكيد',
                            style: TextStyle(
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
