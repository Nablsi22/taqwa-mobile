import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/models/student_model.dart';
import '../widgets/credentials_dialog.dart';

class AddStudentScreen extends StatefulWidget {
  final StudentModel? student;

  const AddStudentScreen({super.key, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _fatherNameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _addressController;
  late final TextEditingController _phone1Controller;
  late final TextEditingController _phone2Controller;
  late final TextEditingController _dobController;
  bool _isLoading = false;

  // Instructor dropdown
  List<Map<String, String>> _instructors = [];
  String? _selectedInstructorId;
  bool _loadingInstructors = true;

  // Grade dropdown
  String? _selectedGrade;

  // Holds the picked DOB so we can send it back to the backend in ISO form
  DateTime? _selectedDob;

  static const List<String> _gradeOptions = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'جامعي',
    'أخرى',
  ];

  bool get isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    _fullNameController =
        TextEditingController(text: widget.student?.fullName ?? '');
    _fatherNameController =
        TextEditingController(text: widget.student?.fatherName ?? '');
    _schoolController =
        TextEditingController(text: widget.student?.school ?? '');
    _addressController =
        TextEditingController(text: widget.student?.address ?? '');
    _phone1Controller =
        TextEditingController(text: widget.student?.phone1 ?? '');
    _phone2Controller =
        TextEditingController(text: widget.student?.phone2 ?? '');
    _selectedDob = widget.student?.dateOfBirth;
    _dobController = TextEditingController(
      text: _selectedDob != null ? _formatDob(_selectedDob!) : '',
    );
    _selectedInstructorId = widget.student?.instructorId;
    _selectedGrade = widget.student?.grade;

    _loadInstructors();
  }

  String _formatDob(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadInstructors() async {
    try {
      final response = await ApiClient.instance.get(
        ApiConstants.instructors,
        queryParameters: {'all': 'true'},
      );
      final responseData = response.data;
      final list = responseData['data'] as List;
      setState(() {
        _instructors = list
            .map((e) => {
                  'id': e['id'] as String,
                  'fullName': e['fullName'] as String,
                })
            .toList();
        _loadingInstructors = false;
      });
    } catch (_) {
      setState(() => _loadingInstructors = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _schoolController.dispose();
    _addressController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 10),
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDob(picked);
      });
    }
  }

  /// Validate Syrian phone format. When not required, empty is allowed.
  /// Accepts:
  ///   +963XXXXXXXXX (12 digits + plus)
  ///   963XXXXXXXXX  (12 digits)
  ///   09XXXXXXXX    (10 digits, local)
  String? _validatePhone(String? value, {required bool required}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'هذا الحقل مطلوب' : null;
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
    final regex = RegExp(r'^(\+?963\d{9}|09\d{8})$');
    if (!regex.hasMatch(cleaned)) {
      return 'الصيغة: +963XXXXXXXXX أو 09XXXXXXXX';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedInstructorId == null) {
      _showError('يرجى اختيار المعلم');
      return;
    }

    if (_selectedDob == null) {
      _showError('يرجى اختيار تاريخ الميلاد');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone1 = _phone1Controller.text.trim();
      final phone2 = _phone2Controller.text.trim();

      final data = <String, dynamic>{
        'fullName': _fullNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'dateOfBirth': _formatDob(_selectedDob!),
        'instructorId': _selectedInstructorId,
        if (_schoolController.text.trim().isNotEmpty)
          'school': _schoolController.text.trim(),
        if (_selectedGrade != null) 'grade': _selectedGrade,
        if (_addressController.text.trim().isNotEmpty)
          'address': _addressController.text.trim(),
        // phone1 is now optional — only send when present
        if (phone1.isNotEmpty) 'phone1': phone1,
        if (phone2.isNotEmpty) 'phone2': phone2,
      };

      debugPrint('=== ${isEditing ? "UPDATE" : "CREATE"} STUDENT ===');
      debugPrint('Data: $data');

      if (isEditing) {
        await ApiClient.instance.put(
          '${ApiConstants.students}/${widget.student!.id}',
          data: data,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تعديل بيانات الطالب بنجاح',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: TaqwaColors.islamicGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      // CREATE — backend returns generatedCredentials in the response
      final response = await ApiClient.instance.post(
        ApiConstants.students,
        data: data,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final responseData = response.data;
      final generated = responseData is Map
          ? responseData['generatedCredentials'] as Map?
          : null;

      if (generated == null) {
        // Defensive — backend should always return creds for new students
        _showError(
          'تم الحفظ ولكن لم يتم استلام بيانات الدخول. راجع شاشة بيانات الدخول.',
        );
        Navigator.pop(context, true);
        return;
      }

      final username = generated['username']?.toString() ?? '';
      final password = generated['password']?.toString() ?? '';
      final studentId = (responseData['id'] ?? '').toString();
      final studentName =
          (responseData['fullName'] ?? _fullNameController.text.trim())
              .toString();

      // Show the one-time credentials dialog
      await CredentialsDialog.show(
        context: context,
        studentId: studentId,
        studentName: studentName,
        username: username,
        password: password,
        isNewStudent: true,
        phone1: phone1.isNotEmpty ? phone1 : null,
        phone2: phone2.isNotEmpty ? phone2 : null,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('=== SAVE STUDENT ERROR ===');
      debugPrint('Error: $e');

      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = 'حدث خطأ غير متوقع';
      final s = e.toString();
      if (s.contains('400')) {
        errorMessage = 'بيانات غير صحيحة، يرجى التحقق من الحقول';
      } else if (s.contains('409') || s.contains('unique')) {
        errorMessage = 'يوجد تعارض في البيانات';
      } else if (s.contains('401')) {
        errorMessage = 'غير مصرح، يرجى تسجيل الدخول مجدداً';
      } else if (s.contains('500')) {
        errorMessage = 'خطأ في الخادم، يرجى المحاولة لاحقاً';
      } else if (s.contains('timeout')) {
        errorMessage = 'انتهت مهلة الاتصال، تحقق من الاتصال';
      }
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(isEditing ? AppStrings.edit : AppStrings.addStudent),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (!isEditing) _buildAutoCredentialsBanner(),
                if (!isEditing) const SizedBox(height: 16),

                // ── Basic Info Card ──
                _buildCard(
                  title: 'المعلومات الأساسية',
                  children: [
                    _buildField(
                      controller: _fullNameController,
                      label: AppStrings.studentName,
                      icon: Icons.person_outline,
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _fatherNameController,
                      label: AppStrings.fatherName,
                      icon: Icons.person_outline,
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _isLoading ? null : _pickDate,
                      child: AbsorbPointer(
                        child: _buildField(
                          controller: _dobController,
                          label: AppStrings.dateOfBirth,
                          icon: Icons.calendar_today_outlined,
                          required: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _schoolController,
                      label: AppStrings.school,
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGrade,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الصف الدراسي',
                        prefixIcon: const Icon(Icons.grade,
                            color: TaqwaColors.gray),
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
                          borderSide: const BorderSide(
                              color: TaqwaColors.domeBlue, width: 1.5),
                        ),
                      ),
                      items: _gradeOptions
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 15)),
                              ))
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _selectedGrade = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Contact Info Card ──
                _buildCard(
                  title: 'معلومات التواصل',
                  children: [
                    _buildField(
                      controller: _phone1Controller,
                      label: 'هاتف ولي الأمر',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      validator: (v) => _validatePhone(v, required: false),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+]'),
                        ),
                      ],
                      hint: '+963XXXXXXXXX (اختياري)',
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _phone2Controller,
                      label: 'هاتف ولي الأمر (احتياطي)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      validator: (v) => _validatePhone(v, required: false),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+]'),
                        ),
                      ],
                      hint: '+963XXXXXXXXX',
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _addressController,
                      label: AppStrings.homeAddress,
                      icon: Icons.home_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Instructor Dropdown Card ──
                _buildCard(
                  title: 'تعيين المعلم',
                  children: [
                    _loadingInstructors
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: TaqwaColors.domeBlue),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedInstructorId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'اختر المعلم',
                              prefixIcon: const Icon(Icons.school_outlined,
                                  color: TaqwaColors.gray),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: TaqwaColors.domeBlue, width: 1.5),
                              ),
                            ),
                            items: _instructors
                                .map((instructor) => DropdownMenuItem<String>(
                                      value: instructor['id'],
                                      child: Text(instructor['fullName']!,
                                          style:
                                              const TextStyle(fontSize: 15)),
                                    ))
                                .toList(),
                            onChanged: _isLoading
                                ? null
                                : (value) => setState(
                                    () => _selectedInstructorId = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى اختيار المعلم';
                              }
                              return null;
                            },
                          ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Save Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaqwaColors.domeBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            AppStrings.save,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoCredentialsBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TaqwaColors.minaretGold.withValues(alpha: 0.12),
            TaqwaColors.minaretGold.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TaqwaColors.minaretGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TaqwaColors.minaretGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: TaqwaColors.minaretGold,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'سيتم إنشاء اسم المستخدم وكلمة المرور تلقائياً بعد الحفظ. ستظهر مرة واحدة فقط لإرسالها لولي الأمر.',
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
    );
  }

  Widget _buildCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D2137))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isLoading,
      textDirection: textDirection,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Cairo',
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: TaqwaColors.gray),
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
          borderSide:
              const BorderSide(color: TaqwaColors.domeBlue, width: 1.5),
        ),
      ),
      validator: validator ??
          (required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  return null;
                }
              : null),
    );
  }
}