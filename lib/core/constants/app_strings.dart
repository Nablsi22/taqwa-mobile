class AppStrings {
  AppStrings._();

  // عام
  static const String appName = 'التقوى';
  static const String mosqueFullName = 'جامع التقوى';

  // تسجيل الدخول
  static const String welcomeBack = 'مرحباً بك';
  static const String loginSubtitle = 'سجّل دخولك للمتابعة';
  static const String username = 'اسم المستخدم';
  static const String password = 'كلمة المرور';
  static const String login = 'تسجيل الدخول';
  static const String usernameRequired = 'الرجاء إدخال اسم المستخدم';
  static const String passwordRequired = 'الرجاء إدخال كلمة المرور';
  static const String loginFailed = 'فشل تسجيل الدخول';
  static const String invalidCredentials = 'اسم المستخدم أو كلمة المرور غير صحيحة';
  static const String loggingIn = 'جاري تسجيل الدخول...';

  // أخطاء الشبكة
  static const String connectionTimeout = 'انتهت مهلة الاتصال. تحقق من اتصالك بالإنترنت';
  static const String cannotReachServer = 'لا يمكن الاتصال بالخادم. تأكد من تشغيل الخادم';
  static const String accessDenied = 'ليس لديك صلاحية للوصول';
  static const String tooManyAttempts = 'محاولات كثيرة. حاول مرة أخرى لاحقاً';
  static const String serverError = 'حدث خطأ في الخادم';
  static const String unexpectedError = 'حدث خطأ غير متوقع. حاول مرة أخرى';

  // الأدوار
  static const String roleAdmin = 'مدير';
  static const String roleInstructor = 'معلم';
  static const String roleStudent = 'طالب';
  static const String roleLabel = 'الدور';

  // الصفحات الرئيسية
  static const String home = 'الرئيسية';
  static const String adminDashboard = 'لوحة تحكم المدير';
  static const String instructorDashboard = 'لوحة المعلم';
  static const String studentDashboard = 'صفحة الطالب';
  static const String welcomeUser = 'مرحباً';
  static const String goodMorning = 'صباح الخير';
  static const String goodEvening = 'مساء الخير';
  static const String points = 'النقاط';
  static const String rank = 'الترتيب';
  static const String attendance = 'الحضور';

  // القرآن والأذكار
  static const String quran = 'القرآن الكريم';
  static const String morningAzkar = 'أذكار الصباح';
  static const String eveningAzkar = 'أذكار المساء';
  static const String azkar = 'الأذكار';

  // الطلاب
  static const String students = 'الطلاب';
  static const String addStudent = 'إضافة طالب';
  static const String studentName = 'اسم الطالب';
  static const String fatherName = 'اسم الأب';
  static const String dateOfBirth = 'تاريخ الميلاد';
  static const String school = 'المدرسة';
  static const String homeAddress = 'عنوان السكن';
  static const String phoneStudent = 'هاتف الطالب';
  static const String phoneParent = 'هاتف ولي الأمر';
  static const String search = 'بحث...';

  // الحضور والغياب
  static const String present = 'حاضر';
  static const String absent = 'غائب';
  static const String late = 'متأخر';
  static const String takeAttendance = 'تسجيل الحضور';
  static const String attendanceLog = 'سجل الحضور';

  // النقاط
  static const String addPoints = 'إضافة نقاط';
  static const String deductPoints = 'خصم نقاط';
  static const String pointsLog = 'سجل النقاط';
  static const String leaderboard = 'لوحة المتصدرين';
  static const String pointsCatalog = 'كتالوج النقاط';

  // فئات النقاط - إضافة
  static const String quranMemorization = 'حفظ صفحة قرآن';
  static const String textMemorization = 'حفظ نص ديني';
  static const String completeJuz = 'إتمام جزء كامل';
  static const String properDress = 'حسن المظهر';
  static const String politeBehavior = 'حسن السلوك';
  static const String quizPass = 'اجتياز الاختبار الشهري';
  static const String recruitStudent = 'إحضار طالب جديد';

  // فئات النقاط - خصم
  static const String disruptiveBehavior = 'إزعاج أثناء الدرس';
  static const String absenceDeduction = 'غياب';
  static const String lateDeduction = 'تأخر';
  static const String phoneUse = 'استخدام الهاتف بدون إذن';

  // التقييم
  static const String good = 'جيد';
  static const String veryGood = 'جيد جداً';
  static const String repeat = 'إعادة';

  // الإدارة
  static const String admin = 'الإدارة';
  static const String instructors = 'المعلمون';
  static const String addInstructor = 'إضافة معلم';
  static const String notifications = 'الإشعارات';
  static const String announcements = 'الإعلانات';
  static const String mediaGallery = 'معرض الصور';
  static const String settings = 'الإعدادات';
  static const String logout = 'تسجيل الخروج';
  static const String logoutConfirm = 'هل أنت متأكد من تسجيل الخروج؟';
  static const String yes = 'نعم';
  static const String no = 'لا';
  static const String save = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String noData = 'لا توجد بيانات';
  static const String loading = 'جاري التحميل...';
  static const String error = 'حدث خطأ';
  static const String retry = 'إعادة المحاولة';
  static const String success = 'تمت العملية بنجاح';
  static const String comingSoon = 'قريباً...';
}