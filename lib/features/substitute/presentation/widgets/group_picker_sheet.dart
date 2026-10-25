import 'package:flutter/material.dart';

import '../substitute_ui.dart';

/// One student in the «طلابي اليوم» picker.
@immutable
class PickableStudent {
  const PickableStudent({required this.id, required this.name});

  final String id;
  final String name;
}

/// «من معك من طلاب أ. فلان اليوم؟» — the substitute ticks the students
/// sitting with him.
///
/// Returns the chosen ids; an empty set means «الحلقة كاملة»; null means
/// the sheet was dismissed and nothing changes.
Future<Set<String>?> showSubstituteGroupPicker(
  BuildContext context, {
  required String instructorName,
  required List<PickableStudent> students,
  Set<String>? initial,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupPicker(
      instructorName: instructorName,
      students: students,
      initial: initial ?? const {},
    ),
  );
}

class _GroupPicker extends StatefulWidget {
  const _GroupPicker({
    required this.instructorName,
    required this.students,
    required this.initial,
  });

  final String instructorName;
  final List<PickableStudent> students;
  final Set<String> initial;

  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  late final Set<String> _chosen = {...widget.initial};
  String _query = '';

  List<PickableStudent> get _visible {
    final q = normalizeArabicName(_query);
    if (q.isEmpty) return widget.students;
    return widget.students
        .where((s) => normalizeArabicName(s.name).contains(q))
        .toList(growable: false);
  }

  void _toggleAllVisible(bool select) {
    setState(() {
      for (final s in _visible) {
        select ? _chosen.add(s.id) : _chosen.remove(s.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final allVisibleChosen =
        visible.isNotEmpty && visible.every((s) => _chosen.contains(s.id));
    final total = widget.students.length;
    // Choosing every student is the same as «الحلقة كاملة».
    final everyone = _chosen.length == total;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: SubstituteColors.claimedFill,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.groups_2_rounded,
                          size: 22, color: SubstituteColors.header),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'من معك من طلاب أ. ${widget.instructorName} اليوم؟',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: SubstituteColors.header,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            'علِّم الطلاب الجالسين عندك؛ فتعمل أزرار الحضور السريعة '
                            'عليهم وحدهم. يُحفظ على هذا الهاتف لهذا اليوم فقط.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الطالب',
                    hintStyle: TextStyle(
                        fontFamily: 'Cairo', color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: SubstituteColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: visible.isEmpty
                          ? null
                          : () => _toggleAllVisible(!allVisibleChosen),
                      style: TextButton.styleFrom(
                          foregroundColor: SubstituteColors.header),
                      icon: Icon(
                        allVisibleChosen
                            ? Icons.remove_done_rounded
                            : Icons.done_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        allVisibleChosen ? 'إلغاء تحديد الظاهرين' : 'تحديد الظاهرين',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'المحدَّد: ${_chosen.length} من $total',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد طالب بهذا الاسم',
                          style: TextStyle(
                              fontFamily: 'Cairo', color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: visible.length,
                        itemBuilder: (_, i) {
                          final s = visible[i];
                          final on = _chosen.contains(s.id);
                          return CheckboxListTile(
                            value: on,
                            onChanged: (v) => setState(() =>
                                v == true ? _chosen.add(s.id) : _chosen.remove(s.id)),
                            activeColor: SubstituteColors.accent,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            title: Text(
                              s.name,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14.5,
                                fontWeight: on ? FontWeight.bold : FontWeight.w500,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, <String>{}),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SubstituteColors.header,
                          side: BorderSide(
                              color: SubstituteColors.accent.withValues(alpha: 0.45)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'الحلقة كاملة معي',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _chosen.isEmpty
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  everyone ? <String>{} : {..._chosen},
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: SubstituteColors.header,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _chosen.isEmpty ? 'اختر طالباً على الأقل' : 'حفظ (${_chosen.length})',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alef forms, taa marbuta and alef maqsura folded, so «احمد» finds «أحمد».
String normalizeArabicName(String s) => s
    .trim()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp('[ً-ْـ]'), '');
