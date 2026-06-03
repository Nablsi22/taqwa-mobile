import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

class PointsRulesScreen extends StatefulWidget {
  const PointsRulesScreen({super.key});

  @override
  State<PointsRulesScreen> createState() => _PointsRulesScreenState();
}

class _PointsRulesScreenState extends State<PointsRulesScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _isLoading = true;

  // ─── Class-level form state (survives lifecycle events) ───
  String _formName = '';
  String _formPoints = '1';
  String _formMinPages = '';
  bool _formIsPerPage = false;
  bool _formIsEarn = true;
  bool _formIsActive = true;
  String? _formRatingCondition;
  Map<String, dynamic>? _formEditingRule;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.dio.get('/point-rules');
      final data = response.data['data'] as List;
      setState(() {
        _rules = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ في تحميل القواعد: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteRule(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف القاعدة',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذه القاعدة؟',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف',
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.red))),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ApiClient.instance.dio.delete('/point-rules/$id');
        _loadRules();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> rule) async {
    try {
      await ApiClient.instance.dio
          .put('/point-rules/${rule['id']}', data: {
        'isActive': !(rule['isActive'] as bool? ?? true),
      });
      _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  /// Resets class-level form fields
  void _resetFormState([Map<String, dynamic>? rule]) {
    _formEditingRule = rule;
    _formName = rule?['nameAr'] ?? '';
    _formPoints =
        (rule?['pointsPerPage'] ?? rule?['points'] ?? 1).toString();
    _formMinPages = rule?['minPages']?.toString() ?? '';
    _formIsPerPage = (rule?['pointsPerPage'] ?? 0) > 0;
    _formIsEarn = (rule?['type'] ?? 'EARN') == 'EARN';
    _formIsActive = rule?['isActive'] ?? true;
    _formRatingCondition = rule?['ratingCondition'];
  }

  Future<void> _showAddEditDialog([Map<String, dynamic>? rule]) async {
    _resetFormState(rule);
    final isEditing = _formEditingRule != null;

    // Create fresh controllers each time the sheet opens
    final nameController = TextEditingController(text: _formName);
    final pointsController = TextEditingController(text: _formPoints);
    final minPagesController = TextEditingController(text: _formMinPages);

    // Sync class-level state as user types
    nameController.addListener(() => _formName = nameController.text);
    pointsController.addListener(() => _formPoints = pointsController.text);
    minPagesController
        .addListener(() => _formMinPages = minPagesController.text);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Header ───
                    Row(
                      children: [
                        Icon(
                          isEditing ? Icons.edit : Icons.add_circle,
                          color: TaqwaColors.domeBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditing
                              ? 'تعديل القاعدة'
                              : 'إضافة قاعدة نقاط جديدة',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: TaqwaColors.domeBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── Rule name ───
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: const InputDecoration(
                        labelText: 'اسم القاعدة *',
                        labelStyle: TextStyle(fontFamily: 'Cairo'),
                        border: OutlineInputBorder(),
                        hintText:
                            'مثل: تسميع جيد جداً - نقطتان لكل صفحة',
                        hintStyle:
                            TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        prefixIcon:
                            Icon(Icons.rule, color: TaqwaColors.domeBlue),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Type (EARN / DEDUCT) ───
                    const Text('نوع القاعدة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setModalState(() => _formIsEarn = true),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _formIsEarn
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _formIsEarn
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    width: _formIsEarn ? 2 : 1),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.add_circle,
                                      color: _formIsEarn
                                          ? Colors.green
                                          : Colors.grey,
                                      size: 24),
                                  const SizedBox(height: 4),
                                  Text('إضافة نقاط',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          fontWeight: _formIsEarn
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _formIsEarn
                                              ? Colors.green
                                              : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setModalState(() => _formIsEarn = false),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_formIsEarn
                                    ? Colors.red.withOpacity(0.15)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: !_formIsEarn
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                    width: !_formIsEarn ? 2 : 1),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.remove_circle,
                                      color: !_formIsEarn
                                          ? Colors.red
                                          : Colors.grey,
                                      size: 24),
                                  const SizedBox(height: 4),
                                  Text('خصم نقاط',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          fontWeight: !_formIsEarn
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: !_formIsEarn
                                              ? Colors.red
                                              : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── Points ───
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        labelText: _formIsPerPage
                            ? 'النقاط لكل صفحة *'
                            : 'عدد النقاط *',
                        labelStyle: const TextStyle(fontFamily: 'Cairo'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.star,
                            color: TaqwaColors.minaretGold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Per-page toggle ───
                    SwitchListTile(
                      value: _formIsPerPage,
                      onChanged: (v) =>
                          setModalState(() => _formIsPerPage = v),
                      title: const Text('لكل صفحة (تسميع)',
                          style: TextStyle(fontFamily: 'Cairo')),
                      subtitle: const Text(
                          'النقاط تُضرب بعدد الصفحات المُسمَّعة',
                          style: TextStyle(
                              fontFamily: 'Cairo', fontSize: 11)),
                      activeColor: TaqwaColors.islamicGreen,
                      contentPadding: EdgeInsets.zero,
                    ),

                    // ─── Rating condition (only if per-page) ───
                    if (_formIsPerPage) ...[
                      const SizedBox(height: 8),
                      const Text('شرط التقييم (اختياري)',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildRatingChip(
                              null, 'بدون شرط', setModalState),
                          _buildRatingChip(
                              'EXCELLENT', 'ممتاز', setModalState),
                          _buildRatingChip(
                              'VERY_GOOD', 'جيد جداً', setModalState),
                          _buildRatingChip(
                              'GOOD', 'جيد', setModalState),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // ─── Min pages (only if per-page) ───
                    if (_formIsPerPage)
                      TextField(
                        controller: minPagesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: const InputDecoration(
                          labelText: 'الحد الأدنى للصفحات (اختياري)',
                          labelStyle: TextStyle(fontFamily: 'Cairo'),
                          border: OutlineInputBorder(),
                          hintText: 'مثل: 5 صفحات',
                          hintStyle:
                              TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // ─── Active toggle ───
                    SwitchListTile(
                      value: _formIsActive,
                      onChanged: (v) =>
                          setModalState(() => _formIsActive = v),
                      title: const Text('القاعدة مفعّلة',
                          style: TextStyle(fontFamily: 'Cairo')),
                      activeColor: TaqwaColors.islamicGreen,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    // ─── Save ───
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _saveRule(
                          ctx,
                          nameController,
                          pointsController,
                          minPagesController,
                        ),
                        icon: Icon(isEditing ? Icons.save : Icons.add,
                            color: Colors.white),
                        label: Text(
                            isEditing ? 'حفظ التعديلات' : 'إضافة القاعدة',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TaqwaColors.domeBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );

    // Dispose controllers after sheet closes
    nameController.dispose();
    pointsController.dispose();
    minPagesController.dispose();

    if (result == true) _loadRules();
  }

  Widget _buildRatingChip(
      String? value, String label, StateSetter setModalState) {
    final isSelected = _formRatingCondition == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: isSelected ? Colors.white : TaqwaColors.domeBlue)),
      selected: isSelected,
      onSelected: (_) =>
          setModalState(() => _formRatingCondition = value),
      selectedColor: TaqwaColors.domeBlue,
      backgroundColor: TaqwaColors.domeBlue.withOpacity(0.08),
    );
  }

  Future<void> _saveRule(
    BuildContext ctx,
    TextEditingController nameCtrl,
    TextEditingController pointsCtrl,
    TextEditingController minPagesCtrl,
  ) async {
    if (nameCtrl.text.trim().isEmpty || pointsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('يرجى ملء الحقول المطلوبة',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.orange));
      return;
    }

    final pointsValue = int.tryParse(pointsCtrl.text.trim()) ?? 1;

    final body = <String, dynamic>{
      'nameAr': nameCtrl.text.trim(),
      'type': _formIsEarn ? 'EARN' : 'DEDUCT',
      'isActive': _formIsActive,
    };

    if (_formIsPerPage) {
      body['pointsPerPage'] = pointsValue;
      body['points'] = 0;
      if (minPagesCtrl.text.trim().isNotEmpty) {
        body['minPages'] = int.tryParse(minPagesCtrl.text.trim());
      }
      if (_formRatingCondition != null) {
        body['ratingCondition'] = _formRatingCondition;
      }
    } else {
      body['points'] = pointsValue;
      body['pointsPerPage'] = 0;
    }

    try {
      if (_formEditingRule != null) {
        await ApiClient.instance.dio
            .put('/point-rules/${_formEditingRule!['id']}', data: body);
      } else {
        await ApiClient.instance.dio.post('/point-rules', data: body);
      }
      if (ctx.mounted) Navigator.pop(ctx, true);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قواعد النقاط',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditDialog(),
          backgroundColor: TaqwaColors.minaretGold,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : _rules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rule, size: 80,
                            color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('لا توجد قواعد نقاط',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('اضغط + لإضافة قاعدة جديدة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRules,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rules.length,
                      itemBuilder: (context, index) =>
                          _buildRuleCard(_rules[index]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final name = rule['nameAr'] as String? ?? '';
    final type = rule['type'] as String? ?? 'EARN';
    final isEarn = type == 'EARN';
    final points = rule['pointsPerPage'] as int? ?? rule['points'] as int? ?? 0;
    final isPerPage = (rule['pointsPerPage'] ?? 0) > 0;
    final isActive = rule['isActive'] as bool? ?? true;
    final ratingCondition = rule['ratingCondition'] as String?;
    final minPages = rule['minPages'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAddEditDialog(rule),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEarn
                      ? Colors.green.withOpacity(0.12)
                      : Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEarn ? Icons.add_circle : Icons.remove_circle,
                  color: isEarn ? Colors.green : Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? TaqwaColors.domeBlue
                                : Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEarn
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isEarn ? '+' : '-'}$points ${isPerPage ? '/ صفحة' : 'نقطة'}',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isEarn ? Colors.green : Colors.red),
                          ),
                        ),
                        if (ratingCondition != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: TaqwaColors.domeBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _ratingLabel(ratingCondition),
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: TaqwaColors.domeBlue),
                            ),
                          ),
                        ],
                        if (minPages != null && minPages > 0) ...[
                          const SizedBox(width: 6),
                          Text('≥ $minPages ص',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  // Active toggle
                  Switch(
                    value: isActive,
                    onChanged: (_) => _toggleActive(rule),
                    activeColor: TaqwaColors.islamicGreen,
                  ),
                  // Delete
                  GestureDetector(
                    onTap: () => _deleteRule(rule['id'].toString()),
                    child: Icon(Icons.delete_outline,
                        size: 20, color: Colors.red.shade300),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ratingLabel(String code) {
    switch (code) {
      case 'EXCELLENT':
        return 'ممتاز';
      case 'VERY_GOOD':
        return 'جيد جداً';
      case 'GOOD':
        return 'جيد';
      default:
        return code;
    }
  }
}