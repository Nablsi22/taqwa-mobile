import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/instructor_api.dart';
import '../../data/instructor_model.dart';
import 'add_edit_instructor_screen.dart';

class InstructorListScreen extends StatefulWidget {
  const InstructorListScreen({super.key});

  @override
  State<InstructorListScreen> createState() => _InstructorListScreenState();
}

class _InstructorListScreenState extends State<InstructorListScreen> {
  late final InstructorApi _instructorApi;
  final TextEditingController _searchController = TextEditingController();

  List<InstructorModel> _instructors = [];
  bool _isLoading = true;
  String? _error;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _instructorApi = InstructorApi(ApiClient.instance);
    _loadInstructors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructors({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _instructorApi.getInstructors(search: search);
      setState(() {
        _instructors = result['instructors'] as List<InstructorModel>;
        _totalCount = result['meta']?['total'] ?? _instructors.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteInstructor(InstructorModel instructor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل أنت متأكد من حذف المعلم "${instructor.fullName}"?\n'
            'لا يمكن حذف معلم لديه طلاب مسجلين.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _instructorApi.deleteInstructor(instructor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المعلم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _loadInstructors();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetPassword(InstructorModel instructor) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إعادة تعيين كلمة مرور ${instructor.fullName}'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              hintText: '6 أحرف على الأقل',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TaqwaColors.domeBlue,
              ),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final newPassword = passwordController.text.trim();
    if (newPassword.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      passwordController.dispose();
      return;
    }

    try {
      await _instructorApi.resetPassword(instructor.id, newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة تعيين كلمة المرور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
    passwordController.dispose();
  }

  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditInstructorScreen(),
      ),
    );
    if (result == true) _loadInstructors();
  }

  void _navigateToEdit(InstructorModel instructor) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditInstructorScreen(instructor: instructor),
      ),
    );
    if (result == true) _loadInstructors();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'إدارة المعلمين',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_totalCount > 0)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalCount معلم',
                    style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToAdd,
          backgroundColor: TaqwaColors.minaretGold,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'إضافة معلم',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: TaqwaColors.domeBlue,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchController,
                style:
                    const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو اسم المستخدم...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontFamily: 'Cairo',
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon:
                              const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            _loadInstructors();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  _loadInstructors(search: value.isEmpty ? null : value);
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: TaqwaColors.domeBlue,
                      ),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : _instructors.isEmpty
                          ? _buildEmptyState()
                          : _buildInstructorList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadInstructors(),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(
              backgroundColor: TaqwaColors.domeBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'لا توجد نتائج للبحث'
                : 'لا يوجد معلمين مسجلين',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على "إضافة معلم" لتسجيل معلم جديد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorList() {
    return RefreshIndicator(
      onRefresh: () => _loadInstructors(
        search:
            _searchController.text.isEmpty ? null : _searchController.text,
      ),
      color: TaqwaColors.domeBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _instructors.length,
        itemBuilder: (context, index) {
          return _buildInstructorCard(_instructors[index]);
        },
      ),
    );
  }

  Widget _buildInstructorCard(InstructorModel instructor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _navigateToEdit(instructor),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: TaqwaColors.domeBlue.withOpacity(0.1),
                child: Text(
                  instructor.fullName.isNotEmpty
                      ? instructor.fullName[0]
                      : '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructor.fullName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            instructor.username,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (instructor.mobile != null &&
                            instructor.mobile!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              instructor.mobile!,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (instructor.specialty != null &&
                        instructor.specialty!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              instructor.specialty!,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: instructor.studentCount > 0
                      ? TaqwaColors.islamicGreen.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${instructor.studentCount}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: instructor.studentCount > 0
                            ? TaqwaColors.islamicGreen
                            : Colors.grey,
                      ),
                    ),
                    Text(
                      'طالب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: instructor.studentCount > 0
                            ? TaqwaColors.islamicGreen
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _navigateToEdit(instructor);
                      break;
                    case 'reset_password':
                      _resetPassword(instructor);
                      break;
                    case 'delete':
                      _deleteInstructor(instructor);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit,
                            size: 18, color: TaqwaColors.domeBlue),
                        const SizedBox(width: 8),
                        const Text('تعديل',
                            style: TextStyle(fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reset_password',
                    child: Row(
                      children: [
                        const Icon(Icons.lock_reset,
                            size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('إعادة تعيين كلمة المرور',
                            style: TextStyle(fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('حذف',
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
    );
  }
}