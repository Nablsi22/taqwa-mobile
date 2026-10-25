import 'package:flutter/material.dart';

import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../../../instructor_home/presentation/screens/add_recitation_screen.dart';
import '../../../instructor_home/presentation/screens/maqraa_screen.dart';
import '../../data/substitute_groups.dart';
import '../../data/substitute_models.dart';
import '../substitute_ui.dart';
import '../widgets/group_picker_sheet.dart';

/// ═════════════════════════════════════════════════════════════════════════
/// «تسميع حلقة أ. فلان» — recitation for a حلقة you are covering.
///
/// The students of the absent teacher, names only, as the mosque agreed:
///   • tap a student → his own recitation form (the same one you use for
///     your students, in the by-proxy violet);
///   • «المقرأة الجماعية» → the group recitation, as before;
///   • when the حلقة is shared out between several teachers, «طلابي اليوم»
///     puts the ones sitting with you on top, and المقرأة covers only them.
///
/// A student whose recitation you saved here is ticked, so in a crowded
/// evening you can see at a glance who is left.
/// ═════════════════════════════════════════════════════════════════════════
class SubstituteStudentsScreen extends StatefulWidget {
  const SubstituteStudentsScreen({
    super.key,
    required this.roster,
    required this.mode,
  });

  final HalaqaRoster roster;
  final SubstituteMode mode;

  @override
  State<SubstituteStudentsScreen> createState() => _SubstituteStudentsScreenState();
}

class _SubstituteStudentsScreenState extends State<SubstituteStudentsScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// «طلابي اليوم»; null → the whole حلقة.
  Set<String>? _group;
  bool _showRest = false;

  /// Recited here during this visit.
  final Set<String> _done = {};

  SubstituteMode get _mode => widget.mode;
  List<RosterStudent> get _students => widget.roster.students;
  String get _date => _mode.date ?? widget.roster.date;

  /// Two students called «محمد» are told apart by their father's name;
  /// everyone else is shown by his own name, as in the attendance sheet.
  late final Map<String, String> _names = _displayNames(_students);

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    if (_date.isEmpty) return;
    final group = await SubstituteGroups.read(_mode.halaqaInstructorId, _date);
    if (!mounted) return;
    // A student who left the حلقة since the choice is simply dropped.
    final ids = _students.map((s) => s.studentId).toSet();
    final kept = group?.where(ids.contains).toSet();
    setState(() => _group = (kept == null || kept.isEmpty) ? null : kept);
  }

  Future<void> _chooseGroup() async {
    final picked = await showSubstituteGroupPicker(
      context,
      instructorName: _mode.instructorName,
      students: [
        for (final s in _students) PickableStudent(id: s.studentId, name: _names[s.studentId]!),
      ],
      initial: _group,
    );
    if (picked == null || !mounted) return;
    if (_date.isNotEmpty) {
      await SubstituteGroups.write(_mode.halaqaInstructorId, _date, picked);
    }
    if (!mounted) return;
    setState(() {
      _group = picked.isEmpty ? null : picked;
      _showRest = false;
    });
  }

  Future<void> _openStudent(RosterStudent s) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecitationScreen(
          studentId: s.studentId,
          studentName: _names[s.studentId]!,
          substitute: _mode,
        ),
      ),
    );
    if (saved == true && mounted) setState(() => _done.add(s.studentId));
  }

  Future<void> _openMaqraa() async {
    final group = _group;
    final students = group == null
        ? _students
        : _students.where((s) => group.contains(s.studentId)).toList(growable: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaqraaScreen(
          students: students.map((s) => s.toStudentMap()).toList(growable: false),
          instructorId: _mode.halaqaInstructorId,
          substitute: _mode,
        ),
      ),
    );
  }

  bool _matches(RosterStudent s) {
    final q = normalizeArabicName(_query);
    if (q.isEmpty) return true;
    return normalizeArabicName(s.displayName).contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final searching = _query.trim().isNotEmpty;
    final mine = _students
        .where((s) => (group == null || group.contains(s.studentId)) && _matches(s))
        .toList(growable: false);
    final rest = group == null
        ? const <RosterStudent>[]
        : _students
            .where((s) => !group.contains(s.studentId) && _matches(s))
            .toList(growable: false);
    // While searching, the rest of the حلقة opens by itself: you are
    // looking for someone, wherever he sits.
    final restOpen = _showRest || searching;
    final maqraaCount = group?.length ?? _students.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SubstituteColors.surface,
        appBar: AppBar(
          title: Text(
            'تسميع حلقة أ. ${_mode.instructorName}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: SubstituteColors.header,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: SubstituteColors.header,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  SubstituteBanner(
                    instructorName: _mode.instructorName,
                    subtitle: 'اختر الطالب لتسجيل تسميعه، أو ابدأ المقرأة الجماعية',
                  ),
                  const SizedBox(height: 8),
                  SubstituteGroupStrip(
                    mine: group?.length,
                    total: _students.length,
                    mode: _mode,
                    onDark: true,
                    onChoose: _chooseGroup,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن طالب',
                      hintStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searching
                          ? IconButton(
                              tooltip: 'مسح',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  _MaqraaCard(count: maqraaCount, onTap: _openMaqraa),
                  const SizedBox(height: 16),
                  _Heading(
                    text: group == null ? 'طلاب الحلقة' : 'طلابك اليوم',
                    trailing: _done.isEmpty ? null : 'سُجّل ${_done.length}',
                  ),
                  const SizedBox(height: 8),
                  if (mine.isEmpty)
                    _Empty(text: searching ? 'لا يوجد طالب بهذا الاسم' : 'لا يوجد طلاب'),
                  for (final s in mine) _row(s),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _RestHeader(
                      count: rest.length,
                      open: restOpen,
                      onTap: searching ? null : () => setState(() => _showRest = !_showRest),
                    ),
                    if (restOpen) ...[
                      const SizedBox(height: 8),
                      for (final s in rest) _row(s, dimmed: true),
                    ],
                  ],
                  const SizedBox(height: 10),
                  const QuietNote(
                    text: 'الطالب يبقى في حلقته مع أستاذه؛ يُحفظ التسميع باسمك '
                        'ويظهر في سجله عند أستاذه.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(RosterStudent s, {bool dimmed = false}) {
    final name = _names[s.studentId]!;
    final done = _done.contains(s.studentId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: done ? const Color(0xFFEAF7EF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openStudent(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: done
                    ? AttendanceColors.present.withValues(alpha: 0.35)
                    : SubstituteColors.accent.withValues(alpha: dimmed ? 0.10 : 0.18),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: done
                      ? AttendanceColors.present.withValues(alpha: 0.15)
                      : SubstituteColors.claimedFill,
                  child: done
                      ? const Icon(Icons.check_rounded, size: 20, color: AttendanceColors.present)
                      : Text(
                          name.isNotEmpty ? name[0] : '?',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: SubstituteColors.header,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: dimmed ? Colors.grey.shade700 : AttendanceColors.ink,
                    ),
                  ),
                ),
                if (done)
                  const TintPill(label: 'سُجّل', color: AttendanceColors.present, dense: true)
                else ...[
                  Text(
                    'تسميع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SubstituteColors.accent.withValues(alpha: 0.9),
                    ),
                  ),
                  // Mirrored in RTL: points toward the reading end, «‹».
                  Icon(Icons.chevron_right_rounded,
                      color: SubstituteColors.accent.withValues(alpha: 0.7)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Own name, or «الاسم ابن فلان» when two students share a first name.
Map<String, String> _displayNames(List<RosterStudent> students) {
  final counts = <String, int>{};
  for (final s in students) {
    counts.update(s.fullName.trim(), (n) => n + 1, ifAbsent: () => 1);
  }
  return {
    for (final s in students)
      s.studentId: (counts[s.fullName.trim()]! > 1 && s.fatherName.trim().isNotEmpty)
          ? '${s.fullName} ابن ${s.fatherName}'
          : s.fullName,
  };
}

class _MaqraaCard extends StatelessWidget {
  const _MaqraaCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: count == 0 ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SubstituteColors.accent.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: SubstituteColors.claimedFill,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    size: 22, color: SubstituteColors.header),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المقرأة الجماعية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: SubstituteColors.header,
                      ),
                    ),
                    Text(
                      'تسميع جماعي دفعة واحدة · ${studentsAr(count)}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: SubstituteColors.accent.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: SubstituteColors.header,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          TintPill(label: trailing!, color: AttendanceColors.present, dense: true),
      ],
    );
  }
}

class _RestHeader extends StatelessWidget {
  const _RestHeader({required this.count, required this.open, required this.onTap});

  final int count;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.people_outline_rounded, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'بقية طلاب الحلقة ($count)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            if (onTap != null)
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
