import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../instructor/data/instructor_model.dart';
import '../../../instructor/presentation/screens/add_edit_instructor_screen.dart';

class AdminManageInstructorsScreen extends StatefulWidget {
  const AdminManageInstructorsScreen({super.key});

  @override
  State<AdminManageInstructorsScreen> createState() =>
      _AdminManageInstructorsScreenState();
}

class _AdminManageInstructorsScreenState
    extends State<AdminManageInstructorsScreen> {
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _filtered = [];
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.get('/instructors');
      final data = res.data['data'] as List? ?? res.data as List? ?? [];
      _instructors = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _filtered = List.from(_instructors);
    } catch (e) {
      debugPrint('Load instructors error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filterInstructors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_instructors);
      } else {
        _filtered = _instructors.where((i) {
          final name = (i['fullName'] ?? '').toString().toLowerCase();
          final username = (i['username'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || username.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _resetPassword(Map<String, dynamic> instructor) async {
    final newPassController = TextEditingController(text: 'Taqwa@2026');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إعادة تعيين كلمة المرور',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المعلم: ${instructor['fullName']}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              Text('اسم المستخدم: ${instructor['username'] ?? ''}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.grey.shade600)),
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
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تغيير',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.instance.post(
          '/instructors/${instructor['id']}/reset-password',
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

  void _showCredentials(Map<String, dynamic> instructor) {
    final username = instructor['username'] ?? 'غير متاح';
    final mobile = instructor['mobile'] ?? '';
    final studentCount = instructor['studentCount'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.school, color: TaqwaColors.domeBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(instructor['fullName'] ?? '',
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
              _buildInfoRow('اسم المستخدم', username, Icons.account_circle,
                  onCopy: () {
                Clipboard.setData(ClipboardData(text: username));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('تم النسخ', style: TextStyle(fontFamily: 'Cairo')),
                    duration: Duration(seconds: 1),
                  ),
                );
              }),
              const SizedBox(height: 10),
              if (mobile.isNotEmpty)
                _buildInfoRow('الهاتف', mobile, Icons.phone),
              if (mobile.isNotEmpty) const SizedBox(height: 10),
              _buildInfoRow(
                  'عدد الطلاب', '$studentCount طالب', Icons.people),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
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
                _resetPassword(instructor);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {VoidCallback? onCopy}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaqwaColors.domeBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: TaqwaColors.domeBlue, size: 20),
          const SizedBox(width: 10),
          Column(
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.domeBlue)),
            ],
          ),
          const Spacer(),
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

  Future<void> _editInstructor(Map<String, dynamic> raw) async {
    final model = InstructorModel.fromJson(raw);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddEditInstructorScreen(instructor: model)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteInstructor(Map<String, dynamic> instructor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف المعلم',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف ${instructor['fullName']}؟',
              style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ApiClient.instance.delete('/instructors/${instructor['id']}');
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
          title: Text('إدارة المعلمين (${_filtered.length})',
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditInstructorScreen()),
                );
                if (result == true) _loadData();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 8),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterInstructors,
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو اسم المستخدم...',
                  hintStyle: TextStyle(
                      fontFamily: 'Cairo', color: Colors.grey.shade400),
                  prefixIcon:
                      const Icon(Icons.search, color: TaqwaColors.domeBlue),
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
                          child: Text('لا يوجد معلمون',
                              style: TextStyle(
                                  fontFamily: 'Cairo', color: Colors.grey)))
                      : RefreshIndicator(
                          color: TaqwaColors.domeBlue,
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _buildInstructorTile(_filtered[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorTile(Map<String, dynamic> instructor) {
    final name = instructor['fullName'] ?? '';
    final username = instructor['username'] ?? '';
    final studentCount = instructor['studentCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showCredentials(instructor),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TaqwaColors.domeBlue,
                        TaqwaColors.domeBlue.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                            Text(username,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          ],
                          if (username.isNotEmpty) const SizedBox(width: 10),
                          Icon(Icons.people,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text('$studentCount طالب',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
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
                        _editInstructor(instructor);
                        break;
                      case 'credentials':
                        _showCredentials(instructor);
                        break;
                      case 'reset':
                        _resetPassword(instructor);
                        break;
                      case 'delete':
                        _deleteInstructor(instructor);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
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
                    const PopupMenuItem(
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
                    const PopupMenuItem(
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
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف',
                              style: TextStyle(
                                  fontFamily: 'Cairo', color: Colors.red)),
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
