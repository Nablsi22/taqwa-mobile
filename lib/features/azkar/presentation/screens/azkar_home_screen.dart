import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../azkar/data/azkar_data.dart';
import 'azkar_reader_screen.dart';

class AzkarHomeScreen extends StatelessWidget {
  const AzkarHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              backgroundColor: TaqwaColors.domeBlue,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B4F72),
                        Color(0xFF154360),
                        Color(0xFF0E2F44),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _getTimeGreeting(),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '\u0627\u0644\u0623\u0630\u0643\u0627\u0631 \u0648\u0627\u0644\u0623\u062f\u0639\u064a\u0629',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\u062d\u0635\u0651\u0646 \u0646\u0641\u0633\u0643 \u0628\u0630\u0643\u0631 \u0627\u0644\u0644\u0647 \u062a\u0639\u0627\u0644\u0649',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: _buildSuggestedCard(context),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  '\u062c\u0645\u064a\u0639 \u0627\u0644\u0623\u0630\u0643\u0627\u0631',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4F72),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = allAzkarCategories[index];
                    return _buildCategoryCard(context, category, index);
                  },
                  childCount: allAzkarCategories.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // FIX: Changed from 1.15 to 1.0 to give cards more height for Arabic text
                  childAspectRatio: 0.85,
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  '\u062a\u0633\u0628\u064a\u062d \u0633\u0631\u064a\u0639',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4F72),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                child: _QuickTasbihWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '\u2600\uFE0F \u0635\u0628\u0627\u062d \u0627\u0644\u062e\u064a\u0631';
    if (hour < 17) return '\uD83C\uDF24\uFE0F \u0645\u0633\u0627\u0621 \u0627\u0644\u0646\u0648\u0631';
    return '\uD83C\uDF19 \u0645\u0633\u0627\u0621 \u0627\u0644\u062e\u064a\u0631';
  }

  AzkarCategory _getSuggestedCategory() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return morningAzkar;
    if (hour >= 12 && hour < 17) return postPrayerAzkar;
    if (hour >= 17 && hour < 21) return eveningAzkar;
    return sleepAzkar;
  }

  Widget _buildSuggestedCard(BuildContext context) {
    final suggested = _getSuggestedCategory();
    final colors = _getCategoryColors(suggested.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AzkarReaderScreen(category: suggested),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [colors[0], colors[1]],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '\u0645\u0642\u062a\u0631\u062d \u0627\u0644\u0622\u0646',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    suggested.name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${suggested.adhkar.length} \u0630\u0643\u0631',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              suggested.icon,
              style: const TextStyle(fontSize: 52),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getCategoryColors(String id) {
    switch (id) {
      case 'morning':
        return [const Color(0xFFFF8C42), const Color(0xFFFFB347)];
      case 'evening':
        return [const Color(0xFF3A1C71), const Color(0xFF5B3E96)];
      case 'post_prayer':
        return [const Color(0xFF1B4F72), const Color(0xFF2E86C1)];
      case 'sleep':
        return [const Color(0xFF0D3B66), const Color(0xFF1B6CA8)];
      case 'general':
        return [const Color(0xFF1E8449), const Color(0xFF27AE60)];
      default:
        return [TaqwaColors.domeBlue, TaqwaColors.skyBlue];
    }
  }

  IconData _getCategoryIcon(String id) {
    switch (id) {
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'evening':
        return Icons.nightlight_round;
      case 'post_prayer':
        return Icons.mosque_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'general':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Widget _buildCategoryCard(
      BuildContext context, AzkarCategory category, int index) {
    final colors = _getCategoryColors(category.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AzkarReaderScreen(category: category),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getCategoryIcon(category.id),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${category.adhkar.length} \u0630\u0643\u0631',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTasbihWidget extends StatefulWidget {
  @override
  State<_QuickTasbihWidget> createState() => _QuickTasbihWidgetState();
}

class _QuickTasbihWidgetState extends State<_QuickTasbihWidget>
    with SingleTickerProviderStateMixin {
  int _count = 0;
  int _selectedIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _tasbihOptions = [
    '\u0633\u0628\u0652\u062d\u064e\u0627\u0646\u064e \u0627\u0644\u0644\u064e\u0651\u0647\u0650',
    '\u0627\u0644\u0652\u062d\u064e\u0645\u0652\u062f\u0650 \u0644\u0650\u0644\u064e\u0651\u0647\u0650',
    '\u0627\u0644\u0644\u064e\u0651\u0647\u0650 \u0623\u064e\u0643\u0652\u0628\u064e\u0631\u0650',
    '\u0644\u064e\u0627 \u0625\u0650\u0644\u064e\u0647\u064e \u0625\u0650\u0644\u064e\u0651\u0627 \u0627\u0644\u0644\u064e\u0651\u0647\u0650',
    '\u0623\u064e\u0633\u0652\u062a\u064e\u063a\u0652\u0641\u0650\u0631\u0650 \u0627\u0644\u0644\u064e\u0651\u0647\u064e',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _increment() {
    _pulseController.forward().then((_) => _pulseController.reverse());
    setState(() => _count++);
  }

  void _reset() {
    setState(() => _count = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: _tasbihOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      _count = 0;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TaqwaColors.domeBlue
                          : const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tasbihOptions[index],
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$_count',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B4F72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _tasbihOptions[_selectedIndex],
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              color: Color(0xFF34495E),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _reset,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: _increment,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B4F72), Color(0xFF2E86C1)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: TaqwaColors.domeBlue.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
