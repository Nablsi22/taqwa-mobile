import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/announcement_api.dart';
import 'create_announcement_screen.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  final _api = AnnouncementApi(ApiClient.instance);
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  // ─── Determine current user role ──────────────────────────────────────────
  String get _userRole {
    try {
      return context.read<AuthProvider>().user?.role.value ?? 'STUDENT';
    } catch (_) {
      return 'STUDENT';
    }
  }

  bool get _canCreate => _userRole == 'ADMIN' || _userRole == 'INSTRUCTOR';

  bool get _isAdmin => _userRole == 'ADMIN';

  // ─── Load announcements from API ──────────────────────────────────────────
  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _api.getAll();
      if (mounted) {
        setState(() {
          _announcements = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── Navigate to create screen ────────────────────────────────────────────
  Future<void> _navigateToCreate(
      {Map<String, dynamic>? announcement}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateAnnouncementScreen(announcement: announcement),
      ),
    );
    if (result == true) _loadAnnouncements();
  }

  // ─── Delete announcement ──────────────────────────────────────────────────
  Future<void> _deleteAnnouncement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الإعلان',
              style: TextStyle(fontFamily: 'Cairo')),
          content: const Text('هل أنت متأكد من حذف هذا الإعلان؟',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child:
                  const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _api.delete(id);
        _loadAnnouncements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الإعلان بنجاح',
                  style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في حذف الإعلان: $e',
                  style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─── Toggle pin (admin only) ──────────────────────────────────────────────
  Future<void> _togglePin(String id) async {
    try {
      await _api.togglePin(id);
      _loadAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تغيير حالة التثبيت: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'الإعلانات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: TaqwaColors.domeBlue,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAnnouncements,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: _canCreate
            ? FloatingActionButton.extended(
                onPressed: () => _navigateToCreate(),
                backgroundColor: TaqwaColors.domeBlue,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'إعلان جديد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'فشل في تحميل الإعلانات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadAnnouncements,
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
        ),
      );
    }

    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد إعلانات حالياً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _canCreate
                  ? 'اضغط + لإضافة إعلان جديد'
                  : 'ستظهر الإعلانات هنا عند نشرها',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      color: TaqwaColors.domeBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _announcements.length,
        itemBuilder: (ctx, i) => _buildAnnouncementCard(_announcements[i]),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENT CARD
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildAnnouncementCard(Map<String, dynamic> ann) {
    final isPinned = ann['pinned'] == true;
    final authorData = ann['author'];
    final authorRole = authorData?['role'] ?? '';
    final isAdminAnnouncement = authorRole == 'ADMIN';

    // Determine author display name
    String authorName;
    if (isAdminAnnouncement) {
      authorName = 'الإدارة';
    } else {
      authorName = authorData?['instructor']?['fullName'] ??
          authorData?['username'] ??
          'معلم';
    }

    // Check if current user can modify this announcement
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final isOwner = ann['createdBy'] == currentUserId;
    final canModify = _isAdmin || isOwner;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPinned
            ? Border.all(color: TaqwaColors.minaretGold, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isAdminAnnouncement
                  ? TaqwaColors.domeBlue.withOpacity(0.06)
                  : TaqwaColors.islamicGreen.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Author badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdminAnnouncement
                        ? TaqwaColors.domeBlue
                        : TaqwaColors.islamicGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdminAnnouncement
                            ? Icons.admin_panel_settings
                            : Icons.school,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pinned indicator
                if (isPinned) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TaqwaColors.minaretGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin,
                            size: 12, color: TaqwaColors.minaretGold),
                        SizedBox(width: 3),
                        Text(
                          'مثبت',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TaqwaColors.minaretGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Scope badge
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdminAnnouncement
                        ? Colors.orange.withOpacity(0.12)
                        : Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAdminAnnouncement ? 'للجميع' : 'للطلاب',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAdminAnnouncement
                          ? Colors.orange[800]
                          : Colors.blue[800],
                    ),
                  ),
                ),

                const Spacer(),

                // Actions menu
                if (canModify)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: Colors.grey[600], size: 20),
                    onSelected: (val) {
                      switch (val) {
                        case 'edit':
                          _navigateToCreate(announcement: ann);
                          break;
                        case 'delete':
                          _deleteAnnouncement(ann['id']);
                          break;
                        case 'pin':
                          _togglePin(ann['id']);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      if (_isAdmin)
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(
                                isPinned
                                    ? Icons.push_pin_outlined
                                    : Icons.push_pin,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isPinned ? 'إلغاء التثبيت' : 'تثبيت',
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
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

          // ── Title & Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              ann['title'] ?? '',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2A4A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              ann['body'] ?? '',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.6,
                color: Colors.grey[700],
              ),
            ),
          ),

          // ── Footer: date ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(
                      ann['publishedAt'] ?? ann['createdAt'] ?? ''),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date formatter ───────────────────────────────────────────────────────
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

      final months = [
        '',
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${date.day} ${months[date.month]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
