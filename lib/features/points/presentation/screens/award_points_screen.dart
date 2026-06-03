import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../data/points_api.dart';

class AwardPointsScreen extends StatefulWidget {
  const AwardPointsScreen({super.key});

  @override
  State<AwardPointsScreen> createState() => _AwardPointsScreenState();
}

class _AwardPointsScreenState extends State<AwardPointsScreen> {
  final _pointsApi = PointsApi(ApiClient.instance);

  // Data
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _students = [];
  bool _loadingCategories = true;
  bool _loadingStudents = true;
  bool _isSaving = false;

  // Form
  String? _selectedStudentId;
  String? _selectedStudentName;
  String? _selectedCategoryId;
  Map<String, dynamic>? _selectedCategory;
  String? _selectedRating;
  int _points = 0;
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadStudents();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _pointsApi.getCategories();
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadStudents() async {
    try {
      final apiClient = ApiClient.instance;
      final response = await apiClient.get(ApiConstants.students);
      final data = response.data['data'] as List;
      setState(() {
        _students = data
            .map((e) => {
                  'id': e['id'] as String,
                  'fullName': e['fullName'] as String,
                })
            .toList();
        _loadingStudents = false;
      });
    } catch (e) {
      setState(() => _loadingStudents = false);
    }
  }

  void _onCategorySelected(String? categoryId) {
    if (categoryId == null) return;
    final cat = _categories.firstWhere((c) => c['id'] == categoryId);
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategory = cat;
      _selectedRating = null;
      _points = (cat['defaultValue'] as int?) ?? 0;
    });
  }

  void _onRatingSelected(String rating) {
    setState(() {
      _selectedRating = rating;
      // Adjust points based on rating
      if (_selectedCategory != null) {
        final defaultVal = (_selectedCategory!['defaultValue'] as int?) ?? 0;
        switch (rating) {
          case 'GOOD':
            _points = defaultVal;
            break;
          case 'VERY_GOOD':
            _points = (defaultVal * 2).clamp(0, 999);
            break;
          case 'REPEAT':
            _points = 0;
            break;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) {
      _showError('يرجى اختيار الطالب');
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('يرجى اختيار فئة النقاط');
      return;
    }
    if (_selectedCategory!['hasRating'] == true && _selectedRating == null) {
      _showError('يرجى اختيار التقييم');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result = await _pointsApi.awardPoints(
        studentId: _selectedStudentId!,
        categoryId: _selectedCategoryId!,
        amount: _points,
        rating: _selectedRating,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'تم إضافة النقاط بنجاح',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      setState(() {
        _selectedStudentId = null;
        _selectedStudentName = null;
        _selectedCategoryId = null;
        _selectedCategory = null;
        _selectedRating = null;
        _points = 0;
        _descriptionController.clear();
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'إضافة نقاط',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _loadingCategories || _loadingStudents
            ? const Center(
                child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student selector
                    _buildSectionLabel('اختيار الطالب'),
                    const SizedBox(height: 10),
                    _buildStudentDropdown(),

                    const SizedBox(height: 24),

                    // Category selector
                    _buildSectionLabel('فئة النقاط'),
                    const SizedBox(height: 10),
                    _buildCategoryGrid(),

                    // Rating (if category has rating)
                    if (_selectedCategory != null &&
                        _selectedCategory!['hasRating'] == true) ...[
                      const SizedBox(height: 24),
                      _buildSectionLabel('التقييم'),
                      const SizedBox(height: 10),
                      _buildRatingSelector(),
                    ],

                    const SizedBox(height: 24),

                    // Points display
                    _buildPointsDisplay(),

                    const SizedBox(height: 24),

                    // Description
                    _buildSectionLabel('ملاحظات (اختياري)'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        hintText: 'أضف ملاحظة...',
                        hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.grey.shade400,
                        ),
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
                          borderSide: const BorderSide(
                              color: TaqwaColors.domeBlue, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TaqwaColors.islamicGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'إضافة النقاط',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TaqwaColors.domeBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStudentId,
          isExpanded: true,
          hint: const Text(
            'اختر الطالب',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
          ),
          items: _students
              .map((s) => DropdownMenuItem<String>(
                    value: s['id'],
                    child: Text(
                      s['fullName'],
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            final student = _students.firstWhere((s) => s['id'] == value);
            setState(() {
              _selectedStudentId = value;
              _selectedStudentName = student['fullName'];
            });
          },
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final isSelected = _selectedCategoryId == cat['id'];
        final isDeduct = cat['type'] == 'DEDUCT';
        final color = isDeduct ? Colors.red : TaqwaColors.islamicGreen;

        return GestureDetector(
          onTap: () => _onCategorySelected(cat['id']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDeduct ? Icons.remove_circle : Icons.add_circle,
                  size: 18,
                  color: isSelected ? color : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  (cat['nameAr'] as String?) ?? (cat['name'] as String),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${cat['defaultValue']})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: isSelected ? color : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingSelector() {
    final ratings = [
      {'value': 'GOOD', 'label': 'جيد', 'color': Colors.blue},
      {'value': 'VERY_GOOD', 'label': 'جيد جداً', 'color': Colors.green},
      {'value': 'REPEAT', 'label': 'إعادة', 'color': Colors.orange},
    ];

    return Row(
      children: ratings.map((r) {
        final isSelected = _selectedRating == r['value'];
        final color = r['color'] as Color;

        return Expanded(
          child: GestureDetector(
            onTap: () => _onRatingSelected(r['value'] as String),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? color : Colors.grey.shade400,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r['label'] as String,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPointsDisplay() {
    final isDeduct =
        _selectedCategory != null && _selectedCategory!['type'] == 'DEDUCT';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDeduct
              ? Colors.red.withOpacity(0.3)
              : TaqwaColors.minaretGold.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            isDeduct ? 'نقاط الخصم' : 'النقاط المضافة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrease button
              IconButton(
                onPressed: _points > 0
                    ? () => setState(() => _points--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                iconSize: 32,
              ),
              const SizedBox(width: 16),
              // Points value
              Text(
                '$_points',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isDeduct ? Colors.red : TaqwaColors.islamicGreen,
                ),
              ),
              const SizedBox(width: 16),
              // Increase button
              IconButton(
                onPressed: () => setState(() => _points++),
                icon: const Icon(Icons.add_circle_outline),
                color: TaqwaColors.islamicGreen,
                iconSize: 32,
              ),
            ],
          ),
          if (_selectedStudentName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _selectedStudentName!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: TaqwaColors.domeBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}