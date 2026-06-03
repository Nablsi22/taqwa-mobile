import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';

class AdminGiftsScreen extends StatefulWidget {
  const AdminGiftsScreen({super.key});

  @override
  State<AdminGiftsScreen> createState() => _AdminGiftsScreenState();
}

class _AdminGiftsScreenState extends State<AdminGiftsScreen> {
  List<Map<String, dynamic>> _gifts = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.get('/gifts');
      final data = response.data['data'] as List? ?? response.data as List? ?? [];
      setState(() {
        _gifts = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGift(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف الهدية',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذه الهدية؟',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ApiClient.instance.delete('/gifts/$id');
        _loadGifts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // IMAGE HANDLING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGiftImage(String? imageData,
      {double? height, BoxFit fit = BoxFit.cover}) {
    if (imageData == null || imageData.isEmpty) {
      return Container(
        color: TaqwaColors.domeBlue.withOpacity(0.06),
        child: const Center(
            child: Icon(Icons.card_giftcard, size: 48, color: TaqwaColors.domeBlue)),
      );
    }

    if (imageData.startsWith('http')) {
      return Image.network(imageData, fit: fit,
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey)));
    }

    try {
      final bytes = base64Decode(imageData);
      return Image.memory(Uint8List.fromList(bytes), fit: fit,
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey)));
    } catch (_) {
      return const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
    }
  }

  Future<Uint8List?> _pickAndCompressImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        // ═══ KEY FIX: Compress at pick time ═══
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
      );
      if (picked == null) return null;
      return await picked.readAsBytes();
    } catch (e) {
      debugPrint('Image pick error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ADD / EDIT GIFT DIALOG — uses full screen instead of bottom sheet
  // ═══════════════════════════════════════════════════════════════
  Future<void> _showAddEditDialog([Map<String, dynamic>? gift]) async {
    final nameController = TextEditingController(text: gift?['name'] ?? '');
    final descController =
        TextEditingController(text: gift?['description'] ?? '');
    final pointsController =
        TextEditingController(text: gift?['pointsCost']?.toString() ?? '');
    bool isAvailable = gift?['isAvailable'] ?? true;
    final isEditing = gift != null;

    String? currentImageData = gift?['imageData'];
    Uint8List? pickedImageBytes;
    bool imageChanged = false;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (ctx, setDialogState) => Scaffold(
              backgroundColor: const Color(0xFFF5F6FA),
              appBar: AppBar(
                backgroundColor: TaqwaColors.domeBlue,
                title: Text(
                  isEditing ? 'تعديل الهدية' : 'إضافة هدية جديدة',
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.white),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  TextButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          pointsController.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('يرجى ملء الاسم والنقاط',
                              style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }

                      String? imageData = currentImageData;
                      if (imageChanged && pickedImageBytes != null) {
                        imageData = base64Encode(pickedImageBytes!);
                      }

                      final body = {
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'pointsCost':
                            int.tryParse(pointsController.text) ?? 0,
                        'isAvailable': isAvailable,
                        if (imageData != null) 'imageData': imageData,
                      };

                      try {
                        if (isEditing) {
                          await ApiClient.instance
                              .put('/gifts/${gift!['id']}', data: body);
                        } else {
                          await ApiClient.instance.post('/gifts', data: body);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('خطأ: $e',
                                style: const TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    },
                    child: const Text('حفظ',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Image Section ──
                    const Text('صورة الهدية',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        // ═══ USE DIALOG instead of bottom sheet ═══
                        final source = await showDialog<ImageSource>(
                          context: ctx,
                          builder: (dCtx) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: SimpleDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('اختر مصدر الصورة',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold)),
                              children: [
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(
                                      dCtx, ImageSource.gallery),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.photo_library,
                                          color: TaqwaColors.domeBlue),
                                      SizedBox(width: 12),
                                      Text('معرض الصور',
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 15)),
                                    ],
                                  ),
                                ),
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(
                                      dCtx, ImageSource.camera),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.camera_alt,
                                          color: TaqwaColors.domeBlue),
                                      SizedBox(width: 12),
                                      Text('الكاميرا',
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (source != null) {
                          final bytes = await _pickAndCompressImage(source);
                          if (bytes != null) {
                            setDialogState(() {
                              pickedImageBytes = bytes;
                              imageChanged = true;
                            });
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: TaqwaColors.domeBlue.withOpacity(0.2)),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: pickedImageBytes != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(pickedImageBytes!,
                                      fit: BoxFit.cover),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: GestureDetector(
                                      onTap: () => setDialogState(() {
                                        pickedImageBytes = null;
                                        imageChanged = true;
                                        currentImageData = null;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : currentImageData != null &&
                                    currentImageData!.isNotEmpty
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildGiftImage(currentImageData),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: GestureDetector(
                                          onTap: () => setDialogState(() {
                                            currentImageData = null;
                                            imageChanged = true;
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close,
                                                color: Colors.white,
                                                size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo,
                                          size: 48,
                                          color: TaqwaColors.domeBlue
                                              .withOpacity(0.4)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'اضغط لإضافة صورة',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Name Field ──
                    _buildField(
                      controller: nameController,
                      label: 'اسم الهدية',
                      icon: Icons.card_giftcard,
                    ),
                    const SizedBox(height: 14),

                    // ── Description Field ──
                    _buildField(
                      controller: descController,
                      label: 'الوصف (اختياري)',
                      icon: Icons.description,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    // ── Points Field ──
                    _buildField(
                      controller: pointsController,
                      label: 'النقاط المطلوبة',
                      icon: Icons.star,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),

                    // ── Available Toggle ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility,
                              color: TaqwaColors.domeBlue),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('متاح للطلاب',
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 15)),
                          ),
                          Switch(
                            value: isAvailable,
                            activeColor: TaqwaColors.islamicGreen,
                            onChanged: (v) =>
                                setDialogState(() => isAvailable = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      _loadGifts();
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        prefixIcon: Icon(icon, color: TaqwaColors.domeBlue),
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
          borderSide: const BorderSide(color: TaqwaColors.domeBlue, width: 2),
        ),
      ),
      style: const TextStyle(fontFamily: 'Cairo'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: TaqwaColors.domeBlue,
          title: const Text('متجر الهدايا',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: TaqwaColors.minaretGold,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة هدية',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          onPressed: () => _showAddEditDialog(),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: TaqwaColors.domeBlue))
            : _gifts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لا توجد هدايا بعد',
                            style:
                                TextStyle(fontFamily: 'Cairo', fontSize: 16)),
                        SizedBox(height: 4),
                        Text('اضغط + لإضافة هدية جديدة',
                            style: TextStyle(
                                fontFamily: 'Cairo', color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: TaqwaColors.domeBlue,
                    onRefresh: _loadGifts,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _gifts.length,
                      itemBuilder: (context, index) {
                        final gift = _gifts[index];
                        return _buildGiftCard(gift);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> gift) {
    final name = gift['name'] ?? '';
    final points = gift['pointsCost'] ?? 0;
    final imageData = gift['imageData'] as String?;
    final isAvailable = gift['isAvailable'] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: _buildGiftImage(imageData),
              ),
              // Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TaqwaColors.minaretGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: TaqwaColors.minaretGold),
                            const SizedBox(width: 4),
                            Text(
                              '$points نقطة',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: TaqwaColors.domeBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Not available overlay
          if (!isAvailable)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'غير متاح',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          // Delete button
          Positioned(
            top: 6,
            left: 6,
            child: GestureDetector(
              onTap: () => _deleteGift(gift['id']),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.delete, color: Colors.white, size: 18),
              ),
            ),
          ),
          // Edit button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _showAddEditDialog(gift),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TaqwaColors.domeBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
