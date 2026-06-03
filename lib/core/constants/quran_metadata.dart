// ═══════════════════════════════════════════════════════════════
// Quran Metadata Constants — Flutter
// Mirrors backend/src/quran-metadata/quran-metadata.ts
// Page counts use fractional values from the standard Madani Mushaf
// (604 pages), so short surahs in Juz 30 are represented accurately.
// ═══════════════════════════════════════════════════════════════

const int totalQuranPages = 604;
const int totalSuras = 114;
const int totalJuz = 30;

class SuraInfo {
  final int number;
  final String nameAr;
  final int startPage;
  final int endPage;
  final double totalPages;
  final int juzStart;

  const SuraInfo({
    required this.number,
    required this.nameAr,
    required this.startPage,
    required this.endPage,
    required this.totalPages,
    required this.juzStart,
  });
}

/// All 114 suras with page information from the Madani Mushaf.
/// Long suras keep integer values; short suras in Juz 30 use
/// fractional values that sum to their real shared pages.
const List<SuraInfo> suraList = [
  SuraInfo(number: 1,   nameAr: 'الفاتحة',     startPage: 1,   endPage: 1,   totalPages: 1,    juzStart: 1),
  SuraInfo(number: 2,   nameAr: 'البقرة',       startPage: 2,   endPage: 49,  totalPages: 48,   juzStart: 1),
  SuraInfo(number: 3,   nameAr: 'آل عمران',     startPage: 50,  endPage: 76,  totalPages: 27,   juzStart: 3),
  SuraInfo(number: 4,   nameAr: 'النساء',       startPage: 77,  endPage: 106, totalPages: 30,   juzStart: 4),
  SuraInfo(number: 5,   nameAr: 'المائدة',      startPage: 106, endPage: 127, totalPages: 22,   juzStart: 6),
  SuraInfo(number: 6,   nameAr: 'الأنعام',      startPage: 128, endPage: 150, totalPages: 23,   juzStart: 7),
  SuraInfo(number: 7,   nameAr: 'الأعراف',      startPage: 151, endPage: 176, totalPages: 26,   juzStart: 8),
  SuraInfo(number: 8,   nameAr: 'الأنفال',      startPage: 177, endPage: 186, totalPages: 10,   juzStart: 9),
  SuraInfo(number: 9,   nameAr: 'التوبة',       startPage: 187, endPage: 207, totalPages: 21,   juzStart: 10),
  SuraInfo(number: 10,  nameAr: 'يونس',         startPage: 208, endPage: 221, totalPages: 14,   juzStart: 11),
  SuraInfo(number: 11,  nameAr: 'هود',          startPage: 221, endPage: 235, totalPages: 15,   juzStart: 11),
  SuraInfo(number: 12,  nameAr: 'يوسف',         startPage: 235, endPage: 248, totalPages: 14,   juzStart: 12),
  SuraInfo(number: 13,  nameAr: 'الرعد',        startPage: 249, endPage: 255, totalPages: 7,    juzStart: 13),
  SuraInfo(number: 14,  nameAr: 'إبراهيم',      startPage: 255, endPage: 261, totalPages: 7,    juzStart: 13),
  SuraInfo(number: 15,  nameAr: 'الحجر',        startPage: 262, endPage: 267, totalPages: 6,    juzStart: 14),
  SuraInfo(number: 16,  nameAr: 'النحل',        startPage: 267, endPage: 281, totalPages: 15,   juzStart: 14),
  SuraInfo(number: 17,  nameAr: 'الإسراء',      startPage: 282, endPage: 293, totalPages: 12,   juzStart: 15),
  SuraInfo(number: 18,  nameAr: 'الكهف',        startPage: 293, endPage: 304, totalPages: 12,   juzStart: 15),
  SuraInfo(number: 19,  nameAr: 'مريم',         startPage: 305, endPage: 312, totalPages: 8,    juzStart: 16),
  SuraInfo(number: 20,  nameAr: 'طه',           startPage: 312, endPage: 321, totalPages: 10,   juzStart: 16),
  SuraInfo(number: 21,  nameAr: 'الأنبياء',     startPage: 322, endPage: 331, totalPages: 10,   juzStart: 17),
  SuraInfo(number: 22,  nameAr: 'الحج',         startPage: 332, endPage: 341, totalPages: 10,   juzStart: 17),
  SuraInfo(number: 23,  nameAr: 'المؤمنون',     startPage: 342, endPage: 349, totalPages: 8,    juzStart: 18),
  SuraInfo(number: 24,  nameAr: 'النور',        startPage: 350, endPage: 359, totalPages: 10,   juzStart: 18),
  SuraInfo(number: 25,  nameAr: 'الفرقان',      startPage: 359, endPage: 366, totalPages: 8,    juzStart: 18),
  SuraInfo(number: 26,  nameAr: 'الشعراء',      startPage: 367, endPage: 376, totalPages: 10,   juzStart: 19),
  SuraInfo(number: 27,  nameAr: 'النمل',        startPage: 377, endPage: 385, totalPages: 9,    juzStart: 19),
  SuraInfo(number: 28,  nameAr: 'القصص',        startPage: 385, endPage: 396, totalPages: 12,   juzStart: 20),
  SuraInfo(number: 29,  nameAr: 'العنكبوت',     startPage: 396, endPage: 404, totalPages: 9,    juzStart: 20),
  SuraInfo(number: 30,  nameAr: 'الروم',        startPage: 404, endPage: 410, totalPages: 7,    juzStart: 21),
  SuraInfo(number: 31,  nameAr: 'لقمان',        startPage: 411, endPage: 414, totalPages: 4,    juzStart: 21),
  SuraInfo(number: 32,  nameAr: 'السجدة',       startPage: 415, endPage: 417, totalPages: 3,    juzStart: 21),
  SuraInfo(number: 33,  nameAr: 'الأحزاب',      startPage: 418, endPage: 427, totalPages: 10,   juzStart: 21),
  SuraInfo(number: 34,  nameAr: 'سبأ',          startPage: 428, endPage: 434, totalPages: 7,    juzStart: 22),
  SuraInfo(number: 35,  nameAr: 'فاطر',         startPage: 434, endPage: 440, totalPages: 7,    juzStart: 22),
  SuraInfo(number: 36,  nameAr: 'يس',           startPage: 440, endPage: 445, totalPages: 6,    juzStart: 22),
  SuraInfo(number: 37,  nameAr: 'الصافات',      startPage: 446, endPage: 452, totalPages: 7,    juzStart: 23),
  SuraInfo(number: 38,  nameAr: 'ص',            startPage: 453, endPage: 458, totalPages: 6,    juzStart: 23),
  SuraInfo(number: 39,  nameAr: 'الزمر',        startPage: 458, endPage: 467, totalPages: 10,   juzStart: 23),
  SuraInfo(number: 40,  nameAr: 'غافر',         startPage: 467, endPage: 476, totalPages: 10,   juzStart: 24),
  SuraInfo(number: 41,  nameAr: 'فصلت',         startPage: 477, endPage: 482, totalPages: 6,    juzStart: 24),
  SuraInfo(number: 42,  nameAr: 'الشورى',       startPage: 483, endPage: 489, totalPages: 7,    juzStart: 25),
  SuraInfo(number: 43,  nameAr: 'الزخرف',       startPage: 489, endPage: 495, totalPages: 7,    juzStart: 25),
  SuraInfo(number: 44,  nameAr: 'الدخان',       startPage: 496, endPage: 498, totalPages: 3,    juzStart: 25),
  SuraInfo(number: 45,  nameAr: 'الجاثية',      startPage: 499, endPage: 502, totalPages: 4,    juzStart: 25),
  SuraInfo(number: 46,  nameAr: 'الأحقاف',      startPage: 502, endPage: 506, totalPages: 5,    juzStart: 26),
  SuraInfo(number: 47,  nameAr: 'محمد',         startPage: 507, endPage: 510, totalPages: 4,    juzStart: 26),
  SuraInfo(number: 48,  nameAr: 'الفتح',        startPage: 511, endPage: 515, totalPages: 5,    juzStart: 26),
  SuraInfo(number: 49,  nameAr: 'الحجرات',      startPage: 515, endPage: 517, totalPages: 3,    juzStart: 26),
  SuraInfo(number: 50,  nameAr: 'ق',            startPage: 518, endPage: 520, totalPages: 3,    juzStart: 26),
  SuraInfo(number: 51,  nameAr: 'الذاريات',     startPage: 520, endPage: 523, totalPages: 4,    juzStart: 26),
  SuraInfo(number: 52,  nameAr: 'الطور',        startPage: 523, endPage: 525, totalPages: 3,    juzStart: 27),
  SuraInfo(number: 53,  nameAr: 'النجم',        startPage: 526, endPage: 528, totalPages: 3,    juzStart: 27),
  SuraInfo(number: 54,  nameAr: 'القمر',        startPage: 528, endPage: 531, totalPages: 4,    juzStart: 27),
  SuraInfo(number: 55,  nameAr: 'الرحمن',       startPage: 531, endPage: 534, totalPages: 4,    juzStart: 27),
  SuraInfo(number: 56,  nameAr: 'الواقعة',      startPage: 534, endPage: 537, totalPages: 4,    juzStart: 27),
  SuraInfo(number: 57,  nameAr: 'الحديد',       startPage: 537, endPage: 541, totalPages: 5,    juzStart: 27),
  SuraInfo(number: 58,  nameAr: 'المجادلة',     startPage: 542, endPage: 545, totalPages: 4,    juzStart: 28),
  SuraInfo(number: 59,  nameAr: 'الحشر',        startPage: 545, endPage: 548, totalPages: 4,    juzStart: 28),
  SuraInfo(number: 60,  nameAr: 'الممتحنة',     startPage: 549, endPage: 551, totalPages: 3,    juzStart: 28),
  SuraInfo(number: 61,  nameAr: 'الصف',         startPage: 551, endPage: 552, totalPages: 2,    juzStart: 28),
  SuraInfo(number: 62,  nameAr: 'الجمعة',       startPage: 553, endPage: 554, totalPages: 2,    juzStart: 28),
  SuraInfo(number: 63,  nameAr: 'المنافقون',    startPage: 554, endPage: 555, totalPages: 2,    juzStart: 28),
  SuraInfo(number: 64,  nameAr: 'التغابن',      startPage: 556, endPage: 557, totalPages: 2,    juzStart: 28),
  SuraInfo(number: 65,  nameAr: 'الطلاق',       startPage: 558, endPage: 559, totalPages: 2,    juzStart: 28),
  SuraInfo(number: 66,  nameAr: 'التحريم',      startPage: 560, endPage: 561, totalPages: 2,    juzStart: 28),
  SuraInfo(number: 67,  nameAr: 'الملك',        startPage: 562, endPage: 564, totalPages: 3,    juzStart: 29),
  SuraInfo(number: 68,  nameAr: 'القلم',        startPage: 564, endPage: 566, totalPages: 3,    juzStart: 29),
  SuraInfo(number: 69,  nameAr: 'الحاقة',       startPage: 566, endPage: 568, totalPages: 3,    juzStart: 29),
  SuraInfo(number: 70,  nameAr: 'المعارج',      startPage: 568, endPage: 570, totalPages: 3,    juzStart: 29),
  SuraInfo(number: 71,  nameAr: 'نوح',          startPage: 570, endPage: 571, totalPages: 2,    juzStart: 29),
  SuraInfo(number: 72,  nameAr: 'الجن',         startPage: 572, endPage: 573, totalPages: 2,    juzStart: 29),
  SuraInfo(number: 73,  nameAr: 'المزمل',       startPage: 574, endPage: 575, totalPages: 2,    juzStart: 29),
  SuraInfo(number: 74,  nameAr: 'المدثر',       startPage: 575, endPage: 577, totalPages: 3,    juzStart: 29),
  SuraInfo(number: 75,  nameAr: 'القيامة',      startPage: 577, endPage: 578, totalPages: 2,    juzStart: 29),
  SuraInfo(number: 76,  nameAr: 'الإنسان',      startPage: 578, endPage: 580, totalPages: 3,    juzStart: 29),
  SuraInfo(number: 77,  nameAr: 'المرسلات',     startPage: 580, endPage: 581, totalPages: 2,    juzStart: 29),

  // ─── Juz 30 — accurate fractional page counts ───
  SuraInfo(number: 78,  nameAr: 'النبأ',        startPage: 582, endPage: 583, totalPages: 2,    juzStart: 30),
  SuraInfo(number: 79,  nameAr: 'النازعات',     startPage: 583, endPage: 584, totalPages: 1.5,  juzStart: 30),
  SuraInfo(number: 80,  nameAr: 'عبس',          startPage: 585, endPage: 585, totalPages: 1,    juzStart: 30),
  SuraInfo(number: 81,  nameAr: 'التكوير',      startPage: 586, endPage: 586, totalPages: 1,    juzStart: 30),
  SuraInfo(number: 82,  nameAr: 'الانفطار',     startPage: 587, endPage: 587, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 83,  nameAr: 'المطففين',     startPage: 587, endPage: 589, totalPages: 2,    juzStart: 30),
  SuraInfo(number: 84,  nameAr: 'الانشقاق',     startPage: 589, endPage: 589, totalPages: 0.75, juzStart: 30),
  SuraInfo(number: 85,  nameAr: 'البروج',       startPage: 590, endPage: 590, totalPages: 0.75, juzStart: 30),
  SuraInfo(number: 86,  nameAr: 'الطارق',       startPage: 591, endPage: 591, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 87,  nameAr: 'الأعلى',       startPage: 591, endPage: 592, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 88,  nameAr: 'الغاشية',      startPage: 592, endPage: 592, totalPages: 0.75, juzStart: 30),
  SuraInfo(number: 89,  nameAr: 'الفجر',        startPage: 593, endPage: 594, totalPages: 1.5,  juzStart: 30),
  SuraInfo(number: 90,  nameAr: 'البلد',        startPage: 594, endPage: 594, totalPages: 0.75, juzStart: 30),
  SuraInfo(number: 91,  nameAr: 'الشمس',        startPage: 595, endPage: 595, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 92,  nameAr: 'الليل',        startPage: 595, endPage: 596, totalPages: 0.75, juzStart: 30),
  SuraInfo(number: 93,  nameAr: 'الضحى',        startPage: 596, endPage: 596, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 94,  nameAr: 'الشرح',        startPage: 596, endPage: 596, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 95,  nameAr: 'التين',        startPage: 597, endPage: 597, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 96,  nameAr: 'العلق',        startPage: 597, endPage: 597, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 97,  nameAr: 'القدر',        startPage: 598, endPage: 598, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 98,  nameAr: 'البينة',       startPage: 598, endPage: 599, totalPages: 1,    juzStart: 30),
  SuraInfo(number: 99,  nameAr: 'الزلزلة',      startPage: 599, endPage: 599, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 100, nameAr: 'العاديات',     startPage: 599, endPage: 600, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 101, nameAr: 'القارعة',      startPage: 600, endPage: 600, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 102, nameAr: 'التكاثر',      startPage: 600, endPage: 600, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 103, nameAr: 'العصر',        startPage: 601, endPage: 601, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 104, nameAr: 'الهمزة',       startPage: 601, endPage: 601, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 105, nameAr: 'الفيل',        startPage: 601, endPage: 601, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 106, nameAr: 'قريش',         startPage: 602, endPage: 602, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 107, nameAr: 'الماعون',      startPage: 602, endPage: 602, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 108, nameAr: 'الكوثر',       startPage: 602, endPage: 602, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 109, nameAr: 'الكافرون',     startPage: 603, endPage: 603, totalPages: 0.5,  juzStart: 30),
  SuraInfo(number: 110, nameAr: 'النصر',        startPage: 603, endPage: 603, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 111, nameAr: 'المسد',        startPage: 603, endPage: 603, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 112, nameAr: 'الإخلاص',      startPage: 604, endPage: 604, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 113, nameAr: 'الفلق',        startPage: 604, endPage: 604, totalPages: 0.25, juzStart: 30),
  SuraInfo(number: 114, nameAr: 'الناس',        startPage: 604, endPage: 604, totalPages: 0.5,  juzStart: 30),
];

/// Get sura info by number (1-indexed)
SuraInfo? getSuraByNumber(int number) {
  if (number < 1 || number > 114) return null;
  return suraList[number - 1];
}

/// Get sura Arabic name by number
String getSuraName(int number) {
  final sura = getSuraByNumber(number);
  return sura?.nameAr ?? 'سورة $number';
}