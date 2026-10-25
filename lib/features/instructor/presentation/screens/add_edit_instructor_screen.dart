import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/instructor_api.dart';
import '../../data/instructor_model.dart';

class AddEditInstructorScreen extends StatefulWidget {
  final InstructorModel? instructor;

  const AddEditInstructorScreen({super.key, this.instructor});

  bool get isEditing => instructor != null;

  @override
  State<AddEditInstructorScreen> createState() =>
      _AddEditInstructorScreenState();
}

class _AddEditInstructorScreenState extends State<AddEditInstructorScreen> {
  late final InstructorApi _instructorApi;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _mobileController;
  late final TextEditingController _dobController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _addressController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  DateTime? _selectedDob;

  @override
  void initState() {
    super.initState();
    _instructorApi = InstructorApi(ApiClient.instance);
    _fullNameController =
        TextEditingController(text: widget.instructor?.fullName ?? '');
    _usernameController =
        TextEditingController(text: widget.instructor?.username ?? '');
    _passwordController = TextEditingController();
    _mobileController =
        TextEditingController(text: widget.instructor?.mobile ?? '');
    _specialtyController =
        TextEditingController(text: widget.instructor?.specialty ?? '');
    _addressController =
        TextEditingController(text: widget.instructor?.address ?? '');

    // Initialize date of birth from existing instructor data
    if (widget.instructor?.dateOfBirth != null) {
      _selectedDob = widget.instructor!.dateOfBirth;
      _dobController = TextEditingController(
        text:
            '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}',
      );
    } else {
      _dobController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    _specialtyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  int? _calculateAge() {
    if (_selectedDob == null) return null;
    final now = DateTime.now();
    int age = now.year - _selectedDob!.year;
    if (now.month < _selectedDob!.month ||
        (now.month == _selectedDob!.month && now.day < _selectedDob!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 30),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18),
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        await _instructorApi.updateInstructor(
          widget.instructor!.id,
          fullName: _fullNameController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
          dateOfBirth: _dobController.text.trim().isNotEmpty
              ? _dobController.text.trim()
              : null,
          specialty: _specialtyController.text.trim(),
          address: _addressController.text.trim(),
          mobile: _mobileController.text.trim(),
        );
      } else {
        await _instructorApi.createInstructor(
          fullName: _fullNameController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          dateOfBirth: _dobController.text.trim().isNotEmpty
              ? _dobController.text.trim()
              : null,
          specialty: _specialtyController.text.trim().isNotEmpty
              ? _specialtyController.text.trim()
              : null,
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          mobile: _mobileController.text.trim().isNotEmpty
              ? _mobileController.text.trim()
              : null,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'تم تحديث بيانات المعلم بنجاح'
                : 'تمت إضافة المعلم بنجاح',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(e.toString(), style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'تعديل بيانات المعلم' : 'إضافة معلم جديد',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header decoration
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 30),
                decoration: const BoxDecoration(
                  color: TaqwaColors.domeBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: Icon(
                        widget.isEditing ? Icons.edit : Icons.person_add,
                        size: 40,
                        color: TaqwaColors.minaretGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEditing
                          ? widget.instructor!.fullName
                          : 'معلم جديد',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (age != null)
                      Text(
                        '$age سنة',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionLabel('المعلومات الشخصية'),
                      const SizedBox(height: 12),

                      _buildTextField(
                        controller: _fullNameController,
                        label: 'الاسم الكامل',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الاسم الكامل مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Date of Birth picker (replaces age field) ──
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: _isLoading ? null : _pickDate,
                              child: AbsorbPointer(
                                child: _buildTextField(
                                  controller: _dobController,
                                  label: 'تاريخ الميلاد',
                                  icon: Icons.cake,
                                  hint: 'اضغط لاختيار التاريخ',
                                ),
                              ),
                            ),
                          ),
                          if (age != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: TaqwaColors.domeBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: TaqwaColors.domeBlue
                                        .withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Text('$age',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: TaqwaColors.domeBlue)),
                                  const Text('سنة',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: TaqwaColors.domeBlue)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _specialtyController,
                        label: 'التخصص (اختياري)',
                        icon: Icons.school,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _mobileController,
                        label: 'رقم الهاتف (اختياري)',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _addressController,
                        label: 'العنوان (اختياري)',
                        icon: Icons.location_on,
                      ),

                      const SizedBox(height: 28),

                      _buildSectionLabel('معلومات الحساب'),
                      const SizedBox(height: 12),

                      _buildTextField(
                        controller: _usernameController,
                        label: 'اسم المستخدم',
                        icon: Icons.account_circle,
                        hint: 'أحرف إنجليزية وأرقام فقط',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'اسم المستخدم مطلوب';
                          }
                          if (value.trim().length < 3) {
                            return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$')
                              .hasMatch(value.trim())) {
                            return 'يجب أن يحتوي على أحرف إنجليزية وأرقام فقط';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _passwordController,
                        label: widget.isEditing
                            ? 'كلمة المرور الجديدة (اتركها فارغة للإبقاء)'
                            : 'كلمة المرور',
                        icon: Icons.lock,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) {
                          if (!widget.isEditing &&
                              (value == null || value.isEmpty)) {
                            return 'كلمة المرور مطلوبة';
                          }
                          if (value != null &&
                              value.isNotEmpty &&
                              value.length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 36),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TaqwaColors.domeBlue,
                            disabledBackgroundColor:
                                TaqwaColors.domeBlue.withOpacity(0.5),
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
                                  widget.isEditing
                                      ? 'حفظ التعديلات'
                                      : 'إضافة المعلم',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('إلغاء',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  color: Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: TaqwaColors.minaretGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: TaqwaColors.domeBlue,
            )),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        hintStyle: TextStyle(
            fontFamily: 'Cairo', color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: TaqwaColors.domeBlue),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
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
              const BorderSide(color: TaqwaColors.domeBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
