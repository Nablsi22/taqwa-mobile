import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/taqwa_colors.dart';
import '../../../../core/utils/meeting_days.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../attendance/presentation/providers/attendance_provider.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../../instructor_home/presentation/screens/maqraa_screen.dart';
import '../../data/substitute_api.dart';
import '../../data/substitute_models.dart';
import '../substitute_ui.dart';

/// ═════════════════════════════════════════════════════════════════════════
/// «حلقات أخرى» — recording for a حلقة that is not yours.
///
/// What the mosque agreed, and what this screen therefore does:
///   • any instructor may record attendance and recitation for another
///     حلقة's students, as a separate entry with its own colour and banner,
///     so it is never mistaken for his own حلقة;
///   • he sees names only;
///   • the student stays with his own instructor — nothing here reassigns
///     anybody — and the record keeps who marked it;
///   • «استلمت هالحلقة اليوم» tells the evening reminder who covered, even
///     before anything has been recorded.
///
/// On a server that predates `/substitute` the screen says so in one calm
/// line instead of showing an error.
/// ═════════════════════════════════════════════════════════════════════════
class OtherHalaqasScreen extends StatefulWidget {
  const OtherHalaqasScreen({
    super.key,
    required this.myInstructorId,
    this.date,
    this.termId,
  });

  /// Used only to tell my own «استلمت» apart from someone else's in a card.
  /// Whose حلقة is excluded from the list is the server's decision.
  final String? myInstructorId;

  /// The day being recorded — the course's last meeting day, as everywhere
  /// else in the app. Absent → today on the server.
  final String? date;

  final int? termId;

  @override
  State<OtherHalaqasScreen> createState() => _OtherHalaqasScreenState();
}

class _OtherHalaqasScreenState extends State<OtherHalaqasScreen> {
  final _api = SubstituteApi(ApiClient.instance);

  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  OtherHalaqasResult? _result;

  /// Halaqas with a claim/release request in flight, so a card can show a
  /// spinner without freezing the rest of the list.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getHalaqas(date: widget.date);
      if (!mounted) return;
      setState(() {
        _result = res;
        _loading = false;
      });
    } on SubstituteUnavailable {
      if (!mounted) return;
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _date => _result?.date ?? widget.date ?? isoDay(DateTime.now());

  void _toast(String message, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo'),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: bad ? Colors.red : SubstituteColors.accent,
      ),
    );
  }

  // ── «استلمت هالحلقة اليوم» ──────────────────────────────────────────────

  Future<void> _toggleCoverage(OtherHalaqa halaqa) async {
    setState(() => _busy.add(halaqa.instructorId));
    try {
      if (halaqa.coveredByMe) {
        await _api.release(halaqa.instructorId, date: _date);
        _toast('تم التراجع عن استلام حلقة أ. ${halaqa.instructorName}');
      } else {
        await _api.claim(halaqa.instructorId, date: _date);
        _toast('تم تسجيل استلامك لحلقة أ. ${halaqa.instructorName}');
      }
      await _load();
    } catch (e) {
      _toast(e.toString(), bad: true);
    } finally {
      if (mounted) setState(() => _busy.remove(halaqa.instructorId));
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────

  /// The ordinary attendance sheet, pointed at another حلقة and wearing the
  /// by-proxy colours. The server stores the mark under this instructor.
  void _recordAttendance(OtherHalaqa halaqa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AttendanceProvider(
            repository: AttendanceRepository(apiClient: ApiClient.instance),
            instructorId: halaqa.instructorId,
            initialDate: _date,
          ),
          child: AttendanceScreen(
            substitute: SubstituteMode(
              halaqaInstructorId: halaqa.instructorId,
              instructorName: halaqa.instructorName,
            ),
          ),
        ),
      ),
    ).then((_) => _load());
  }

  /// Recitation by proxy. The roster is fetched first because المقرأة works
  /// from a list of students, and a substitute is given names only.
  Future<void> _recordRecitation(OtherHalaqa halaqa) async {
    setState(() => _busy.add(halaqa.instructorId));
    HalaqaRoster? roster;
    try {
      roster = await _api.getRoster(
        halaqa.instructorId,
        date: _date,
        termId: widget.termId,
      );
    } catch (e) {
      _toast(e.toString(), bad: true);
    } finally {
      if (mounted) setState(() => _busy.remove(halaqa.instructorId));
    }
    if (!mounted || roster == null) return;
    if (roster.students.isEmpty) {
      _toast('لا يوجد طلاب في هذه الحلقة', bad: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaqraaScreen(
          students: roster!.students
              .map((s) => s.toStudentMap())
              .toList(growable: false),
          instructorId: halaqa.instructorId,
          substitute: SubstituteMode(
            halaqaInstructorId: halaqa.instructorId,
            instructorName: halaqa.instructorName,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SubstituteColors.surface,
        appBar: AppBar(
          title: const Text(
            'حلقات أخرى',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: SubstituteColors.header,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: RefreshIndicator(
          color: SubstituteColors.header,
          onRefresh: _load,
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(color: SubstituteColors.header),
      );
    }

    if (_unavailable) {
      return _centered(
        icon: Icons.cloud_off_rounded,
        title: 'التسجيل بالنيابة يظهر بعد تحديث الخادم',
        subtitle: 'حلقتك وتسجيل حضورها تعمل كالمعتاد.',
      );
    }

    if (_error != null && _result == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.7),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: SubstituteColors.header,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final halaqas = _result?.halaqas ?? const <OtherHalaqa>[];
    if (halaqas.isEmpty) {
      return _centered(
        icon: Icons.groups_2_outlined,
        title: 'لا توجد حلقات أخرى',
        subtitle: 'تظهر هنا حلقات بقية الأساتذة التي فيها طلاب.',
      );
    }

    final note = dayKindNote(_result?.dayKind);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _DayHeader(date: _date, note: note),
        const SizedBox(height: 14),
        for (final h in halaqas) ...[
          _HalaqaCard(
            halaqa: h,
            others: h.othersCovering(widget.myInstructorId),
            busy: _busy.contains(h.instructorId),
            onToggleCoverage: () => _toggleCoverage(h),
            onAttendance: () => _recordAttendance(h),
            onRecitation: () => _recordRecitation(h),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        const QuietNote(
          text: 'الطالب يبقى في حلقته مع أستاذه؛ ما تسجّله يُحفظ باسمك كمسجِّل '
              'ويظهر في إحصائيات حلقته.',
        ),
      ],
    );
  }

  Widget _centered({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 62, color: SubstituteColors.accent.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: SubstituteColors.header,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            color: Colors.grey.shade600,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

// ── The day being recorded ───────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, this.note});

  final String date;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final today = date == isoDay(DateTime.now());
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_rounded,
                  size: 18, color: SubstituteColors.header),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  today ? '${dayLabel(date)} · اليوم' : dayLabel(date),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AttendanceColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            QuietNote(text: note!, icon: Icons.star_rounded),
          ],
        ],
      ),
    );
  }
}

// ── One حلقة ─────────────────────────────────────────────────────────────

class _HalaqaCard extends StatelessWidget {
  const _HalaqaCard({
    required this.halaqa,
    required this.others,
    required this.busy,
    required this.onToggleCoverage,
    required this.onAttendance,
    required this.onRecitation,
  });

  final OtherHalaqa halaqa;
  final List<CoveringInstructor> others;
  final bool busy;
  final VoidCallback onToggleCoverage;
  final VoidCallback onAttendance;
  final VoidCallback onRecitation;

  @override
  Widget build(BuildContext context) {
    final mine = halaqa.coveredByMe;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mine ? SubstituteColors.claimedFill : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mine
              ? SubstituteColors.accent.withValues(alpha: 0.45)
              : TaqwaColors.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: SubstituteColors.header.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SubstituteColors.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded,
                    size: 20, color: SubstituteColors.header),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أ. ${halaqa.instructorName}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AttendanceColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      studentsAr(halaqa.students),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (mine)
                const TintPill(
                  label: 'استلمتها اليوم',
                  color: SubstituteColors.accent,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // How much of the day is already recorded — whoever recorded it.
          Row(
            children: [
              if (halaqa.notRecorded)
                const TintPill(
                  label: 'لم تُسجّل بعد',
                  color: AttendanceColors.absent,
                )
              else if (halaqa.unmarked == 0)
                const TintPill(
                  label: 'مكتملة',
                  color: AttendanceColors.present,
                )
              else
                TintPill(
                  label: 'بقي ${studentsAr(halaqa.unmarked)}',
                  color: AttendanceColors.irregular,
                ),
              const SizedBox(width: 8),
              if (!halaqa.notRecorded)
                Text(
                  'سُجّل ${halaqa.recorded} من ${halaqa.students}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),

          if (others.isNotEmpty) ...[
            const SizedBox(height: 8),
            QuietNote(
              icon: Icons.handshake_outlined,
              text: others.length == 1
                  ? 'استلمها اليوم أ. ${others.first.name}'
                  : 'استلمها اليوم: ${others.map((o) => 'أ. ${o.name}').join(' · ')}',
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  icon: Icons.check_circle_outline,
                  label: 'الحضور',
                  filled: true,
                  onTap: busy ? null : onAttendance,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardButton(
                  icon: Icons.menu_book_rounded,
                  label: 'التسميع',
                  filled: false,
                  onTap: busy ? null : onRecitation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // The claim itself: a note about today, not a reassignment, so it
          // sits apart from the two recording buttons.
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: busy ? null : onToggleCoverage,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SubstituteColors.header,
                      ),
                    )
                  : Icon(
                      mine ? Icons.undo_rounded : Icons.handshake_outlined,
                      size: 18,
                    ),
              label: Text(
                mine ? 'تراجع عن الاستلام' : 'استلمت هالحلقة اليوم',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: SubstituteColors.header,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: filled ? Colors.white : SubstituteColors.header,
    );
    return filled
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label, style: style),
            style: ElevatedButton.styleFrom(
              backgroundColor: SubstituteColors.header,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label, style: style),
            style: OutlinedButton.styleFrom(
              foregroundColor: SubstituteColors.header,
              side: BorderSide(
                color: SubstituteColors.accent.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          );
  }
}
