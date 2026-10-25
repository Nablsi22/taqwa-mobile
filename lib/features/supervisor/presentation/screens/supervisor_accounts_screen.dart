import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../data/supervisor_api.dart';
import '../../data/supervisor_models.dart';
import '../supervisor_ui.dart';

/// The admin's page for the course director's login («حساب مدير الدورة»).
///
/// The account is its own thing: role SUPERVISOR, no أستاذ record behind it,
/// so it appears in no list of أساتذة and has no حلقة. From here the admin
/// creates it, changes its password, or switches it off. The server accepts
/// these requests from an ADMIN only.
class SupervisorAccountsScreen extends StatefulWidget {
  const SupervisorAccountsScreen({super.key});

  @override
  State<SupervisorAccountsScreen> createState() => _SupervisorAccountsScreenState();
}

class _SupervisorAccountsScreenState extends State<SupervisorAccountsScreen> {
  final _api = SupervisorApi(ApiClient.instance);
  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  List<SupervisorAccount> _accounts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = list;
        _loading = false;
      });
    } on SupervisorUnavailable {
      if (!mounted) return;
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String text, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? AttendanceColors.present : AttendanceColors.absent,
      ),
    );
  }

  Future<void> _create() async {
    final result = await showDialog<({String username, String password})>(
      context: context,
      builder: (_) => const _CredentialsDialog(title: 'حساب مدير الدورة الجديد', askUsername: true),
    );
    if (result == null || !mounted) return;
    try {
      await _api.createAccount(username: result.username, password: result.password);
      if (!mounted) return;
      _toast('انعمل الحساب «${result.username}» — بيدخل فيه المدير من شاشة الدخول');
      _load();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString(), ok: false);
    }
  }

  Future<void> _changePassword(SupervisorAccount a) async {
    final result = await showDialog<({String username, String password})>(
      context: context,
      builder: (_) => _CredentialsDialog(title: 'كلمة مرور جديدة لـ «${a.username}»', askUsername: false),
    );
    if (result == null || !mounted) return;
    try {
      await _api.setPassword(a.id, result.password);
      if (!mounted) return;
      _toast('تغيّرت كلمة المرور');
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString(), ok: false);
    }
  }

  Future<void> _toggle(SupervisorAccount a) async {
    try {
      await _api.setActive(a.id, !a.isActive);
      if (!mounted) return;
      _toast(a.isActive ? 'توقف الحساب — ما بيقدر يدخل' : 'رجع الحساب يشتغل');
      _load();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString(), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaqwaColors.background,
        appBar: AppBar(
          title: const Text('حساب مدير الدورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButton: _unavailable || _loading
            ? null
            : FloatingActionButton.extended(
                onPressed: _create,
                backgroundColor: TaqwaColors.islamicGreen,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('إنشاء حساب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
        body: RefreshIndicator(color: TaqwaColors.domeBlue, onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: TaqwaColors.domeBlue));
    }
    if (_unavailable) {
      return const SupervisorState(
        icon: Icons.cloud_sync_outlined,
        title: 'حساب مدير الدورة بيشتغل بعد تحديث الخادم',
      );
    }
    if (_error != null && _accounts.isEmpty) {
      return SupervisorState(icon: Icons.error_outline_rounded, title: _error!, onRetry: _load);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
      children: [
        const SoftCard(
          child: QuietNote(
            icon: Icons.verified_user_outlined,
            text: 'حساب مستقل: بيشوف كل شي (الأساتذة، الحضور، التسميع، النقاط) وما بيقدر يغيّر أي شي. '
                'ما إله حلقة ولا بيطلع بقائمة الأساتذة.',
          ),
        ),
        const SizedBox(height: 12),
        if (_accounts.isEmpty)
          const SoftCard(child: QuietNote(text: 'ما في حساب لمدير الدورة لهلق — اضغط «إنشاء حساب»'))
        else
          for (final a in _accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: a.isActive ? TaqwaColors.domeBlue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.username,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AttendanceColors.ink,
                            ),
                          ),
                        ),
                        TintPill(
                          label: a.isActive ? 'فعّال' : 'موقوف',
                          color: a.isActive ? AttendanceColors.present : AttendanceColors.absent,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastLogin(a.lastLogin),
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _changePassword(a),
                          icon: const Icon(Icons.key_rounded, size: 18),
                          label: const Text('كلمة المرور', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _toggle(a),
                          icon: Icon(a.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 18),
                          label: Text(a.isActive ? 'إيقاف' : 'تفعيل', style: const TextStyle(fontFamily: 'Cairo')),
                          style: TextButton.styleFrom(
                            foregroundColor: a.isActive ? AttendanceColors.absent : AttendanceColors.present,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// «آخر دخول: السبت 24/10» in the phone's own time, or «ما دخل لهلق».
String _lastLogin(String? stamp) {
  final t = stamp == null ? null : DateTime.tryParse(stamp)?.toLocal();
  if (t == null) return 'ما دخل لهلق';
  return 'آخر دخول: ${dayLabel(isoDay(t))}';
}

/// Username (when creating) and a password typed twice.
class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog({required this.title, required this.askUsername});

  final String title;
  final bool askUsername;

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, (username: _username.text.trim(), password: _password.text));
  }

  InputDecoration _decoration(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.askUsername) ...[
                  TextFormField(
                    controller: _username,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    decoration: _decoration('اسم المستخدم (إنكليزي)'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.length < 3) return '3 أحرف على الأقل';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(t)) return 'أحرف إنكليزية وأرقام و _ فقط';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _password,
                  obscureText: _hidden,
                  textDirection: TextDirection.ltr,
                  decoration: _decoration(
                    'كلمة المرور',
                    suffix: IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 6 ? '6 أحرف على الأقل' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _hidden,
                  textDirection: TextDirection.ltr,
                  decoration: _decoration('تأكيد كلمة المرور'),
                  validator: (v) => v != _password.text ? 'كلمتا المرور مختلفتان' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(backgroundColor: TaqwaColors.domeBlue),
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
