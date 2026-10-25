import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../students/presentation/widgets/credentials_dialog.dart';

class AdminCredentialsScreen extends StatefulWidget {
  const AdminCredentialsScreen({super.key});

  @override
  State<AdminCredentialsScreen> createState() => _AdminCredentialsScreenState();
}

enum _SentFilter { all, sent, unsent }

class _AdminCredentialsScreenState extends State<AdminCredentialsScreen> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, dynamic> _meta = {};
  bool _isLoading = true;
  String? _error;

  _SentFilter _filter = _SentFilter.all;
  String _searchQuery = '';

  // Per-row action loading states
  final Set<String> _busyStudentIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Data loading ────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.get('/students/credentials/list');
      final data = res.data;
      final list = (data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _all = list;
      _meta = Map<String, dynamic>.from(data['meta'] ?? {});
      _applyFilters();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilters() {
    Iterable<Map<String, dynamic>> result = _all;

    if (_filter == _SentFilter.sent) {
      result = result.where((s) => s['credentialsSentAt'] != null);
    } else if (_filter == _SentFilter.unsent) {
      result = result.where((s) => s['credentialsSentAt'] == null);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final name = (s['fullName'] ?? '').toString().toLowerCase();
        final username = (s['username'] ?? '').toString().toLowerCase();
        final phone1 = (s['phone1'] ?? '').toString().toLowerCase();
        final phone2 = (s['phone2'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            username.contains(q) ||
            phone1.contains(q) ||
            phone2.contains(q);
      });
    }

    _filtered = result.toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilters();
    });
  }

  void _setFilter(_SentFilter filter) {
    HapticFeedback.selectionClick();
    setState(() {
      _filter = filter;
      _applyFilters();
    });
  }

  // ─── Per-student actions ──────────────────────────────────

  /// Normalize a Syrian phone into the format wa.me expects.
  /// Returns null if the phone is empty or unrecognized.
  String? _normalizePhone(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('+963')) return cleaned.substring(1);
    if (cleaned.startsWith('963')) return cleaned;
    if (cleaned.startsWith('09')) return '963${cleaned.substring(1)}';
    return null;
  }

  /// "Reset and send" — generates a new password, then opens WhatsApp
  /// with the fresh credentials, then marks as sent on success.
  Future<void> _resetAndSend(Map<String, dynamic> student) async {
    final studentId = student['id'] as String;
    final phone = _normalizePhone(student['phone1'] as String?);

    if (phone == null) {
      _showError('لا يوجد رقم هاتف صالح لولي الأمر');
      return;
    }

    final confirmed = await _confirm(
      title: 'إعادة تعيين وإرسال',
      message:
          'سيتم إنشاء كلمة مرور جديدة لـ ${student['fullName']} وفتح واتساب لإرسالها.\n\n'
          'كلمة المرور القديمة لن تعمل بعد ذلك. هل تريد المتابعة؟',
      confirmText: 'متابعة',
      confirmColor: TaqwaColors.minaretGold,
    );
    if (!confirmed) return;

    setState(() => _busyStudentIds.add(studentId));

    try {
      // 1. Reset password — backend returns the new plain password ONCE
      final res = await ApiClient.instance.post(
        '/students/$studentId/reset-password',
      );
      final data = res.data;
      final newPassword = data['newPassword']?.toString() ?? '';
      if (newPassword.isEmpty) {
        throw Exception('الخادم لم يرجع كلمة مرور جديدة');
      }

      if (!mounted) return;

      // 2. Open the credentials dialog with the new password.
      // The dialog already handles WhatsApp + mark-as-sent for us.
      await CredentialsDialog.show(
        context: context,
        studentId: studentId,
        studentName: student['fullName']?.toString() ?? '',
        username: student['username']?.toString() ?? '',
        password: newPassword,
        isNewStudent: false,
        phone1: student['phone1']?.toString(),
        phone2: student['phone2']?.toString(),
      );

      // 3. Refresh the list to reflect the new sent status
      await _loadData();
    } catch (e) {
      _showError('فشل إعادة التعيين: $e');
    } finally {
      if (mounted) {
        setState(() => _busyStudentIds.remove(studentId));
      }
    }
  }

  /// Send only the username via WhatsApp (no password change).
  /// Marks as sent on success.
  Future<void> _sendUsernameOnly(Map<String, dynamic> student) async {
    final studentId = student['id'] as String;
    final phone = _normalizePhone(student['phone1'] as String?);
    if (phone == null) {
      _showError('لا يوجد رقم هاتف صالح');
      return;
    }

    final username = student['username']?.toString() ?? '';
    final name = student['fullName']?.toString() ?? '';

    final message =
        'السلام عليكم ورحمة الله و بركاته\n\n'
        'اسم المستخدم لابنكم $name في تطبيق التقوى:\n\n'
        'اسم المستخدم: $username\n\n'
        'إذا نسيتم كلمة المرور، تواصلوا مع الإدارة لإعادة تعيينها.';

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showError('تعذر فتح واتساب');
        return;
      }
      await _markSentOnBackend(studentId);
      await _loadData();
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  Future<void> _copyUsername(Map<String, dynamic> student) async {
    final username = student['username']?.toString() ?? '';
    if (username.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: username));
    HapticFeedback.lightImpact();
    _showInfo('تم نسخ اسم المستخدم');
  }

  Future<void> _markAsSentManually(Map<String, dynamic> student) async {
    final studentId = student['id'] as String;
    setState(() => _busyStudentIds.add(studentId));
    try {
      await _markSentOnBackend(studentId);
      await _loadData();
      _showInfo('تم تسجيل الإرسال يدوياً');
    } catch (e) {
      _showError('فشل: $e');
    } finally {
      if (mounted) setState(() => _busyStudentIds.remove(studentId));
    }
  }

  Future<void> _markSentOnBackend(String studentId) async {
    await ApiClient.instance.post(
      '/students/$studentId/mark-credentials-sent',
    );
  }

  // ─── Bulk regenerate (one-time migration) ─────────────────

  Future<void> _bulkRegenerate() async {
    final firstConfirm = await _confirm(
      title: '⚠️ إعادة توليد جميع بيانات الدخول',
      message:
          'سيتم إنشاء اسم مستخدم وكلمة مرور جديدة لكل طالب في النظام. '
          'جميع بيانات الدخول الحالية ستتوقف عن العمل فوراً.\n\n'
          'هذه عملية لمرة واحدة فقط. سيتم عرض جميع البيانات الجديدة دفعة واحدة لتوزيعها على أولياء الأمور.\n\n'
          'هل أنت متأكد؟',
      confirmText: 'متابعة',
      confirmColor: Colors.red,
    );
    if (!firstConfirm) return;

    final secondConfirm = await _confirm(
      title: 'تأكيد نهائي',
      message:
          'هذا إجراء لا يمكن التراجع عنه. اكتب التأكيد فقط إذا كنت متأكداً تماماً.',
      confirmText: 'نعم، نفّذ الآن',
      confirmColor: Colors.red,
    );
    if (!secondConfirm) return;

    // Show a blocking progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: TaqwaColors.domeBlue),
              SizedBox(height: 16),
              Text(
                'جارٍ إنشاء بيانات الدخول الجديدة...\nقد يستغرق هذا بضع لحظات.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await ApiClient.instance.post(
        '/students/credentials/regenerate-all',
        data: {
          'confirmationToken': 'REGENERATE_ALL_STUDENT_CREDENTIALS_CONFIRMED',
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      final data = res.data;
      final credentials = (data['credentials'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Show the bulk results screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _BulkCredentialsResultScreen(credentials: credentials),
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog
      _showError('فشلت العملية: $e');
    }
  }

  // ─── Confirmation dialogs ─────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: TaqwaColors.islamicGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'بيانات دخول الطلاب',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
              )
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    color: TaqwaColors.domeBlue,
                    onRefresh: _loadData,
                    child: Column(
                      children: [
                        _buildStatsBar(),
                        _buildSearchBar(),
                        _buildFilterChips(),
                        Expanded(child: _buildList()),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── Stats bar ──
  Widget _buildStatsBar() {
    final total = _meta['total'] ?? _all.length;
    final sent = _meta['sent'] ?? _all.where((s) => s['credentialsSentAt'] != null).length;
    final unsent = _meta['unsent'] ?? _all.where((s) => s['credentialsSentAt'] == null).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TaqwaColors.domeBlue, Color(0xFF154360)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _miniStat(Icons.people_alt_rounded, 'الإجمالي', '$total', Colors.white),
          _statDivider(),
          _miniStat(Icons.check_circle_rounded, 'أرسلت', '$sent',
              const Color(0xFF2ECC71)),
          _statDivider(),
          _miniStat(Icons.pending_rounded, 'لم ترسل', '$unsent',
              TaqwaColors.minaretGold),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.15),
      );

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ──
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
        onChanged: _onSearchChanged,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم أو اسم المستخدم أو الهاتف...',
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
                    _onSearchChanged('');
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
    );
  }

  // ── Filter chips ──
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', _SentFilter.all),
          const SizedBox(width: 8),
          _filterChip('لم ترسل', _SentFilter.unsent),
          const SizedBox(width: 8),
          _filterChip('أرسلت', _SentFilter.sent),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _SentFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TaqwaColors.domeBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? TaqwaColors.domeBlue
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ── List ──
  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _filter != _SentFilter.all
                  ? 'لا توجد نتائج مطابقة'
                  : 'لا يوجد طلاب',
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        return _buildStudentRow(_filtered[index]);
      },
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student) {
    final id = student['id'] as String;
    final name = student['fullName']?.toString() ?? '';
    final username = student['username']?.toString() ?? '';
    final phone1 = student['phone1']?.toString() ?? '';
    final instructor = student['instructorName']?.toString() ?? '';
    final sentAt = student['credentialsSentAt'];
    final lastReset = student['lastCredentialReset'];
    final isSent = sentAt != null;
    final isBusy = _busyStudentIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        border: Border(
          right: BorderSide(
            color: isSent
                ? const Color(0xFF2ECC71)
                : TaqwaColors.minaretGold,
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: name + status + menu ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (instructor.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.school_rounded,
                                  size: 11, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  instructor,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TaqwaColors.domeBlue,
                      ),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: Colors.grey.shade500),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'reset_send':
                          _resetAndSend(student);
                          break;
                        case 'send_username':
                          _sendUsernameOnly(student);
                          break;
                        case 'copy':
                          _copyUsername(student);
                          break;
                        case 'mark':
                          _markAsSentManually(student);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'reset_send',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset_rounded,
                                size: 18, color: TaqwaColors.minaretGold),
                            SizedBox(width: 8),
                            Text(
                              'إعادة تعيين وإرسال',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'send_username',
                        child: Row(
                          children: [
                            Icon(Icons.send_rounded,
                                size: 18, color: Color(0xFF25D366)),
                            SizedBox(width: 8),
                            Text(
                              'إرسال اسم المستخدم فقط',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 18, color: TaqwaColors.domeBlue),
                            SizedBox(width: 8),
                            Text(
                              'نسخ اسم المستخدم',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'mark',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'تسجيل الإرسال يدوياً',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Username + phone ──
            Row(
              children: [
                _infoChip(
                  Icons.account_circle_outlined,
                  username.isNotEmpty ? username : '—',
                  TaqwaColors.domeBlue,
                  ltr: true,
                ),
                const SizedBox(width: 6),
                if (phone1.isNotEmpty)
                  _infoChip(
                    Icons.phone_rounded,
                    phone1,
                    Colors.grey.shade700,
                    ltr: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Status row ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSent
                        ? const Color(0xFF2ECC71).withValues(alpha: 0.12)
                        : TaqwaColors.minaretGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSent
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        size: 12,
                        color: isSent
                            ? const Color(0xFF27AE60)
                            : TaqwaColors.minaretGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSent
                            ? 'أرسلت ${_formatDate(sentAt)}'
                            : 'لم ترسل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isSent
                              ? const Color(0xFF27AE60)
                              : TaqwaColors.minaretGold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lastReset != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          size: 11,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'آخر تغيير: ${_formatDate(lastReset)}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color,
      {bool ltr = false}) {
    final child = Text(
      text,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: ltr
                  ? Directionality(
                      textDirection: TextDirection.ltr,
                      child: child,
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(
            'تعذر تحميل البيانات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: TaqwaColors.domeBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// BULK REGENERATION RESULTS — shown ONCE after the migration
// ═══════════════════════════════════════════════════════════════

class _BulkCredentialsResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> credentials;
  const _BulkCredentialsResultScreen({required this.credentials});

  @override
  State<_BulkCredentialsResultScreen> createState() =>
      _BulkCredentialsResultScreenState();
}

class _BulkCredentialsResultScreenState
    extends State<_BulkCredentialsResultScreen> {
  bool _acknowledged = false;

  Future<bool> _confirmExit() async {
    if (_acknowledged) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                '⚠️ تحذير',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                'إذا خرجت من هذه الشاشة، لن تتمكن من رؤية كلمات المرور مرة أخرى.\n\n'
                'تأكد من نسخها أو إرسالها لجميع أولياء الأمور.\n\n'
                'هل أنت متأكد؟',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'البقاء',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'خروج بدون حفظ',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  String _normalizePhone(String? raw) {
    if (raw == null) return '';
    final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('+963')) return cleaned.substring(1);
    if (cleaned.startsWith('963')) return cleaned;
    if (cleaned.startsWith('09')) return '963${cleaned.substring(1)}';
    return '';
  }

  Future<void> _sendOne(Map<String, dynamic> cred) async {
    final phone = _normalizePhone(cred['phone1'] as String?);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يوجد رقم هاتف',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final message =
        'السلام عليكم ورحمة الله و بركاته\n\n'
        'بيانات دخول ابنكم ${cred['fullName']} لتطبيق التقوى:\n\n'
        'اسم المستخدم: ${cred['username']}\n'
        'كلمة المرور: ${cred['password']}\n\n'
        'يمكنكم تحميل التطبيق من المتجر.';

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Mark as sent on the backend
      await ApiClient.instance.post(
        '/students/${cred['studentId']}/mark-credentials-sent',
      );
    } catch (_) {}
  }

  Future<void> _copyAll() async {
    final buf = StringBuffer();
    for (final c in widget.credentials) {
      buf.writeln('${c['fullName']}');
      buf.writeln('  اسم المستخدم: ${c['username']}');
      buf.writeln('  كلمة المرور: ${c['password']}');
      buf.writeln('  هاتف: ${c['phone1'] ?? '-'}');
      buf.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم نسخ جميع البيانات',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: TaqwaColors.islamicGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final ok = await _confirmExit();
          if (ok && mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: TaqwaColors.domeBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              'بيانات الدخول الجديدة (${widget.credentials.length})',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'نسخ الكل',
                icon: const Icon(Icons.copy_all_rounded),
                onPressed: _copyAll,
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF9800),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'هذه البيانات لن تظهر مرة أخرى. أرسلها لكل ولي أمر الآن، '
                        'أو انسخها واحفظها في مكان آمن.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Color(0xFF7A4F00),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: widget.credentials.length,
                  itemBuilder: (context, index) {
                    final c = widget.credentials[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['fullName']?.toString() ?? '',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _credCell(
                                  'اسم المستخدم',
                                  c['username']?.toString() ?? '',
                                  TaqwaColors.domeBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _credCell(
                                  'كلمة المرور',
                                  c['password']?.toString() ?? '',
                                  TaqwaColors.minaretGold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendOne(c),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text(
                                'إرسال عبر واتساب',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Checkbox(
                    value: _acknowledged,
                    onChanged: (v) =>
                        setState(() => _acknowledged = v ?? false),
                    activeColor: TaqwaColors.domeBlue,
                  ),
                  const Expanded(
                    child: Text(
                      'لقد حفظت/أرسلت جميع البيانات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _acknowledged
                        ? () => Navigator.of(context).pop()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaqwaColors.domeBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'إنهاء',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _credCell(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}