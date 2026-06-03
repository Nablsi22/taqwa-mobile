import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import 'award_points_screen.dart';
import 'leaderboard_screen.dart';

class PointsHubScreen extends StatelessWidget {
  const PointsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            title: const Text(
              'برنامج النقاط',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            backgroundColor: TaqwaColors.domeBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: const TabBar(
              indicatorColor: TaqwaColors.minaretGold,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.add_circle_outline),
                  text: 'إضافة نقاط',
                ),
                Tab(
                  icon: Icon(Icons.emoji_events_outlined),
                  text: 'المتصدرين',
                ),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              AwardPointsScreen(),
              LeaderboardScreen(),
            ],
          ),
        ),
      ),
    );
  }
}