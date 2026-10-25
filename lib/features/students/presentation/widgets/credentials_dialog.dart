import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

/// One-time credentials dialog. Shown immediately after a new student is
/// created OR after a password reset. The plain password is in memory only —
/// once this dialog is closed, the password is GONE FOREVER. The admin must
/// either copy it or send it via WhatsApp before closing.
class CredentialsDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String username;
  final String password;
  final String? phone1;
  final String? phone2;

  /// True if this is a freshly-created student. False if it's a reset.
  /// Affects the title and the warning copy.
  final bool isNewStudent;

  const CredentialsDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.username,
    required this.password,
    required this.isNewStudent,
    this.phone1,
    this.phone2,
  });

  /// Convenience launcher used by both the create and reset flows.
  static Future<void> show({
    required BuildContext context,
    required String studentId,
    required String studentName,
    required String username,
    required String password,
    required bool isNewStudent,
    String? phone1,
    String? phone2,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // Force the admin to consciously close it
      builder: (_) => CredentialsDialog(
        studentId: studentId,
        studentName: studentName,
        username: username,
        password: password,
        isNewStudent: isNewStudent,
        phone1: phone1,
        phone2: phone2,
      ),
    );
  }

  @override
  State<CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<CredentialsDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleIn;
  late final Animation<double> _fadeIn;

  bool _markingAsSent = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();

    _scaleIn = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ $label',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: TaqwaColors.islamicGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copyAll() {
    final text = _buildMessage();
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ بيانات الدخول بالكامل',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: TaqwaColors.islamicGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildMessage() {
    return 'السلام عليكم ورحمة الله و بركاته\n\n'
        'بيانات دخول ابنكم ${widget.studentName} لتطبيق التقوى:\n\n'
        'اسم المستخدم: ${widget.username}\n'
        'كلمة المرور: ${widget.password}\n\n'
        'يمكنكم تحميل التطبيق من المتجر.';
  }

  /// Normalize a phone string into the international format that WhatsApp
  /// expects in wa.me URLs (no `+`, no spaces, no leading 0).
  /// Accepts +963XXXXXXXXX, 963XXXXXXXXX, or 09XXXXXXXX (Syrian).
  String? _normalizePhone(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('+963')) return cleaned.substring(1);
    if (cleaned.startsWith('963')) return cleaned;
    if (cleaned.startsWith('09')) return '963${cleaned.substring(1)}';
    return null;
  }

  Future<void> _sendWhatsApp(String? phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized == null) {
      _showError('رقم الهاتف غير صالح');
      return;
    }

    final encodedMessage = Uri.encodeComponent(_buildMessage());
    final uri = Uri.parse('https://wa.me/$normalized?text=$encodedMessage');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showError('تعذر فتح واتساب');
        return;
      }

      // Mark as sent on the backend (best-effort, non-blocking).
      await _markAsSent();
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  Future<void> _markAsSent() async {
    if (_markingAsSent) return;
    setState(() => _markingAsSent = true);
    try {
      await ApiClient.instance.post(
        '/students/${widget.studentId}/mark-credentials-sent',
      );
    } catch (e) {
      // Silent failure — the credentials were still delivered, the
      // admin can manually mark as sent later from the credentials page.
      debugPrint('mark-credentials-sent failed: $e');
    } finally {
      if (mounted) setState(() => _markingAsSent = false);
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

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final phones = <String>[
      if (widget.phone1 != null && widget.phone1!.isNotEmpty) widget.phone1!,
      if (widget.phone2 != null && widget.phone2!.isNotEmpty) widget.phone2!,
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FadeTransition(
        opacity: _fadeIn,
        child: ScaleTransition(
          scale: _scaleIn,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: const Color(0xFFF7F8FB),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildWarningBanner(),
                          const SizedBox(height: 16),
                          _buildCredentialField(
                            label: 'اسم المستخدم',
                            value: widget.username,
                            icon: Icons.person_outline_rounded,
                            color: TaqwaColors.domeBlue,
                          ),
                          const SizedBox(height: 10),
                          _buildCredentialField(
                            label: 'كلمة المرور',
                            value: widget.password,
                            icon: Icons.lock_outline_rounded,
                            color: TaqwaColors.minaretGold,
                            highlight: true,
                          ),
                          const SizedBox(height: 16),
                          _buildCopyAllButton(),
                          if (phones.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _buildSectionLabel('إرسال إلى ولي الأمر'),
                            const SizedBox(height: 8),
                            ...phones.map(_buildWhatsAppButton),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildCloseBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TaqwaColors.domeBlue, Color(0xFF14395A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: TaqwaColors.minaretGold.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              color: TaqwaColors.minaretGold,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isNewStudent
                ? 'تم إنشاء الحساب بنجاح'
                : 'تمت إعادة تعيين كلمة المرور',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.studentName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF9800),
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'احفظ كلمة المرور الآن — لن تظهر مرة أخرى. يمكنك إرسالها للولي عبر واتساب أو نسخها مباشرة.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: Color(0xFF7A4F00),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialField({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                // Use a monospaced look for the credential value (LTR)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copy(value, label),
            tooltip: 'نسخ',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.copy_rounded,
                size: 16,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyAllButton() {
    return OutlinedButton.icon(
      onPressed: _copyAll,
      icon: const Icon(Icons.content_copy_rounded, size: 16),
      label: const Text(
        'نسخ بيانات الدخول كاملة',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: TaqwaColors.domeBlue,
        side: BorderSide(
          color: TaqwaColors.domeBlue.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: TaqwaColors.domeBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppButton(String phone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: () => _sendWhatsApp(phone),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            phone,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildCloseBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                'تم — حفظت البيانات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}