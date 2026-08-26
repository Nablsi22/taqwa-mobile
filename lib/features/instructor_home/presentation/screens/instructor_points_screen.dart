import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

class InstructorPointsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  const InstructorPointsScreen({super.key, required this.students});

  @override
  State<InstructorPointsScreen> createState() => _InstructorPointsScreenState();
}

class _InstructorPointsScreenState extends State<InstructorPointsScreen> {
  List<Map<String, dynamic>> _manualRules = [];
  // Cache category IDs by type for instant reliable lookup
  String? _earnCategoryId;
  String? _deductCategoryId;
  bool _isLoading = true;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/point-rules/manual'),
        ApiClient.instance.get('/points/categories'),
      ]);

      final rulesData = results[0].data;
      final catsData = results[1].data;

      List rulesList = [];
      if (rulesData is Map && rulesData['data'] is List) {
        rulesList = rulesData['data'];
      } else if (rulesData is List) {
        rulesList = rulesData;
      }

      List catsList = [];
      if (catsData is Map && catsData['data'] is List) {
        catsList = catsData['data'];
      } else if (catsData is List) {
        catsList = catsData;
      }

      // Cache category IDs by type — done once, used everywhere
      _earnCategoryId = null;
      _deductCategoryId = null;
      for (final cat in catsList) {
        final type = cat['type'] as String? ?? '';
        final id = cat['id'] as String?;
        if (id == null) continue;
        if (type == 'EARN' && _earnCategoryId == null) {
          _earnCategoryId = id;
        } else if (type == 'DEDUCT' && _deductCategoryId == null) {
          _deductCategoryId = id;
        }
      }

      debugPrint('=== CATEGORIES CACHED ===');
      debugPrint('EARN category: $_earnCategoryId');
      debugPrint('DEDUCT category: $_deductCategoryId');

      if (mounted) {
        setState(() {
          _manualRules = rulesList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading points data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('خطأ في تحميل البيانات', isError: true);
      }
    }
  }

  /// Show a styled snackbar — guaranteed to display
  void _showMessage(String text, {bool isError = false, bool isDeduct = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
      backgroundColor: isError
          ? Colors.red.shade700
          : isDeduct
              ? Colors.orange.shade700
              : TaqwaColors.islamicGreen,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  /// Core method: award points to a student
  Future<void> _awardPoints({
    required String studentId,
    required String studentName,
    required int amount,
    required bool isEarn,
    required String description,
  }) async {
    if (amount == 0) {
      _showMessage('لا يمكن إضافة 0 نقطة', isError: true);
      return;
    }

    // Pick the correct category by type
    final categoryId = isEarn ? _earnCategoryId : _deductCategoryId;

    if (categoryId == null) {
      _showMessage(
        isEarn ? 'لا توجد فئة إضافة نقاط' : 'لا توجد فئة خصم نقاط',
        isError: true,
      );
      return;
    }

    setState(() => _isApplying = true);

    try {
      debugPrint('=== AWARD POINTS ===');
      debugPrint(
          'Student: $studentName, Amount: $amount, IsEarn: $isEarn, Category: $categoryId');

      await ApiClient.instance.post('/points/award', data: {
        'studentId': studentId,
        'categoryId': categoryId,
        'amount': amount.abs(),
        'description': description,
      });

      if (isEarn) {
        _showMessage('تم إضافة +${amount.abs()} نقطة لـ $studentName ($description)');
      } else {
        _showMessage(
          'تم خصم -${amount.abs()} نقطة من $studentName ($description)',
          isDeduct: true,
        );
      }
    } on DioException catch (e) {
      debugPrint('Award points DioException: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      String errorMsg = 'فشل في تطبيق النقاط';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        errorMsg = data['message'].toString();
      }
      _showMessage(errorMsg, isError: true);
    } catch (e) {
      debugPrint('Award points error: $e');
      _showMessage('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  /// Apply a predefined rule to a student
  Future<void> _applyRule(
      Map<String, dynamic> student, Map<String, dynamic> rule) async {
    final studentId = student['studentId'] as String;
    final studentName = student['fullName'] as String? ?? 'طالب';
    final points = (rule['points'] as num?)?.toInt() ?? 0;
    final ruleName = rule['nameAr'] as String? ?? 'قاعدة';

    if (points == 0) {
      _showMessage('هذه القاعدة لا تحتوي على نقاط', isError: true);
      return;
    }

    await _awardPoints(
      studentId: studentId,
      studentName: studentName,
      amount: points.abs(),
      isEarn: points > 0,
      description: ruleName,
    );
  }

  /// Apply custom manual points to a student
  Future<void> _applyCustomPoints(
    Map<String, dynamic> student,
    int amount,
    bool isDeduct,
    String description,
  ) async {
    final studentId = student['studentId'] as String;
    final studentName = student['fullName'] as String? ?? 'طالب';

    await _awardPoints(
      studentId: studentId,
      studentName: studentName,
      amount: amount,
      isEarn: !isDeduct,
      description:
          description.isNotEmpty ? description : (isDeduct ? 'خصم يدوي' : 'إضافة يدوية'),
    );
  }

  /// Show the points action bottom sheet for a student
  void _showPointsSheet(Map<String, dynamic> student) {
    final studentName = student['fullName'] as String? ?? 'طالب';
    final earnRules = _manualRules
        .where((r) => ((r['points'] as num?)?.toInt() ?? 0) > 0)
        .toList();
    final deductRules = _manualRules
        .where((r) => ((r['points'] as num?)?.toInt() ?? 0) < 0)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // Handle bar
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Student name header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TaqwaColors.domeBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person,
                                color: TaqwaColors.domeBlue, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(studentName,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: TaqwaColors.domeBlue)),
                                Text('إدارة النقاط',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    // Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        // Keyboard-aware bottom inset. Extends the scroll
                        // extent by the keyboard height so the custom-points
                        // fields can rise above it; collapses to zero when
                        // the keyboard is dismissed.
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          16 + MediaQuery.of(ctx).viewInsets.bottom,
                        ),
                        children: [
                          // === EARN RULES ===
                          if (earnRules.isNotEmpty) ...[
                            _buildSectionTitle('إضافة نقاط',
                                Icons.add_circle, TaqwaColors.islamicGreen),
                            const SizedBox(height: 8),
                            ...earnRules.map(
                                (rule) => _buildRuleChip(rule, student, ctx)),
                            const SizedBox(height: 20),
                          ],
                          // === DEDUCT RULES ===
                          if (deductRules.isNotEmpty) ...[
                            _buildSectionTitle(
                                'خصم نقاط', Icons.remove_circle, Colors.red),
                            const SizedBox(height: 8),
                            ...deductRules.map(
                                (rule) => _buildRuleChip(rule, student, ctx)),
                            const SizedBox(height: 20),
                          ],
                          // === CUSTOM POINTS ===
                          _buildSectionTitle('نقاط مخصصة', Icons.edit_note,
                              TaqwaColors.minaretGold),
                          const SizedBox(height: 8),
                          _buildCustomPointsCard(student, ctx),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildRuleChip(Map<String, dynamic> rule,
      Map<String, dynamic> student, BuildContext sheetCtx) {
    final nameAr = rule['nameAr'] as String? ?? '';
    final points = (rule['points'] as num?)?.toInt() ?? 0;
    final isEarn = points > 0;
    final description = rule['description'] as String?;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isApplying
            ? null
            : () async {
                // Close sheet first, then apply
                Navigator.pop(sheetCtx);
                await _applyRule(student, rule);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Points badge
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isEarn
                      ? TaqwaColors.islamicGreen.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${isEarn ? '+' : ''}$points',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isEarn ? TaqwaColors.islamicGreen : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nameAr,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    if (description != null && description.isNotEmpty)
                      Text(description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPointsCard(
      Map<String, dynamic> student, BuildContext sheetCtx) {
    final pointsController = TextEditingController();
    final descController = TextEditingController();
    bool isDeduct = false;

    return StatefulBuilder(builder: (ctx, setCardState) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: TaqwaColors.minaretGold.withOpacity(0.3), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Earn / Deduct toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setCardState(() => isDeduct = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isDeduct
                              ? TaqwaColors.islamicGreen.withOpacity(0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: !isDeduct
                                  ? TaqwaColors.islamicGreen
                                  : Colors.grey.shade300,
                              width: 2),
                        ),
                        child: Center(
                          child: Text('إضافة +',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: !isDeduct
                                      ? TaqwaColors.islamicGreen
                                      : Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setCardState(() => isDeduct = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isDeduct
                              ? Colors.red.withOpacity(0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isDeduct
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: 2),
                        ),
                        child: Center(
                          child: Text('خصم -',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDeduct ? Colors.red : Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Points amount
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'عدد النقاط',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  suffixText: 'نقطة',
                  suffixStyle: TextStyle(
                      fontFamily: 'Cairo', color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Description
              TextField(
                controller: descController,
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  labelText: 'السبب *',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  hintText: 'اكتب سبب الإضافة أو الخصم',
                  hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.note_alt_outlined,
                      color: TaqwaColors.domeBlue),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // Submit button
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final pts =
                        int.tryParse(pointsController.text.trim());
                    if (pts == null || pts <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('يرجى إدخال عدد نقاط صحيح',
                              style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: Colors.red));
                      return;
                    }
                    if (descController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('يرجى كتابة السبب',
                              style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(sheetCtx);
                    _applyCustomPoints(student, pts, isDeduct,
                        descController.text.trim());
                  },
                  icon: Icon(isDeduct ? Icons.remove : Icons.add,
                      color: Colors.white, size: 18),
                  label: Text(
                    isDeduct ? 'خصم النقاط' : 'إضافة النقاط',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDeduct ? Colors.red : TaqwaColors.islamicGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('إدارة النقاط',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: TaqwaColors.domeBlue))
                : widget.students.isEmpty
                    ? Center(
                        child: Text('لا يوجد طلاب',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.grey.shade500,
                                fontSize: 16)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.students.length,
                        itemBuilder: (context, index) {
                          final student = widget.students[index];
                          return _buildStudentTile(student, index);
                        },
                      ),
            // Loading overlay when applying points
            if (_isApplying)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: TaqwaColors.domeBlue),
                          SizedBox(height: 16),
                          Text('جارِ تطبيق النقاط...',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> student, int index) {
    final name = student['fullName'] as String? ?? 'طالب';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TaqwaColors.domeBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: TaqwaColors.domeBlue)),
          ),
        ),
        title: Text(name,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        subtitle: Text('اضغط لإدارة النقاط',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade500)),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: TaqwaColors.minaretGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 16, color: TaqwaColors.minaretGold),
              SizedBox(width: 4),
              Text('النقاط',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.domeBlue)),
            ],
          ),
        ),
        onTap: _isApplying ? null : () => _showPointsSheet(student),
      ),
    );
  }
}