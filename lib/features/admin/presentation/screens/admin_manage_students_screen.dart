import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/presentation/screens/add_student_screen.dart';

class AdminManageStudentsScreen extends StatefulWidget {
  const AdminManageStudentsScreen({super.key});

  @override
  State<AdminManageStudentsScreen> createState() =>
      _AdminManageStudentsScreenState();
}

class _AdminManageStudentsScreenState extends State<AdminManageStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, String> _instructorNames = {};
  bool _isLoading = true;
  final _searchController = TextEditingController();

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

  /// Extract username from nested or flat response shape.
  String _getUsername(Map<String, dynamic> student) {
    return student['user']?['username'] as String? ??
        student['username'] as String? ??
        '';
  }

  /// Safely unwrap a paginated response ({ data: [...] }) or a raw list.
  List<dynamic> _unwrapList(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final inner = responseData['data'];
      if (inner is List) return inner;
    }
    if (responseData is List) return responseData;
    return const [];
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Run both requests in parallel — they're independent.
      // `all=true` opts out of backend pagination so we get every
      // record in a single call. Client-side filtering is already
      // implemented below in _filterStudents().
      final results = await Future.wait([
        ApiClient.instance.get(
          '/instructors',
          queryParameters: {'all': 'true'},
        ),
        ApiClient.instance.get(
          '/students',
          queryParameters: {'all': 'true'},
        ),
      ]);

      final instList = _unwrapList(results[0].data);
      final studentList = _unwrapList(results[1].data);

      final nextInstructors = <String, String>{};
      for (final inst in instList) {
        if (inst is Map) {
          nextInstructors[(inst['id'] ?? '').toString()] =
              (inst['fullName'] ?? '').toString();
        }
      }

      _instructorNames = nextInstructors;
      _students = studentList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _filtered = List.of(_students);
    } catch (e) {
      debugPrint('Load students error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل البيانات: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(_students);
      } else {
        final q = query.toLowerCase();
        _filtered = _students.where((s) {
          final name = (s['fullName'] ?? '').toString().toLowerCase();
          final username = _getUsername(s).toLowerCase();
          return name.contains(q) || username.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _resetPassword(Map<String, dynamic> student) async {
    final newPassController = TextEditingController(text: 'Taqwa@2026');
    final username = _getUsername(student);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('إعادة تعيين كلمة المرور',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الطالب: ${student['fullName']}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              ),
              if (username.isNotEmpty)
                Text(
                  'اسم المستخدم: $username',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.grey.shade600),
                ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: newPassController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style:
                      TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تغيير',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        debugPrint('Resetting password for student ID: ${student['id']}');
        await ApiClient.instance.post(
          '/students/${student['id']}/reset-password',
          data: {'password': newPassController.text.trim()},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تغيير كلمة المرور بنجاح',
                  style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: TaqwaColors.islamicGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Reset password error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e',
                  style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCredentials(Map<String, dynamic> student) {
    final username = _getUsername(student);
    final instructorName =
        _instructorNames[student['instructorId']] ?? 'غير محدد';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person, color: TaqwaColors.domeBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(student['fullName'] ?? '',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCredentialRow(
                'اسم المستخدم',
                username.isNotEmpty ? username : 'غير متاح',
                Icons.account_circle,
                onCopy: username.isNotEmpty
                    ? () {
                        Clipboard.setData(ClipboardData(text: username));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم النسخ',
                                style: TextStyle(fontFamily: 'Cairo')),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              _buildCredentialRow(
                'المعلم',
                instructorName,
                Icons.school,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('تغيير كلمة المرور',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _resetPassword(student);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaqwaColors.domeBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: TaqwaColors.domeBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
                Text(value,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue)),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy,
                  size: 18, color: TaqwaColors.domeBlue),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }

  Future<void> _editStudent(Map<String, dynamic> raw) async {
    final model = StudentModel.fromJson(raw);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddStudentScreen(student: model)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف الطالب',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف ${student['fullName']}؟',
              style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ApiClient.instance.delete('/students/${student['id']}');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: TaqwaColors.domeBlue,
          title: Text('إدارة الطلاب (${_filtered.length})',
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddStudentScreen()),
                );
                if (result == true) _loadData();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterStudents,
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو اسم المستخدم...',
                  hintStyle: TextStyle(
                      fontFamily: 'Cairo', color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search,
                      color: TaqwaColors.domeBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: TaqwaColors.domeBlue))
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text('لا يوجد طلاب',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.grey)))
                      : RefreshIndicator(
                          color: TaqwaColors.domeBlue,
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _buildStudentTile(_filtered[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> student) {
    final name = (student['fullName'] ?? '').toString();
    final username = _getUsername(student);
    final instructorName =
        _instructorNames[student['instructorId']] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showCredentials(student),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: TaqwaColors.skyBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TaqwaColors.domeBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50))),
                      Row(
                        children: [
                          if (username.isNotEmpty) ...[
                            Icon(Icons.account_circle,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(username,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (instructorName.isNotEmpty) ...[
                            Icon(Icons.school,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(instructorName,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _editStudent(student);
                        break;
                      case 'credentials':
                        _showCredentials(student);
                        break;
                      case 'reset':
                        _resetPassword(student);
                        break;
                      case 'delete':
                        _deleteStudent(student);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              size: 18, color: TaqwaColors.domeBlue),
                          SizedBox(width: 8),
                          Text('تعديل البيانات',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'credentials',
                      child: Row(
                        children: [
                          Icon(Icons.key, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('بيانات الدخول',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset,
                              size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('تغيير كلمة المرور',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}