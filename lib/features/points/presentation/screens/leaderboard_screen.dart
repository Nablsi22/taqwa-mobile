import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/points_api.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _pointsApi = PointsApi(ApiClient.instance);
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _pointsApi.getLeaderboard(limit: 50);
      setState(() {
        _leaderboard = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'لوحة المتصدرين',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: TaqwaColors.domeBlue),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadLeaderboard,
                          child: const Text('إعادة المحاولة',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  )
                : _leaderboard.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد نقاط مسجلة بعد',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLeaderboard,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaderboard.length,
                          itemBuilder: (context, index) {
                            final student = _leaderboard[index];
                            return _buildRankCard(student, index);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildRankCard(Map<String, dynamic> student, int index) {
    final rank = student['rank'] as int;
    final isTop3 = rank <= 3;

    Color rankColor;
    IconData? rankIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700);
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0);
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32);
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = TaqwaColors.domeBlue;
        rankIcon = null;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isTop3 ? 4 : 1,
      shadowColor: isTop3 ? rankColor.withOpacity(0.3) : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isTop3
            ? BorderSide(color: rankColor.withOpacity(0.4), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Rank
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(isTop3 ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: rankIcon != null
                    ? Icon(rankIcon, color: rankColor, size: 24)
                    : Text(
                        '$rank',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: rankColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + instructor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['fullName'] as String,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: isTop3 ? 16 : 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    'المعلم: ${student['instructorName'] ?? '-'}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // Points
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: TaqwaColors.minaretGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star,
                      color: TaqwaColors.minaretGold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${student['totalPoints']}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.minaretGold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}