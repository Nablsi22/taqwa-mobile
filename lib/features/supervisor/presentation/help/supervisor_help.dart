import 'package:flutter/material.dart';

import '../../../../core/theme/taqwa_colors.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import '../supervisor_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Plain-language help for the course director.
//
// Every heading on his screens carries a small «شرح» chip; it opens one of
// the topics below in a bottom sheet. The texts are written for someone who
// has never used the app: short sentences, what he sees, what it means, and
// what to tap next. The same texts feed the full guide
// (supervisor_guide_screen.dart), so the two never disagree.
// ═══════════════════════════════════════════════════════════════════════════

enum HelpTopic {
  overview,
  instructors,
  needFollowUp,
  slipping,
  disciplined,
  day,
  dayNotRecorded,
  dayRecorded,
  students,
  needsCall,
  studentClasses,
  instructorPage,
  lastSession,
  teacherPresence,
  teacherRecord,
  studentsCommitment,
  roster,
  recitations,
  halaqaDay,
  studentPage,
}

@immutable
class HelpContent {
  const HelpContent({
    required this.title,
    required this.icon,
    required this.points,
    this.showLegend = false,
  });

  final String title;
  final IconData icon;
  final List<String> points;

  /// Adds the explained colour key of the recording-discipline squares.
  final bool showLegend;
}

const Map<HelpTopic, HelpContent> kSupervisorHelp = {
  HelpTopic.overview: HelpContent(
    title: 'الصفحة الرئيسية',
    icon: Icons.home_rounded,
    points: [
      'ملخّص سريع لأهم ما يجري في الدورة، في صفحة واحدة.',
      'البطاقة الأولى: الحلقات التي لم يسجّل أستاذها الحضور في آخر جلسة.',
      'البطاقة الثانية: كم طالباً حضر في آخر جلسة من أصل جميع طلاب الدورة.',
      'البطاقة الثالثة: الطلاب الذين غابوا جلستين متتاليتين أو أكثر ويحتاجون إلى اتصال.',
      'اضغط على أي بطاقة لتنتقل إلى تفاصيلها.',
      'لتحديث الأرقام اسحب الصفحة إلى الأسفل.',
    ],
  ),
  HelpTopic.instructors: HelpContent(
    title: 'صفحة الأساتذة',
    icon: Icons.groups_rounded,
    showLegend: true,
    points: [
      'تعرض مدى انضباط كل أستاذ في تسجيل حضور طلاب حلقته.',
      'لكل أستاذ أربعة مربعات ملوّنة؛ كل مربع جلسة إلزامية من آخر أربع جلسات، وتحته تاريخها.',
      'الأساتذة مرتّبون من الأحوج إلى المتابعة إلى الأكثر انضباطاً.',
      'اضغط على اسم الأستاذ لترى حلقته: حضور طلابه وتسميعهم ونقاطهم.',
    ],
  ),
  HelpTopic.needFollowUp: HelpContent(
    title: 'يحتاجون إلى متابعة',
    icon: Icons.priority_high_rounded,
    points: [
      'أساتذة لم يسجّلوا حضور جلستين أو أكثر من آخر أربع جلسات، أو لم يسجّلوا أي جلسة.',
      'يُستحسن التواصل معهم وتذكيرهم بتسجيل الحضور يوم الجلسة.',
    ],
  ),
  HelpTopic.slipping: HelpContent(
    title: 'يتأخرون أحياناً',
    icon: Icons.schedule_rounded,
    points: [
      'أساتذة فاتهم تسجيل جلسة واحدة، أو سجّلوا الحضور بعد يوم الجلسة.',
      'التسجيل المتأخر محسوب، لكن الأفضل أن يكون في اليوم نفسه.',
    ],
  ),
  HelpTopic.disciplined: HelpContent(
    title: 'منضبطون',
    icon: Icons.verified_rounded,
    points: [
      'أساتذة سجّلوا حضور كل الجلسات الأخيرة في يومها.',
    ],
  ),
  HelpTopic.day: HelpContent(
    title: 'صفحة الجلسة',
    icon: Icons.event_note_rounded,
    points: [
      'تعرض يوماً واحداً من أيام الدوام لجميع الحلقات معاً.',
      'انتقل بين أيام الدوام بالسهمين في الأعلى، أو اضغط على التاريخ لاختيار أي يوم.',
      'البطاقة الأولى: كم حلقة سجّلت، وكم طالباً حضر من أصل طلاب الدورة.',
      'ثم الحلقات التي لم تسجّل، ثم الحلقات التي سجّلت مع عدد الحاضرين والغائبين.',
      'اضغط على أي حلقة لترى أسماء طلابها وحالة كل طالب في ذلك اليوم.',
      'اليوم الإلزامي يُحسب فيه الغياب، واليوم الاختياري يُكافأ فيه من حضر ولا يُحاسَب من غاب.',
    ],
  ),
  HelpTopic.dayNotRecorded: HelpContent(
    title: 'حلقات لم تسجّل',
    icon: Icons.edit_off_rounded,
    points: [
      'حلقات لم يسجّل أستاذها حضور الطلاب في هذا اليوم حتى الآن.',
      'لذلك لا يدخل طلابها في أعداد الحاضرين والغائبين.',
      'في اليوم الاختياري لا يُحاسَب أحد على عدم التسجيل.',
    ],
  ),
  HelpTopic.dayRecorded: HelpContent(
    title: 'حلقات سجّلت',
    icon: Icons.fact_check_rounded,
    points: [
      'بجانب كل حلقة: عدد من حضر، وعدد من غاب، ومتى سُجّل الحضور.',
      'إن ظهرت كلمة «بالنيابة» فقد سجّل الحضور أستاذ آخر بدلاً من أستاذ الحلقة.',
      'اضغط على الحلقة لترى أسماء الحاضرين والغائبين.',
    ],
  ),
  HelpTopic.students: HelpContent(
    title: 'صفحة الطلاب',
    icon: Icons.school_rounded,
    points: [
      'تعرض حال جميع طلاب الدورة في الحضور خلال آخر أربعة أسابيع.',
      'ثابت: لم يغب أكثر من جلسة إلزامية واحدة (المتأخر يُحسب حاضراً).',
      'متذبذب: غاب أكثر من جلسة، لكنه ما زال يحضر.',
      'منقطع: لم يحضر أي جلسة في الأسابيع الأربعة.',
      'بلا جلسات: حلقته لم تسجّل الحضور، فلا نعرف حاله.',
      'طلاب حلقة «عزل» غير محسوبين.',
      'اضغط على اسم أي طالب لترى صفحته الكاملة.',
    ],
  ),
  HelpTopic.needsCall: HelpContent(
    title: 'يحتاجون إلى اتصال',
    icon: Icons.phone_in_talk_rounded,
    points: [
      'طلاب غابوا جلستين إلزاميتين متتاليتين أو أكثر دون عذر.',
      'يُستحسن أن يتصل أستاذ الحلقة بأهلهم ليطمئن عليهم.',
      'الغياب بعذر لا يُحسب هنا.',
    ],
  ),
  HelpTopic.studentClasses: HelpContent(
    title: 'ثابت · متذبذب · منقطع',
    icon: Icons.insights_rounded,
    points: [
      'يُقاس الحضور على آخر أربعة أسابيع، وعلى جلسات حلقة الطالب نفسه.',
      'ثابت: لم يغب أكثر من جلسة إلزامية واحدة (المتأخر يُحسب حاضراً).',
      'متذبذب: غاب أكثر من جلسة، لكنه ما زال يحضر.',
      'منقطع: لم يحضر أي جلسة في الأسابيع الأربعة.',
      'بلا جلسات: حلقته لم تسجّل الحضور، فلا نعرف حاله.',
    ],
  ),
  HelpTopic.instructorPage: HelpContent(
    title: 'صفحة الأستاذ',
    icon: Icons.person_rounded,
    points: [
      'فيها ثلاثة أقسام تختارها من الأعلى:',
      'الحضور: آخر جلسة للحلقة، وسجل تسجيل الأستاذ في كل أيام الدوام، والتزام كل طالب بالحضور.',
      'الطلاب: نقاط كل طالب المكتسبة والمخصومة، وحفظه، وحضوره، مع تصفية حسب المدرسة والصف.',
      'التسميع: ماذا سمّع كل طالب يوماً بيوم: السورة، ومن آية إلى آية، والتقدير، والنقاط.',
      'اضغط على اسم أي طالب لترى صفحته الكاملة.',
    ],
  ),
  HelpTopic.lastSession: HelpContent(
    title: 'آخر جلسة',
    icon: Icons.today_rounded,
    points: [
      'كم طالباً حضر في آخر جلسة من أصل طلاب الحلقة، ومن غاب.',
      'اضغط «أسماء الحلقة كاملة» لترى حالة كل طالب.',
    ],
  ),
  HelpTopic.teacherPresence: HelpContent(
    title: 'حضور الأستاذ',
    icon: Icons.badge_rounded,
    points: [
      'هل حضر الأستاذ نفسه إلى المسجد في أيام الدوام، كما سجّلته الإدارة في «حضور المعلمين».',
      'وهذا غير تسجيله لحضور طلابه.',
    ],
  ),
  HelpTopic.teacherRecord: HelpContent(
    title: 'سجل الأستاذ في أيام الدوام',
    icon: Icons.history_edu_rounded,
    showLegend: true,
    points: [
      'كل يوم دوام إلزامي في الدورة: هل سجّل الأستاذ حضور طلابه، ومتى سجّله.',
      'في الأعلى ملخّص: كم جلسة سجّل، وكم منها في اليوم نفسه، وكم تأخر، وكم فاته.',
      'اضغط على أي يوم لترى أسماء الحاضرين والغائبين في ذلك اليوم.',
    ],
  ),
  HelpTopic.studentsCommitment: HelpContent(
    title: 'التزام الطلاب بالحضور',
    icon: Icons.how_to_reg_rounded,
    points: [
      'طلاب الحلقة مقسّمون حسب التزامهم في آخر أربعة أسابيع: منقطع، متذبذب، ثابت.',
      'وفي الأسفل أسماء من غاب جلستين متتاليتين أو أكثر ويحتاج إلى اتصال.',
      'لترى صفحة أي طالب افتح قسم «الطلاب» في الأعلى واضغط على اسمه.',
    ],
  ),
  HelpTopic.roster: HelpContent(
    title: 'طلاب الحلقة',
    icon: Icons.groups_2_rounded,
    points: [
      'لكل طالب: رصيد نقاطه، والنقاط التي اكتسبها (+) والتي خُصمت منه (−) في هذه الدورة.',
      'وصفحات حفظه ونسبتها من المصحف، وحضوره في الدورة، وآخر ما سمّعه.',
      'استخدم «المدرسة» و«الصف» في الأعلى لتصفية الطلاب، وأزرار الترتيب لترتيبهم.',
      'اضغط على الطالب لترى صفحته الكاملة.',
    ],
  ),
  HelpTopic.recitations: HelpContent(
    title: 'تسميع الحلقة',
    icon: Icons.menu_book_rounded,
    points: [
      'ماذا سمّع طلاب الحلقة في يوم معيّن: السورة، ومن آية إلى آية، وعدد الصفحات، والتقدير، والنقاط، ومن سجّل التسميع.',
      'انتقل بين أيام الدوام بالسهمين، أو اضغط على التاريخ لاختيار يوم، أو اختر «آخر 30 يوماً» لترى الشهر كله.',
      'اضغط على اسم الطالب لترى تسميعه في كل الدورات.',
    ],
  ),
  HelpTopic.halaqaDay: HelpContent(
    title: 'الحلقة في يوم الجلسة',
    icon: Icons.groups_rounded,
    points: [
      'أسماء طلاب الحلقة في هذا اليوم، وحالة كل طالب: حاضر، متأخر، غائب، غائب بعذر.',
      'تحت اسم الطالب تنبيه إن تكرر غيابه.',
      'اضغط على أي طالب لترى صفحته وتقويم حضوره.',
    ],
  ),
  HelpTopic.studentPage: HelpContent(
    title: 'صفحة الطالب',
    icon: Icons.account_circle_rounded,
    points: [
      'هي الصفحة نفسها التي يراها أستاذه، للاطلاع فقط.',
      'معلومات: بياناته الشخصية ومدرسته وصفّه.',
      'الحضور: تقويم شهري ملوّن بحضوره وغيابه.',
      'التسميع: كل ما سمّعه في كل الدورات؛ الدورة الحالية أولاً، ثم الدورات السابقة.',
      'النقاط: كل نقطة أخذها أو خُصمت منه، وسببها.',
      'الحفظ: السور التي حفظها. الأربعين: ما حفظه من الأحاديث النووية.',
    ],
  ),
};

/// Opens [topic] in a bottom sheet.
Future<void> showSupervisorHelp(BuildContext context, HelpTopic topic) {
  final h = kSupervisorHelp[topic]!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              HelpHeading(icon: h.icon, title: h.title),
              const SizedBox(height: 14),
              for (final p in h.points) HelpPoint(p),
              if (h.showLegend) ...[
                const SizedBox(height: 10),
                const ExplainedDisciplineLegend(),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: TaqwaColors.domeBlue,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'فهمت',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The small «؟ شرح» chip placed beside a heading.
class HelpChip extends StatelessWidget {
  const HelpChip(this.topic, {super.key});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'شرح: ${kSupervisorHelp[topic]!.title}',
      child: ExcludeSemantics(
        child: Material(
          color: TaqwaColors.lightBlue,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showSupervisorHelp(context, topic),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline_rounded, size: 15, color: TaqwaColors.skyBlue),
                  SizedBox(width: 3),
                  Text(
                    'شرح',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: TaqwaColors.skyBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A «؟» icon for an app bar.
class HelpAppBarButton extends StatelessWidget {
  const HelpAppBarButton(this.topic, {super.key});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'شرح هذه الصفحة',
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => showSupervisorHelp(context, topic),
    );
  }
}

class HelpHeading extends StatelessWidget {
  const HelpHeading({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(color: TaqwaColors.lightBlue, shape: BoxShape.circle),
          child: Icon(icon, color: TaqwaColors.domeBlue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AttendanceColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class HelpPoint extends StatelessWidget {
  const HelpPoint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: TaqwaColors.minaretGold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.75,
                color: Color(0xFF34495E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The colours of the recording squares, each with a full sentence.
class ExplainedDisciplineLegend extends StatelessWidget {
  const ExplainedDisciplineLegend({super.key});

  static const _rows = <(Color, String, bool, String)>[
    (DisciplineColors.onTime, '✓', true, 'سجّل الحضور في يوم الجلسة نفسه'),
    (DisciplineColors.dayLate, '+1', true, 'سجّل بعد الجلسة بيوم'),
    (DisciplineColors.veryLate, '+2', true, 'سجّل بعد يومين أو أكثر'),
    (DisciplineColors.missed, '✕', true, 'لم يسجّل الحضور'),
    (DisciplineColors.covered, 'نيابة', true, 'سجّلها أستاذ آخر بالنيابة، ولا تُحتسب تقصيراً على أستاذ الحلقة'),
    (DisciplineColors.notDue, '—', false, 'يوم اختياري لا يُحتسب'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaqwaColors.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معاني الألوان',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AttendanceColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final (color, mark, onDark, meaning) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      mark,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: onDark ? Colors.white : const Color(0xFF5D6D7E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meaning,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6, color: Color(0xFF34495E)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
