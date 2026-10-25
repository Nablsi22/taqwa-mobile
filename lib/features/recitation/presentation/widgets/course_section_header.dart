import 'package:flutter/material.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/recitation_timeline.dart';

/// The band that opens each course's part of a recitation record.
///
/// The current course is green with a calendar icon; an earlier course is
/// grey with a history icon, and gets extra space above it, so scrolling past
/// the current course reads clearly as «from here on: an earlier course».
class CourseSectionHeader extends StatelessWidget {
  const CourseSectionHeader({
    super.key,
    required this.section,
    this.isFirst = false,
    this.count,
  });

  final CourseSection section;

  /// What the pill counts when a page lists only part of the section (the
  /// admin page shows Quran recitations only). Defaults to every entry.
  final int? count;

  /// The first band on the page needs no gap above it.
  final bool isFirst;

  static const Color _earlierAccent = Color(0xFF5D6D7E);

  @override
  Widget build(BuildContext context) {
    final current = section.isCurrent;
    final accent = current ? TaqwaColors.islamicGreen : _earlierAccent;

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 2 : 26, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(
              current ? Icons.event_available_rounded : Icons.history_rounded,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (section.name != null)
                    Text(
                      section.kindLabel,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.nightSky,
                    ),
                  ),
                  if (section.period.isNotEmpty)
                    Text(
                      section.period,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Text(
                recitationsCountAr(count ?? section.count),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown under the current course's band when it has no entries yet.
class EmptyCourseNote extends StatelessWidget {
  const EmptyCourseNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'لم يُسجَّل أي تسميع في هذه الدورة بعد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
