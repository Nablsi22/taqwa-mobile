import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/term_model.dart';
import '../providers/term_provider.dart';

/// «إدارة الدورات» — admin-only.
///
/// Lists every course past and present, creates new ones, and switches which
/// one is active. Activating a course does not delete or reset anything:
/// students and all previous courses keep their data, and the new course
/// simply has no points yet, so every balance in it starts at 0.
class AdminTermsScreen extends StatefulWidget {
  const AdminTermsScreen({super.key});

  @override
  State<AdminTermsScreen> createState() => _AdminTermsScreenState();
}

class _AdminTermsScreenState extends State<AdminTermsScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guarded: a fast back-tap can pop this screen before the frame
      // callback runs, and reading a provider off a deactivated element
      // throws.
      if (!mounted) return;
      context.read<TermProvider>().load(force: true);
    });
  }

  // ═════════════════════════════════════════════════════════════════
  // Actions
  // ═════════════════════════════════════════════════════════════════

  Future<void> _activate(Term term) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تفعيل الدورة',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(
            'سيتم تفعيل «${term.nameAr}» وإغلاق الدورة الحالية.\n\n'
            '• لن يتم حذف أي طالب.\n'
            '• لن تُحذف أو تتغيّر نقاط الدورات السابقة.\n'
            '• نقاط الدورة الجديدة تبدأ من 0 لكل الطلاب.',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: TaqwaColors.islamicGreen),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تفعيل',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<TermProvider>().activate(term.id);
      _toast('تم تفعيل «${term.nameAr}»', TaqwaColors.islamicGreen);
    } catch (e) {
      _toast(e.toString(), TaqwaColors.alertRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTermSheet(),
    );
    if (created == true && mounted) {
      _toast('تم إنشاء الدورة بنجاح', TaqwaColors.islamicGreen);
    }
  }

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontFamily: 'Cairo'),
          textDirection: TextDirection.rtl),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═════════════════════════════════════════════════════════════════
  // Build
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TermProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('إدارة الدورات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _openCreateSheet,
          backgroundColor: TaqwaColors.domeBlue,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('دورة جديدة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        body: RefreshIndicator(
          onRefresh: () => provider.load(force: true),
          child: provider.isLoading && provider.terms.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.terms.isEmpty
                  ? _buildEmpty(provider.error)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        _buildExplainer(),
                        const SizedBox(height: 14),
                        for (final term in provider.terms) ...[
                          _buildTermCard(term),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String? error) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          error ?? 'لا توجد دورات بعد. أنشئ أول دورة للبدء.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildExplainer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaqwaColors.lightBlue,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: TaqwaColors.domeBlue.withValues(alpha: 0.15)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: TaqwaColors.domeBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'كل دورة مستقلة تماماً بنقاطها وترتيبها وإحصائياتها. '
              'تفعيل دورة جديدة لا يحذف أي طالب ولا يمسّ نقاط الدورات السابقة — '
              'الدورة الجديدة تبدأ ببساطة من 0.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.7,
                  color: TaqwaColors.domeBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermCard(Term term) {
    final accent =
        term.isActive ? TaqwaColors.islamicGreen : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: term.isActive
              ? TaqwaColors.islamicGreen.withValues(alpha: 0.35)
              : Colors.grey.shade200,
          width: term.isActive ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                    term.isActive
                        ? Icons.event_available_rounded
                        : Icons.history_rounded,
                    size: 20,
                    color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(term.nameAr,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: TaqwaColors.domeBlue)),
                    const SizedBox(height: 2),
                    Text(term.periodLabel,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              if (term.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: TaqwaColors.islamicGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('الدورة الحالية',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: TaqwaColors.islamicGreen)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('الطلاب', '${term.activeStudentCount}',
                  Icons.people_alt_outlined),
              const SizedBox(width: 8),
              _stat('التسميعات', '${term.recitationCount}',
                  Icons.menu_book_rounded),
              const SizedBox(width: 8),
              _stat('النقاط', _formatPoints(term.totalPoints),
                  Icons.stars_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          context.read<TermProvider>().viewTerm(term.id);
                          _toast('يتم الآن عرض «${term.nameAr}»',
                              TaqwaColors.domeBlue);
                        },
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('عرض بياناتها',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TaqwaColors.domeBlue,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                        color:
                            TaqwaColors.domeBlue.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
              if (!term.isActive) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _activate(term),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('تفعيل',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: TaqwaColors.islamicGreen,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue)),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  static String _formatPoints(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

// ═══════════════════════════════════════════════════════════════════
// CREATE SHEET
// ═══════════════════════════════════════════════════════════════════

class _CreateTermSheet extends StatefulWidget {
  const _CreateTermSheet();

  @override
  State<_CreateTermSheet> createState() => _CreateTermSheetState();
}

class _CreateTermSheetState extends State<_CreateTermSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameController = TextEditingController();

  DateTime _startDate = DateTime.now();
  bool _activateNow = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameArController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Suggest a slug from the season and year so the admin rarely has to think
  /// about the Latin identifier at all. `الدورة الصيفية 2027` → `summer-2027`.
  void _suggestSlug() {
    if (_nameController.text.trim().isNotEmpty) return;
    final ar = _nameArController.text;
    final year = RegExp(r'(\d{4})').firstMatch(ar)?.group(1) ??
        '${_startDate.year}';
    String season;
    if (ar.contains('صيف')) {
      season = 'summer';
    } else if (ar.contains('شتو') || ar.contains('شتاء')) {
      season = 'winter';
    } else if (ar.contains('ربيع')) {
      season = 'spring';
    } else if (ar.contains('خريف')) {
      season = 'autumn';
    } else {
      season = 'term';
    }
    _nameController.text = '$season-$year';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<TermProvider>().create(
            name: _nameController.text.trim(),
            nameAr: _nameArController.text.trim(),
            startDate: _startDate,
            activateNow: _activateNow,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('دورة جديدة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue)),
                const SizedBox(height: 4),
                Text(
                  'مثال: الدورة الصيفية 2027 — نقاطها تبدأ من 0 دون المساس بأي بيانات سابقة.',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600),
                ),
                const SizedBox(height: 18),

                _label('اسم الدورة'),
                TextFormField(
                  controller: _nameArController,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: _decoration('الدورة الصيفية 2027'),
                  onChanged: (_) => _suggestSlug(),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'يرجى إدخال اسم الدورة'
                      : null,
                ),
                const SizedBox(height: 14),

                _label('المعرّف (أحرف لاتينية وأرقام و«-»)'),
                TextFormField(
                  controller: _nameController,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: _decoration('summer-2027'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'يرجى إدخال المعرّف';
                    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(value)) {
                      return 'أحرف لاتينية وأرقام و«-» فقط';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('تاريخ البداية'),
                InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 17, color: TaqwaColors.domeBlue),
                        const SizedBox(width: 10),
                        Text(
                          '${_startDate.year}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                SwitchListTile.adaptive(
                  value: _activateNow,
                  onChanged: (v) => setState(() => _activateNow = v),
                  activeThumbColor: TaqwaColors.islamicGreen,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تفعيلها الآن',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'إغلاق الدورة الحالية وبدء تسجيل النقاط في هذه الدورة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: TaqwaColors.alertRed)),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: TaqwaColors.domeBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('إنشاء الدورة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700)),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TaqwaColors.domeBlue),
        ),
      );
}
