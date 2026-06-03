import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/widgets/points_display.dart';
import '../../../../core/extensions/points_formatting.dart';

class LeaderboardScreen extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final String? currentStudentId;

  const LeaderboardScreen({
    super.key,
    required this.leaderboard,
    this.currentStudentId,
  });

  /// Prisma's `Decimal` type can arrive as int, double, or String.
  /// Coerce defensively so callers never have to care.
  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('ترتيب الطلاب',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Top 3 podium
            if (leaderboard.length >= 3) _buildPodium(),
            // Full list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: leaderboard.length,
                itemBuilder: (context, index) {
                  final s = leaderboard[index];
                  final name = s['fullName'] ?? s['name'] ?? 'طالب';
                  final points = _toNum(s['totalPoints']);
                  final isMe = s['id'] == currentStudentId ||
                      s['studentId'] == currentStudentId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? TaqwaColors.domeBlue.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: isMe
                          ? Border.all(
                              color: TaqwaColors.domeBlue.withOpacity(0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: index < 3
                                ? _podiumColor(index).withOpacity(0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: index < 3
                                ? Icon(_podiumIcon(index),
                                    size: 18, color: _podiumColor(index))
                                : Text('${index + 1}',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? '$name (أنت)' : name,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: isMe
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isMe
                                      ? TaqwaColors.domeBlue
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                'المرتبة ${index + 1}',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Points badge — formatted via PointsDisplay
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: TaqwaColors.minaretGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: TaqwaColors.minaretGold),
                              const SizedBox(width: 4),
                              PointsDisplay(
                                value: points,
                                size: PointsDisplaySize.small,
                                color: TaqwaColors.minaretGold,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TaqwaColors.domeBlue, Color(0xFF14395A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (leaderboard.length > 1)
            _podiumItem(leaderboard[1], 1, 80),
          const SizedBox(width: 12),
          // 1st place
          _podiumItem(leaderboard[0], 0, 100),
          const SizedBox(width: 12),
          // 3rd place
          if (leaderboard.length > 2)
            _podiumItem(leaderboard[2], 2, 65),
        ],
      ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> student, int rank, double height) {
    final name = student['fullName'] ?? student['name'] ?? 'طالب';
    final points = _toNum(student['totalPoints']);
    final isMe = student['id'] == currentStudentId ||
        student['studentId'] == currentStudentId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st
        if (rank == 0)
          const Icon(Icons.emoji_events,
              color: TaqwaColors.minaretGold, size: 32),
        const SizedBox(height: 4),
        // Name
        Text(
          isMe ? 'أنت' : name,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: rank == 0 ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Points (2-decimal, tabular figures, LTR)
        Text(
          points.asPoints,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: TaqwaColors.minaretGold,
          ),
        ),
        const SizedBox(height: 6),
        // Podium block
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: _podiumColor(rank).withOpacity(0.2),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: _podiumColor(rank).withOpacity(0.4)),
          ),
          child: Center(
            child: Text('${rank + 1}',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _podiumColor(rank))),
          ),
        ),
      ],
    );
  }

  Color _podiumColor(int rank) {
    switch (rank) {
      case 0:
        return TaqwaColors.minaretGold;
      case 1:
        return Colors.white70;
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  IconData _podiumIcon(int rank) {
    switch (rank) {
      case 0:
        return Icons.emoji_events;
      case 1:
        return Icons.workspace_premium;
      case 2:
        return Icons.military_tech;
      default:
        return Icons.circle;
    }
  }
}