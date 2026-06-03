import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/announcement_api.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final Map<String, dynamic>? announcement; // null = create mode

  const CreateAnnouncementScreen({super.key, this.announcement});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _api = AnnouncementApi(ApiClient.instance);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _pinned = false;
  bool _isSaving = false;
  DateTime? _expiresAt;

  bool get _isEdit => widget.announcement != null;

  String get _userRole {
    try {
      return context.read<AuthProvider>().user?.role.value ?? 'STUDENT';
    } catch (_) {
      return 'STUDENT';
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final ann = widget.announcement!;
      _titleController.text = ann['title'] ?? '';
      _bodyController.text = ann['body'] ?? '';
      _pinned = ann['pinned'] == true;
      if (ann['expiresAt'] != null) {
        try {
          _expiresAt = DateTime.parse(ann['expiresAt']);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // ─── Pick expiry date ─────────────────────────────────────────────────────
  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ الانتهاء',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  // ─── Save announcement ────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEdit) {
        await _api.update(
          widget.announcement!['id'],
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          pinned: _pinned,
          expiresAt: _expiresAt?.toIso8601String(),
        );
      } else {
        await _api.create(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          pinned: _pinned,
          expiresAt: _expiresAt?.toIso8601String(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'تم تعديل الإعلان بنجاح' : 'تم نشر الإعلان بنجاح',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: TaqwaColors.islamicGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'فشل في تعديل الإعلان: $e' : 'فشل في نشر الإعلان: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'ADMIN';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            _isEdit ? 'تعديل الإعلان' : 'إعلان جديد',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: TaqwaColors.domeBlue,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Scope Info Banner ──
                _buildScopeBanner(isAdmin),
                const SizedBox(height: 20),

                // ── Title Field ──
                _buildSectionLabel('عنوان الإعلان'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
                  decoration: _inputDecoration(
                    hint: 'أدخل عنوان الإعلان',
                    icon: Icons.title,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'عنوان الإعلان مطلوب';
                    }
                    if (v.trim().length > 200) {
                      return 'العنوان يجب أن لا يتجاوز 200 حرف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Body Field ──
                _buildSectionLabel('نص الإعلان'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bodyController,
                  textDirection: TextDirection.rtl,
                  maxLines: 6,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                  decoration: _inputDecoration(
                    hint: 'اكتب نص الإعلان هنا...',
                    icon: Icons.description,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'نص الإعلان مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Options Section ──
                _buildSectionLabel('خيارات إضافية'),
                const SizedBox(height: 12),

                // Pin toggle (admin only)
                if (isAdmin)
                  _buildOptionTile(
                    icon: Icons.push_pin_outlined,
                    title: 'تثبيت الإعلان',
                    subtitle: 'يظهر في أعلى القائمة دائماً',
                    trailing: Switch(
                      value: _pinned,
                      onChanged: (v) => setState(() => _pinned = v),
                      activeThumbColor: TaqwaColors.minaretGold,
                    ),
                  ),

                // Expiry date
                GestureDetector(
                  onTap: _pickExpiryDate,
                  child: _buildOptionTile(
                    icon: Icons.event,
                    title: 'تاريخ الانتهاء',
                    subtitle: _expiresAt != null
                        ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                        : 'بدون تاريخ انتهاء (اختياري)',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_expiresAt != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () =>
                                setState(() => _expiresAt = null),
                            color: Colors.grey,
                          ),
                        Icon(Icons.calendar_today,
                            size: 20, color: TaqwaColors.domeBlue),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Save Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _isSaving
                          ? 'جارٍ الحفظ...'
                          : (_isEdit ? 'حفظ التعديلات' : 'نشر الإعلان'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaqwaColors.domeBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildScopeBanner(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAdmin
            ? TaqwaColors.domeBlue.withOpacity(0.08)
            : TaqwaColors.islamicGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin
              ? TaqwaColors.domeBlue.withOpacity(0.2)
              : TaqwaColors.islamicGreen.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.campaign : Icons.group,
            color:
                isAdmin ? TaqwaColors.domeBlue : TaqwaColors.islamicGreen,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'إعلان عام' : 'إعلان للطلاب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isAdmin
                        ? TaqwaColors.domeBlue
                        : TaqwaColors.islamicGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAdmin
                      ? 'سيصل هذا الإعلان لجميع المعلمين والطلاب'
                      : 'سيصل هذا الإعلان لطلابك فقط',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1B2A4A),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Cairo',
        color: Colors.grey[400],
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: TaqwaColors.domeBlue, size: 22),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: TaqwaColors.domeBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: TaqwaColors.domeBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
