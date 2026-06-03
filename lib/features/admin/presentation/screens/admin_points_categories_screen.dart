import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

class AdminPointsCategoriesScreen extends StatefulWidget {
  const AdminPointsCategoriesScreen({super.key});

  @override
  State<AdminPointsCategoriesScreen> createState() =>
      _AdminPointsCategoriesScreenState();
}

class _AdminPointsCategoriesScreenState
    extends State<AdminPointsCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response =
          await ApiClient.instance.get('/points/categories');
      final data = response.data['data'] as List;
      setState(() {
        _categories = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Load categories error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('خطأ في تحميل الفئات',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> category) async {
    final nameArController =
        TextEditingController(text: category['nameAr'] ?? category['name'] ?? '');
    final defaultValueController =
        TextEditingController(text: (category['defaultValue'] ?? 0).toString());
    bool isActive = category['isActive'] as bool? ?? true;
    bool hasRating = category['hasRating'] as bool? ?? false;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              'تعديل: ${category['nameAr'] ?? category['name']}',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameArController,
                    style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالعربية',
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: defaultValueController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'القيمة الافتراضية',
                      labelStyle: const TextStyle(fontFamily: 'Cairo'),
                      border: const OutlineInputBorder(),
                      suffixText: 'نقطة',
                      suffixStyle: TextStyle(
                          fontFamily: 'Cairo', color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('مفعّلة',
                        style: TextStyle(fontFamily: 'Cairo')),
                    value: isActive,
                    activeThumbColor: TaqwaColors.islamicGreen,
                    onChanged: isSaving
                        ? null
                        : (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('تحتاج تقييم',
                        style: TextStyle(fontFamily: 'Cairo')),
                    value: hasRating,
                    activeThumbColor: TaqwaColors.domeBlue,
                    onChanged: isSaving
                        ? null
                        : (v) => setDialogState(() => hasRating = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                child:
                    const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final value =
                            int.tryParse(defaultValueController.text.trim());
                        if (value == null || value < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('يرجى إدخال قيمة صحيحة',
                                  style: TextStyle(fontFamily: 'Cairo')),
                              backgroundColor: Colors.red));
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final body = <String, dynamic>{
                            'nameAr': nameArController.text.trim(),
                            'defaultValue': value,
                            'isActive': isActive,
                            'hasRating': hasRating,
                          };

                          debugPrint('=== UPDATE CATEGORY ===');
                          debugPrint('ID: ${category['id']}');
                          debugPrint('Body: $body');

                          final response = await ApiClient.instance.put(
                            '/points/categories/${category['id']}',
                            data: body,
                          );

                          debugPrint('Update response: ${response.statusCode}');
                          debugPrint('Response data: ${response.data}');

                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on DioException catch (e) {
                          debugPrint('=== UPDATE CATEGORY DIO ERROR ===');
                          debugPrint('Status: ${e.response?.statusCode}');
                          debugPrint('Response: ${e.response?.data}');
                          debugPrint('Message: ${e.message}');

                          setDialogState(() => isSaving = false);

                          if (ctx.mounted) {
                            String errorMsg = 'خطأ في التحديث';
                            final responseData = e.response?.data;
                            if (responseData is Map &&
                                responseData['message'] != null) {
                              errorMsg = responseData['message'].toString();
                            } else if (e.response?.statusCode == 500) {
                              errorMsg = 'خطأ في الخادم (500)';
                            } else if (e.response?.statusCode == 400) {
                              errorMsg = 'بيانات غير صحيحة';
                            }

                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(errorMsg,
                                    style:
                                        const TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.red));
                          }
                        } catch (e) {
                          debugPrint('=== UPDATE CATEGORY GENERIC ERROR ===');
                          debugPrint('Error: $e');

                          setDialogState(() => isSaving = false);

                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text('خطأ: $e',
                                    style:
                                        const TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.red));
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: TaqwaColors.islamicGreen),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
              ),
            ],
          ),
        );
      }),
    );

    nameArController.dispose();
    defaultValueController.dispose();
    if (result == true) _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('إعدادات فئات النقاط',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : _categories.isEmpty
                ? Center(
                    child: Text('لا توجد فئات',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            color: Colors.grey.shade600)))
                : RefreshIndicator(
                    onRefresh: _loadCategories,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) =>
                          _buildCategoryCard(_categories[index]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final name = (cat['nameAr'] as String?) ?? (cat['name'] as String? ?? '');
    final type = cat['type'] as String? ?? 'EARN';
    final defaultValue = cat['defaultValue'] as int? ?? 0;
    final isActive = cat['isActive'] as bool? ?? true;
    final hasRating = cat['hasRating'] as bool? ?? false;
    final isEarn = type == 'EARN';

    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showEditDialog(cat),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isEarn
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEarn ? Icons.add_circle : Icons.remove_circle,
                    color: isEarn ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Name + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (hasRating)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: TaqwaColors.domeBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('تقييم',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: TaqwaColors.domeBlue,
                                      fontWeight: FontWeight.bold)),
                            ),
                          if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('معطّلة',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Points value
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEarn
                        ? TaqwaColors.islamicGreen.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${isEarn ? '+' : '-'}$defaultValue',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isEarn ? TaqwaColors.islamicGreen : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}