# نظام الدورات + التسميع بنطاق الآيات

> تاريخ التنفيذ: 2026-09-05
> النطاق: `backend/` (NestJS + Prisma + PostgreSQL) و `lib/` (Flutter)

---

## 1. لماذا هذا التعديل

### أ) النقاط كانت تراكمية عبر الزمن
جدول `terms` وأعمدة `term_id` كانت موجودة منذ 2026-06، لكن:
- لا يوجد أي واجهة لاختيار الدورة أو إدارتها.
- مسارات `points/leaderboard`، `points/student/:id`، `recitations/overview`،
  `recitations/student/:id/history` لم تكن تقبل `termId` إطلاقاً.
- صفوف قديمة بقيت بـ `term_id = NULL` (orphaned).
- لا شيء يمنع نقل صف من دورة إلى أخرى.

### ب) «سورة كاملة» كانت تعطي نقاطاً أعلى
مساران مختلفان لقياس نفس المحتوى:

| الطريقة | مصدر عدد الصفحات |
|---|---|
| سورة كاملة | جدول `SURA_METADATA` المنسوخ يدوياً (مجموعه ≈ 639.75 صفحة) |
| نطاق آيات | خريطة صفحات المصحف الحقيقية `quran_ayat_pages.json` (604 صفحة) |

نتيجة التدقيق في `fullsura-impact.csv`: التسميعات المسجّلة كسورة كاملة أعطت
نقاطاً **أعلى بنسبة 40–75%** من الحساب الدقيق لنفس المحتوى. طالبان حفظا نفس
الآيات كانا يحصلان على نقاط مختلفة حسب الزر الذي ضغطه معلّمهما.

---

## 2. القرارات المتفق عليها

| القرار | الاختيار |
|---|---|
| النقاط التاريخية | **لا تُمَس إطلاقاً.** لا إعادة حساب، لا حذف. الدورة الجديدة تبدأ من 0. |
| اختيار الدورة | selector عام في التطبيق + شاشة «إدارة الدورات» للأدمن |
| المقرأة | **لا نقاط إطلاقاً** — مجرد إعلام لأولياء الأمور بأن جلسة قراءة جماعية جرت |

---

## 3. ما الذي تغيّر

### قاعدة البيانات
`prisma/migrations/20260905000000_course_isolation_and_verse_range/`

| # | التغيير | الأثر |
|---|---|---|
| 1 | جدول `term_backfill_audit` | يسجّل كل قيمة قبل تعديلها → التراجع ممكن بأمر واحد |
| 2 | Backfill لـ `term_id` الفارغ | الصفوف اليتيمة تُنسب لدورتها حسب التاريخ. صفوف النقاط الناتجة عن تسميع ترث دورة التسميع نفسه |
| 3 | Trigger `freeze_term_id` | **تغيير دورة صف موجود مرفوض على مستوى قاعدة البيانات** |
| 4 | `*_term_required_chk` (NOT VALID) | كل صف جديد يجب أن يحمل دورة |
| 5 | `recitations_verse_range_chk` (NOT VALID) | كل تسميع جديد (عدا المقرأة) يجب أن يحمل نطاق آيات صالح |
| 6 | فهارس `(term_id, student_id)` | تسريع تجميعات المتصدرين لكل دورة |

**الصفوف القديمة محمية بطريقتين:** القيود `NOT VALID` لا تُفحص عند الإضافة،
وشرط `created_at < 2026-09-05` يجعلها معفاة حتى عند التعديل لاحقاً.

**لا شيء يُحذف. لا مبلغ نقاط واحد يتغيّر.**

### الخادم (NestJS)

| الملف | التغيير |
|---|---|
| `terms/terms.service.ts` | `requireActiveTermId()` — رسالة عربية واضحة بدل خطأ قيد. `findAll()` صار يرجع عدّادات كل دورة |
| `points/points.controller.ts` | `?termId=` على `student/:id`، `student/:id/rank`، `leaderboard` |
| `points/points.service.ts` | ختم `termId` صراحةً عند كتابة النقاط اليدوية + إرجاع `termId` مع كل نتيجة |
| `recitation/recitation.controller.ts` | `?termId=` على `overview` و `student/:id/history` |
| `recitation/recitation.service.ts` | إزالة مسار `FULL_SURA` بالكامل · `applyRangePoints` هو المسار الوحيد للنقاط · المقرأة بلا نقاط · ختم `termId` على كل كتابة |
| `attendance/attendance.service.ts` | ختم `termId` على نقاط الحضور |
| `quran-metadata/quran-ayat-pages.util.ts` | `getVerseCount()` — التعريف الوحيد لعدد الآيات · رسائل `validateRange` صارت تذكر عدد آيات السورة |
| `recitation/dto/create-recitation.dto.ts` | تشديد التحقق + توثيق سبب إبقاء `FULL_SURA` في الـ enum |

**دلالة `termId` في كل المسارات:**

```
غائب  → الدورة المفعّلة (سلوك التطبيقات القديمة، بدون أي تغيير)
0     → كل الدورات (عرض الأرشيف الكامل للأدمن)
> 0   → تلك الدورة تحديداً
```

### التطبيق (Flutter)

**ملفات جديدة** — `lib/features/terms/`:
- `data/term_model.dart` · `data/terms_api.dart`
- `presentation/providers/term_provider.dart`
- `presentation/widgets/term_selector.dart`
- `presentation/screens/admin_terms_screen.dart`

**ملفات معدّلة:** `main.dart` · شاشة التسميع · المقرأة · لوحة المعلم ·
تفاصيل الطالب (معلم/أدمن) · المتصدرين (عادي/أدمن) · الطلاب حسب المعلم ·
الصفحة الرئيسية للأدمن · `points_api.dart` · `recitation_api.dart`

---

## 4. تفاصيل مهمة في التصميم

**«الدورة المعروضة» ≠ «الدورة المفعّلة».**
- المعروضة: ما ينظر إليه المستخدم الآن. تُعاد للمفعّلة عند كل تشغيل للتطبيق —
  اختيار يبقى بعد إعادة التشغيل يعني أن أحدهم قد يفتح التطبيق بعد أيام ويقرأ
  أرقام دورة منتهية على أنها الحالية.
- المفعّلة: يحدّدها الأدمن على الخادم. **كل** ما يُكتب يذهب إليها.
- شاشة التسميع تعرض **المفعّلة دائماً** في بانر أخضر أعلى النموذج، حتى لو كان
  المعلّم يتصفّح دورة قديمة في شاشة أخرى.

**ما هو تراكمي عبر الدورات عن قصد** (لأن الحفظ لا يُنسى بانتهاء الدورة):
- خريطة حفظ القرآن (`/recitations/student/:id/progress`)
- خريطة الأربعين النووية (`/recitations/student/:id/hadith-progress`)
- اقتراح الآية التالية (`next-suggestion`)
- عدد الصفحات المسمّعة في فلاتر الأدمن

**ما هو مقيّد بالدورة:** النقاط، الترتيب، المتصدرين، سجل النقاط، سجل التسميع.

**التطبيقات القديمة (100+ مستخدم):** طلب بصيغة «سورة كاملة» يُرفض برسالة عربية
صريحة تطلب تحديث التطبيق — لا فشل صامت ولا تسجيل غير عادل.

---

## 5. خطوات النشر

```bash
# 1. الخادم — الـ migration تُطبَّق تلقائياً عند الإقلاع
#    (Dockerfile: npx prisma migrate deploy && ... && node dist/main.js)
git add . && git commit -m "feat: course isolation + verse-range-only recitation"
git push          # Railway يبني وينشر

# 2. التحقق بعد النشر
#    - يجب أن تكون النتيجة 0 في الاستعلامات الثلاثة:
#      SELECT count(*) FROM recitations        WHERE term_id IS NULL;
#      SELECT count(*) FROM points_log         WHERE term_id IS NULL;
#      SELECT count(*) FROM hadith_recitations WHERE term_id IS NULL;
#    - عدد صفوف السجل: SELECT count(*) FROM term_backfill_audit;

# 3. التطبيق
cd D:\taqwa-app\taqwa_mobile
flutter pub get
flutter analyze
flutter build appbundle --release
```

### التراجع عن الـ backfill (إن لزم)

```sql
UPDATE recitations r SET term_id = NULL
FROM term_backfill_audit a
WHERE a.migration = 'course_isolation_and_verse_range'
  AND a.table_name = 'recitations' AND a.column_name = 'term_id'
  AND a.row_id = r.id;
-- كرّر لـ points_log و hadith_recitations
-- ملاحظة: عطّل trigger freeze_term_id مؤقتاً إذا لزم
```

---

## 6. الاختبارات

`npx jest` داخل `backend/` — 42 اختباراً:

| الملف | التغطية |
|---|---|
| `quran-metadata/quran-ayat-pages.util.spec.ts` (19) | `verseCount = end - start + 1` بلا تقريب · حدود كل سورة من 114 · تطابق النقاط بين طالبين · اطّراد القياس · إثبات اختلاف الجدول القديم عن الخريطة الدقيقة |
| `recitation/recitation.service.spec.ts` (13) | رفض `FULL_SURA` برسالة التحديث · عدم كتابة أي صف عند الرفض · ختم الدورة على التسميع ونقاطه معاً · رفض التسجيل بلا دورة مفعّلة · المقرأة بلا نقاط |
| `points/course-isolation.spec.ts` (10) | دورة جديدة = 0 لكل طالب دون حذف أحد · الدورة السابقة تبقى كما هي · الترتيب داخل دورة واحدة · `termId=0` للأرشيف |

الـ migration جُرّبت على PostgreSQL 16 حقيقي: تشغيلان متتاليان (idempotent)،
ببيانات قديمة تحاكي الإنتاج، و10 فحوصات للقيود (رفض/قبول).

---

## 7. ملاحظات متبقية

1. **`recitations` ليس لها ملف migration في المستودع** — أُنشئ الجدول مباشرة على
   الإنتاج، لذا `prisma migrate deploy` على قاعدة بيانات فارغة تماماً سيفشل عند
   `20260608000000_add_terms_chapter`. الإنتاج غير متأثر.
2. **`sura_multi_select_picker.dart` صار بلا مستخدمين** — يمكن حذفه.
3. **ملفات `*.spec.ts` الأربعة الأصلية** (`points.service`, `attendance.service`,
   `students.service`, `instructors.service`) كانت فاشلة **قبل** هذا التعديل:
   هي هياكل Nest CLI تحقن الخدمة بدون تبعياتها.
4. **الطلاب لا يرون selector** — `GET /terms` مقيّد بـ ADMIN/INSTRUCTOR، والطالب
   يرى الدورة المفعّلة دائماً، وهو السلوك الصحيح.
5. **نسخ احتياطية** من كل ملف عُدّل محفوظة بامتداد `.pre-course-edit.bak`.
