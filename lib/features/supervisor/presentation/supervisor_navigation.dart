import 'package:flutter/material.dart';
import '../../instructor_home/presentation/screens/instructor_student_detail_screen.dart';
import 'help/supervisor_help.dart';

/// Opens a student's page exactly as his أستاذ sees it — information,
/// attendance calendar, recitation history with ratings, points, memorisation,
/// the Nawawi map — with nothing to add or change.
///
/// [tab]: [InstructorStudentDetailScreen.attendanceTab],
/// [InstructorStudentDetailScreen.recitationTab], or 0 for his information.
void openStudentPage(
  BuildContext context, {
  required String studentId,
  required String name,
  int tab = 0,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => InstructorStudentDetailScreen(
        studentId: studentId,
        studentName: name,
        initialTab: tab,
        readOnly: true,
        onHelp: () => showSupervisorHelp(context, HelpTopic.studentPage),
      ),
    ),
  );
}

/// «جيد جداً» · «جيد» · «إعادة» · «لم يحفظ» · «مقرأة», with its colour.
({String label, Color color})? ratingLook(String? rating) {
  switch (rating) {
    case 'VERY_GOOD':
      return (label: 'جيد جداً', color: const Color(0xFF1E8449));
    case 'GOOD':
      return (label: 'جيد', color: const Color(0xFF2E86C1));
    case 'REPEAT':
      return (label: 'إعادة', color: const Color(0xFFD4AC0D));
    case 'DID_NOT_MEMORIZE':
      return (label: 'لم يحفظ', color: const Color(0xFFE74C3C));
    case 'MAQRAA':
      return (label: 'مقرأة', color: const Color(0xFFD4AC0D));
  }
  return null;
}

/// 12.5 → «12.5» · 3.0 → «3».
String numAr(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}
