import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/azkar_data.dart';

class AzkarReaderScreen extends StatefulWidget {
  final AzkarCategory category;

  const AzkarReaderScreen({super.key, required this.category});

  @override
  State<AzkarReaderScreen> createState() => _AzkarReaderScreenState();
}

class _AzkarReaderScreenState extends State<AzkarReaderScreen> {
  // Track remaining count for each dhikr
  late List<int> _remainingCounts;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _remainingCounts = widget.category.adhkar
        .map((d) => d.repeatCount)
        .toList();
  }

  int get _totalAdhkar => widget.category.adhkar.length;

  double get _progress {
    if (_totalAdhkar == 0) return 0;
    return _completedCount / _totalAdhkar;
  }

  void _decrementCount(int index) {
    if (_remainingCounts[index] > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _remainingCounts[index]--;
        if (_remainingCounts[index] == 0) {
          _completedCount++;
        }
      });
    }
  }

  void _resetAll() {
    setState(() {
      _remainingCounts = widget.category.adhkar
          .map((d) => d.repeatCount)
          .toList();
      _completedCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _completedCount == _totalAdhkar;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: CustomScrollView(
          slivers: [
            // ─── App Bar with Progress ───
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: TaqwaColors.domeBlue,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _resetAll,
                  tooltip: 'إعادة',
                ),
              ],
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
                      padding: const EdgeInsets.fromLTRB(24, 50, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.category.icon,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.category.name,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Progress bar
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _progress,
                                    minHeight: 8,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFD4AC0D),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$_completedCount / $_totalAdhkar',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Completion Banner ───
            if (isCompleted)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E8449), Color(0xFF27AE60)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E8449).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ما شاء الله! أتممت الأذكار',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'بارك الله فيك، تقبّل الله منك',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Dhikr Cards ───
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dhikr = widget.category.adhkar[index];
                    final remaining = _remainingCounts[index];
                    final isDone = remaining == 0;

                    return _DhikrCard(
                      dhikr: dhikr,
                      index: index + 1,
                      remaining: remaining,
                      isDone: isDone,
                      onTap: () => _decrementCount(index),
                    );
                  },
                  childCount: widget.category.adhkar.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Individual Dhikr Card
// ═══════════════════════════════════════════════════════════
class _DhikrCard extends StatelessWidget {
  final Dhikr dhikr;
  final int index;
  final int remaining;
  final bool isDone;
  final VoidCallback onTap;

  const _DhikrCard({
    required this.dhikr,
    required this.index,
    required this.remaining,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDone ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF0FFF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isDone
              ? Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.3))
              : null,
          boxShadow: [
            if (!isDone)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Card Header ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF27AE60).withValues(alpha: 0.08)
                    : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  topLeft: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  // Index badge
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF27AE60)
                          : TaqwaColors.domeBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '$index',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Reference
                  if (dhikr.reference != null)
                    Expanded(
                      child: Text(
                        dhikr.reference!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Counter badge
                  if (dhikr.repeatCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF27AE60)
                            : remaining == dhikr.repeatCount
                                ? TaqwaColors.domeBlue.withValues(alpha: 0.1)
                                : const Color(0xFFD4AC0D).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isDone ? 'تمّ' : '$remaining / ${dhikr.repeatCount}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? Colors.white
                              : remaining == dhikr.repeatCount
                                  ? TaqwaColors.domeBlue
                                  : const Color(0xFFD4AC0D),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── Arabic Text ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                dhikr.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  height: 2.0,
                  fontWeight: FontWeight.w500,
                  color: isDone
                      ? Colors.grey.shade500
                      : const Color(0xFF2C3E50),
                ),
              ),
            ),

            // ─── Benefit ───
            if (dhikr.benefit != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4AC0D).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFD4AC0D),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dhikr.benefit!,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Color(0xFF7D6608),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Tap indicator for multi-repeat ───
            if (!isDone && dhikr.repeatCount > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    'اضغط للتسبيح',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: TaqwaColors.domeBlue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
