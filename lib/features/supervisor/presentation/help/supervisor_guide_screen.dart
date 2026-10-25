import 'package:flutter/material.dart';

import '../../../../core/theme/taqwa_colors.dart';
import '../../../attendance_stats/presentation/attendance_ui.dart';
import 'supervisor_help.dart';

/// «دليل مدير الدورة» — everything the account can tell him, in plain words.
///
///   • what he can find out, one card per question, each with where to find
///     it and a button that takes him there;
///   • what the colours mean;
///   • common questions;
///   • a short explanation of every screen;
///   • replaying the welcome and the introduction.
class SupervisorGuideScreen extends StatelessWidget {
  const SupervisorGuideScreen({
    super.key,
    required this.onGoToTab,
    required this.onReplayWelcome,
    required this.onReplayTour,
  });

  /// Opens a tab of the home screen: 0 الرئيسية · 1 الأساتذة · 2 الجلسة · 3 الطلاب.
  final ValueChanged<int> onGoToTab;
  final VoidCallback onReplayWelcome;
  final VoidCallback onReplayTour;

  static const _abilities = <_Ability>[
    _Ability(
      icon: Icons.groups_rounded,
      color: AttendanceColors.lateArrival,
      title: 'من سجّل حضور حلقته من الأساتذة، ومن تأخّر، ومن لم يسجّل',
      body: 'لكل أستاذ مربعات ملوّنة لآخر أربع جلسات، والأحوج إلى المتابعة في أعلى القائمة.',
      path: ['الأساتذة'],
      tab: 1,
    ),
    _Ability(
      icon: Icons.event_available_rounded,
      color: TaqwaColors.skyBlue,
      title: 'كم طالباً حضر في يوم معيّن من أصل جميع طلاب الدورة',
      body: 'اختر اليوم بالسهمين أو بالضغط على التاريخ؛ وفي أعلى الصفحة عدد الحاضرين من أصل طلاب الدورة.',
      path: ['الجلسة'],
      tab: 2,
    ),
    _Ability(
      icon: Icons.fact_check_rounded,
      color: AttendanceColors.present,
      title: 'من حضر ومن غاب ومن غاب بعذر في كل حلقة',
      body: 'اضغط على أي حلقة في صفحة الجلسة لترى أسماء طلابها وحالة كل واحد منهم.',
      path: ['الجلسة', 'اسم الحلقة'],
      tab: 2,
    ),
    _Ability(
      icon: Icons.phone_in_talk_rounded,
      color: AttendanceColors.absent,
      title: 'من انقطع من الطلاب، ومن يحتاج إلى اتصال',
      body: 'الطلاب مقسّمون: ثابت، متذبذب، منقطع؛ ومن غاب جلستين متتاليتين يظهر في الأعلى.',
      path: ['الطلاب'],
      tab: 3,
    ),
    _Ability(
      icon: Icons.badge_rounded,
      color: TaqwaColors.domeBlue,
      title: 'تفاصيل كل أستاذ، وحضوره هو إلى المسجد',
      body: 'حضور الأستاذ نفسه كما سجّلته الإدارة، وسجل تسجيله للحضور في كل أيام الدوام.',
      path: ['الأساتذة', 'اسم الأستاذ', 'الحضور'],
      tab: 1,
    ),
    _Ability(
      icon: Icons.menu_book_rounded,
      color: Color(0xFF8E44AD),
      title: 'ماذا سمّع طلاب كل حلقة، وتقديرهم، ونقاطهم',
      body: 'يوماً بيوم: السورة، ومن آية إلى آية، وعدد الصفحات، والتقدير، والنقاط، ومن سجّل التسميع.',
      path: ['الأساتذة', 'اسم الأستاذ', 'التسميع'],
      tab: 1,
    ),
    _Ability(
      icon: Icons.stars_rounded,
      color: TaqwaColors.minaretGold,
      title: 'نقاط كل طالب: المكتسبة والمخصومة',
      body: 'مع تصفية الطلاب حسب المدرسة والصف، وترتيبهم بالنقاط أو الحفظ أو الحضور أو الاسم.',
      path: ['الأساتذة', 'اسم الأستاذ', 'الطلاب'],
      tab: 1,
    ),
    _Ability(
      icon: Icons.account_circle_rounded,
      color: TaqwaColors.islamicGreen,
      title: 'الصفحة الكاملة لأي طالب',
      body: 'تقويم حضوره، وكل ما سمّعه في كل الدورات، ونقاطه، وحفظه، والأحاديث النووية التي حفظها.',
      path: ['اضغط على اسم أي طالب'],
    ),
  ];

  static const _questions = <(String, String)>[
    (
      'كيف أعرف من لم يسجّل الحضور في آخر جلسة؟',
      'افتح «الرئيسية»: البطاقة الأولى تذكر الحلقات التي لم تسجّل. أو افتح «الجلسة» لترى قائمة «لم تسجّل».',
    ),
    (
      'كيف أرى حضور يوم معيّن؟',
      'افتح «الجلسة»، ثم اضغط على التاريخ في الأعلى واختر اليوم، أو تنقّل بالسهمين.',
    ),
    (
      'كيف أرى ماذا سمّع طالب معيّن؟',
      'اضغط على اسمه في أي مكان، ثم اختر «التسميع». ستجد الدورة الحالية أولاً ثم الدورات السابقة.',
    ),
    (
      'هل يمكن أن أغيّر شيئاً بالخطأ؟',
      'لا. هذا الحساب للاطلاع فقط، ولا يحتوي على أي زر يضيف أو يحذف أو يعدّل.',
    ),
    (
      'ما معنى «بالنيابة»؟',
      'أن أستاذاً آخر سجّل حضور الحلقة بدلاً من أستاذها (مثلاً في غيابه)، ولا يُحتسب ذلك تقصيراً على أستاذ الحلقة.',
    ),
    (
      'ما الفرق بين اليوم الإلزامي واليوم الاختياري؟',
      'في اليوم الإلزامي يُحسب الحضور والغياب. أما اليوم الاختياري فيُكافأ فيه من حضر، ولا يُحاسَب من غاب.',
    ),
    (
      'كيف أحدّث الأرقام؟',
      'اسحب الصفحة إلى الأسفل ثم اتركها، فتُحمَّل البيانات من جديد.',
    ),
    (
      'ما معنى «عزل»؟',
      'حلقة يُجمَّع فيها الطلاب المتوقفون مؤقتاً، ولا تدخل في الإحصائيات.',
    ),
  ];

  static const _screens = <HelpTopic>[
    HelpTopic.overview,
    HelpTopic.instructors,
    HelpTopic.day,
    HelpTopic.students,
    HelpTopic.instructorPage,
    HelpTopic.studentPage,
  ];

  void _goTo(BuildContext context, int tab) {
    Navigator.of(context).pop();
    onGoToTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TaqwaColors.background,
        appBar: AppBar(
          title: const Text('دليل مدير الدورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const _Intro(),
            const _Heading(icon: Icons.lightbulb_rounded, text: 'ماذا يمكنك أن تعرف من هذا الحساب؟'),
            for (var i = 0; i < _abilities.length; i++)
              _AbilityCard(
                number: i + 1,
                ability: _abilities[i],
                onGo: _abilities[i].tab == null ? null : () => _goTo(context, _abilities[i].tab!),
              ),
            const _Heading(icon: Icons.palette_rounded, text: 'معاني الألوان'),
            const Text(
              'مربعات تسجيل الأساتذة:',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AttendanceColors.ink),
            ),
            const SizedBox(height: 6),
            const ExplainedDisciplineLegend(),
            const SizedBox(height: 12),
            const Text(
              'حالات الطلاب:',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AttendanceColors.ink),
            ),
            const SizedBox(height: 6),
            const _StudentStatusLegend(),
            const _Heading(icon: Icons.question_answer_rounded, text: 'أسئلة شائعة'),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _questions.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    _Question(question: _questions[i].$1, answer: _questions[i].$2),
                  ],
                ],
              ),
            ),
            const _Heading(icon: Icons.web_stories_rounded, text: 'شرح كل صفحة'),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _screens.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 64),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: TaqwaColors.lightBlue,
                        child: Icon(kSupervisorHelp[_screens[i]]!.icon, color: TaqwaColors.domeBlue, size: 20),
                      ),
                      title: Text(
                        kSupervisorHelp[_screens[i]]!.title,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showSupervisorHelp(context, _screens[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onReplayWelcome();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('إعادة عرض الترحيب', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.5)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onReplayTour();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.slideshow_rounded),
              label: const Text('إعادة الجولة التعريفية', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ability {
  const _Ability({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.path,
    this.tab,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  /// Where to find it, step by step.
  final List<String> path;

  /// The home tab that leads there; null when it is reached from anywhere.
  final int? tab;
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [TaqwaColors.domeBlue, Color(0xFF0D2F45)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_stories_rounded, color: TaqwaColors.minaretGold, size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كل ما يمكنك معرفته من هذا الحساب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 6),
                Text(
                  'هذا الحساب للاطلاع فقط: ترى فيه كل ما يجري في الدورة، ولا يتغيّر شيء مهما ضغطت. '
                  'تحت كل بند ستجد أين تجده، وزراً يأخذك إليه.',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.8, color: Color(0xDDFFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TaqwaColors.minaretGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AttendanceColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.number, required this.ability, this.onGo});

  final int number;
  final _Ability ability;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: BorderDirectional(start: BorderSide(color: ability.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: ability.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(ability.icon, color: ability.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$number. ${ability.title}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    height: 1.6,
                    color: AttendanceColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ability.body,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.8, color: Color(0xFF4A5A6A)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Text('أين تجده:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600)),
                    for (var i = 0; i < ability.path.length; i++) ...[
                      if (i > 0) Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade500),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: TaqwaColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ability.path[i],
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: TaqwaColors.domeBlue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onGo != null)
                TextButton.icon(
                  onPressed: onGo,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('اذهب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentStatusLegend extends StatelessWidget {
  const _StudentStatusLegend();

  static const _rows = <(Color, String, String)>[
    (AttendanceColors.present, 'حاضر', 'حضر الجلسة في وقتها'),
    (AttendanceColors.lateArrival, 'متأخر', 'حضر متأخراً، ويُحسب حاضراً'),
    (AttendanceColors.absent, 'غائب', 'لم يحضر'),
    (AttendanceColors.excused, 'بعذر', 'غاب بعذر: لا يُخصم منه، ولا يُحسب عليه غياباً'),
    (AttendanceColors.unmarked, 'لم يُسجَّل', 'لم يسجّل الأستاذ حالته بعد'),
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
        children: [
          for (final (color, label, meaning) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
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

class _Question extends StatelessWidget {
  const _Question({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: const Icon(Icons.help_outline_rounded, color: TaqwaColors.skyBlue),
        title: Text(
          question,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600, color: AttendanceColors.ink),
        ),
        children: [
          Text(answer, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, height: 1.8, color: Color(0xFF4A5A6A))),
        ],
      ),
    );
  }
}
