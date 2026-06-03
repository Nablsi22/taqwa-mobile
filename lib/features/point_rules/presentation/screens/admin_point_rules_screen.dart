import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

class AdminPointRulesScreen extends StatefulWidget {
  const AdminPointRulesScreen({super.key});

  @override
  State<AdminPointRulesScreen> createState() => _AdminPointRulesScreenState();
}

class _AdminPointRulesScreenState extends State<AdminPointRulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _earnRules = [];
  List<Map<String, dynamic>> _deductRules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allItems = <Map<String, dynamic>>[];

    // ── Load point rules ──
    try {
      final rulesRes = await ApiClient.instance.get('/point-rules');
      debugPrint('Point rules response: ${rulesRes.data}');
      final rules = (rulesRes.data['data'] as List? ??
              rulesRes.data as List? ??
              [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      for (final rule in rules) {
        // PointRule model has: points (Int), isPerPage (Boolean)
        // points field holds the value (per-page if isPerPage is true)
        final int points = rule['points'] as int? ?? 0;
        final bool isPerPage = rule['isPerPage'] as bool? ?? false;
        // Determine type from sign: negative = DEDUCT, positive = EARN
        final String type = points < 0 ? 'DEDUCT' : 'EARN';

        allItems.add({
          'source': 'rule',
          'id': rule['id'],
          'name': rule['nameAr'] ?? rule['name'] ?? '',
          'description': rule['description'] ?? '',
          'type': type,
          'points': points,
          'isPerPage': isPerPage,
          'isActive': rule['isActive'] ?? true,
          'code': rule['code'] ?? '',
        });
      }
      debugPrint('Loaded ${rules.length} point rules');
    } catch (e) {
      debugPrint('Point rules error: $e');
    }

    // ── Load point categories ──
    try {
      final catRes = await ApiClient.instance.get('/points/categories');
      debugPrint('Point categories response: ${catRes.data}');
      final categories = (catRes.data['data'] as List? ??
              catRes.data as List? ??
              [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      for (final cat in categories) {
        final catName = cat['nameAr'] ?? cat['name'] ?? '';
        final alreadyExists =
            allItems.any((item) => item['name'] == catName);
        if (!alreadyExists) {
          allItems.add({
            'source': 'category',
            'id': cat['id'],
            'name': catName,
            'description': '',
            'type': cat['type'] ?? 'EARN',
            'points': cat['defaultValue'] ?? 0,
            'isPerPage': false,
            'isActive': cat['isActive'] ?? true,
          });
        }
      }
      debugPrint('Loaded ${categories.length} point categories');
    } catch (e) {
      debugPrint('Point categories error: $e');
    }

    setState(() {
      _earnRules = allItems.where((r) => r['type'] == 'EARN').toList();
      _deductRules = allItems.where((r) => r['type'] == 'DEDUCT').toList();
      _isLoading = false;
    });

    debugPrint(
        'Earn rules: ${_earnRules.length}, Deduct rules: ${_deductRules.length}');
  }

  Future<void> _editPoints(Map<String, dynamic> item) async {
    final int currentPoints = (item['points'] as int? ?? 0).abs();
    final controller = TextEditingController(text: '$currentPoints');
    final isPerPage = item['isPerPage'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'تعديل: ${item['name']}',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isPerPage ? 'النقاط لكل صفحة' : 'عدد النقاط',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(
                      isPerPage ? Icons.auto_stories : Icons.star),
                ),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18),
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
              child: const Text('حفظ',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final newValue = int.tryParse(controller.text.trim()) ?? 0;

      try {
        if (item['source'] == 'rule') {
          // ── FIX: Send "points" to match backend controller's dto.points ──
          debugPrint('=== UPDATE POINT RULE ===');
          debugPrint('ID: ${item['id']}, points: $newValue');

          await ApiClient.instance.put(
            '/point-rules/${item['id']}',
            data: {'points': newValue},
          );
        } else {
          // Category update
          debugPrint('=== UPDATE POINT CATEGORY ===');
          debugPrint('ID: ${item['id']}, defaultValue: $newValue');

          await ApiClient.instance.put(
            '/points/categories/${item['id']}',
            data: {'defaultValue': newValue},
          );
        }

        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم التحديث بنجاح',
                  style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: TaqwaColors.islamicGreen,
            ),
          );
        }
      } on DioException catch (e) {
        debugPrint('=== UPDATE ERROR ===');
        debugPrint('Status: ${e.response?.statusCode}');
        debugPrint('Response: ${e.response?.data}');

        if (mounted) {
          String errorMsg = 'خطأ في التحديث';
          final responseData = e.response?.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMsg = responseData['message'].toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(errorMsg, style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('=== UPDATE GENERIC ERROR: $e ===');
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: TaqwaColors.domeBlue,
          title: const Text('قواعد النقاط',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: TaqwaColors.minaretGold,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo'),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle, size: 18),
                    const SizedBox(width: 6),
                    const Text('إضافة نقاط'),
                    if (_earnRules.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_earnRules.length}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.remove_circle, size: 18),
                    const SizedBox(width: 6),
                    const Text('خصم نقاط'),
                    if (_deductRules.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_deductRules.length}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildRulesList(_earnRules, isEarn: true),
                  _buildRulesList(_deductRules, isEarn: false),
                ],
              ),
      ),
    );
  }

  Widget _buildRulesList(List<Map<String, dynamic>> rules,
      {required bool isEarn}) {
    final accentColor = isEarn ? TaqwaColors.islamicGreen : Colors.red;

    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEarn ? Icons.add_circle_outline : Icons.remove_circle_outline,
              size: 64,
              color: accentColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              isEarn ? 'لا توجد قواعد إضافة نقاط' : 'لا توجد قواعد خصم نقاط',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16, color: accentColor),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label:
                  const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: _loadData,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: TaqwaColors.domeBlue,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rules.length,
        itemBuilder: (context, index) {
          final rule = rules[index];
          final name = rule['name'] ?? '';
          final isPerPage = rule['isPerPage'] == true;
          // Display absolute value of points
          final int points = (rule['points'] as int? ?? 0).abs();

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                right: BorderSide(color: accentColor, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _editPoints(rule),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEarn ? Icons.add_circle : Icons.remove_circle,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            if (isPerPage)
                              Text(
                                'لكل صفحة',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: accentColor.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: accentColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              '${isEarn ? '+' : '-'}$points',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}