import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../data/term_model.dart';
import '../providers/term_provider.dart';

/// Course switcher for the AppBar of any screen that shows points.
///
/// Renders nothing at all when there is only one course, so a mosque that
/// never creates a second one sees the app exactly as it was.
///
/// Changing the selection is a READ action: it re-reads the same screen for a
/// different course. It never affects where new records go.
class TermSelectorAction extends StatelessWidget {
  const TermSelectorAction({super.key, this.onChanged});

  /// Called after the viewed course changes, so the host screen can refetch.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TermProvider>();
    if (!provider.hasMultipleTerms) return const SizedBox.shrink();

    final viewed = provider.viewedTerm;
    if (viewed == null) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      tooltip: 'اختيار الدورة',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (id) {
        provider.viewTerm(id);
        onChanged?.call();
      },
      itemBuilder: (_) => provider.terms
          .map((t) => PopupMenuItem<int>(
                value: t.id,
                child: _TermMenuRow(term: t, selected: t.id == viewed.id),
              ))
          .toList(growable: false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              provider.isViewingArchive
                  ? Icons.history_rounded
                  : Icons.event_available_rounded,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                viewed.nameAr,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _TermMenuRow extends StatelessWidget {
  const _TermMenuRow({required this.term, required this.selected});

  final Term term;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 17,
          color: selected ? TaqwaColors.domeBlue : Colors.grey.shade400,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                term.nameAr,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? TaqwaColors.domeBlue : Colors.grey.shade800,
                ),
              ),
              Text(
                term.periodLabel,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        if (term.isActive) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: TaqwaColors.islamicGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'الحالية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: TaqwaColors.islamicGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline strip naming the course the figures below belong to.
///
/// On a points screen this answers "whose numbers am I looking at?"; when the
/// viewed course is an archived one it turns amber and says so, so an old
/// leaderboard is never mistaken for today's.
class TermContextBanner extends StatelessWidget {
  const TermContextBanner({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TermProvider>();
    final viewed = provider.viewedTerm;
    if (viewed == null || !provider.hasMultipleTerms) {
      return const SizedBox.shrink();
    }

    final archive = provider.isViewingArchive;
    final accent = archive ? const Color(0xFFB9770E) : TaqwaColors.domeBlue;

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            archive ? Icons.history_rounded : Icons.event_available_rounded,
            size: 17,
            color: accent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              archive
                  ? 'أرشيف: ${viewed.nameAr} — نقاط هذه الدورة فقط'
                  : 'الدورة الحالية: ${viewed.nameAr}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
          if (archive)
            TextButton(
              onPressed: provider.viewActiveTerm,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'العودة للحالية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Prominent strip for RECORDING screens: which course this entry will be
/// filed under. Always the ACTIVE course — never the browsed one — because
/// that is where the backend will put it regardless of what is on screen
/// elsewhere. Its whole job is to stop a session being logged against the
/// wrong course without anyone noticing.
class ActiveTermRecordingBanner extends StatelessWidget {
  const ActiveTermRecordingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TermProvider>();
    final active = provider.activeTerm;

    if (active == null) {
      if (!provider.hasLoaded) return const SizedBox.shrink();
      // No course activated: the backend will refuse the save, so say why
      // before the instructor fills the whole form.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEDEC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TaqwaColors.alertRed.withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: TaqwaColors.alertRed),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'لا توجد دورة مفعّلة. يرجى تفعيل دورة من «إدارة الدورات» قبل التسجيل.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: TaqwaColors.alertRed,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TaqwaColors.islamicGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TaqwaColors.islamicGreen.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 18, color: TaqwaColors.islamicGreen),
          const SizedBox(width: 9),
          Text(
            'التسجيل ضمن:',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              active.nameAr,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: TaqwaColors.islamicGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
