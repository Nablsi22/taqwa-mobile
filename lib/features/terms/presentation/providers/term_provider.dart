import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../data/term_model.dart';
import '../../data/terms_api.dart';

/// App-wide course (دورة) state.
///
/// Two ideas live here and they are deliberately different:
///
///   • the ACTIVE course — decided by the admin, server-side. Everything
///     written (recitation, points, attendance, hadith) lands in it. The app
///     never chooses this.
///   • the VIEWED course — what the current user is looking at. Defaults to
///     the active course and can be pointed at an archived one to read its
///     history.
///
/// The viewed course resets to the active one on every launch, on purpose: a
/// selection that survived a restart would let someone open the app days
/// later and read a finished course's numbers as if they were current.
///
/// Recording screens always show the ACTIVE course, never the viewed one, so
/// a teacher browsing last winter can still only record into today's course.
class TermProvider extends ChangeNotifier {
  TermProvider({TermsApi? api})
      : _api = api ?? TermsApi(ApiClient.instance);

  final TermsApi _api;

  List<Term> _terms = const [];
  Term? _activeTerm;
  int? _viewedTermId;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  // ── Reads ────────────────────────────────────────────────────────
  List<Term> get terms => _terms;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  /// The course every new record goes into. `null` means no course has been
  /// activated yet — recording is refused by the backend until one is.
  Term? get activeTerm => _activeTerm;

  /// The course whose numbers are currently on screen.
  Term? get viewedTerm {
    if (_viewedTermId == null) return _activeTerm;
    for (final t in _terms) {
      if (t.id == _viewedTermId) return t;
    }
    return _activeTerm;
  }

  /// Value for the `termId` query parameter. `null` sends nothing, which the
  /// backend reads as "the active course" — so an unloaded provider behaves
  /// exactly like the app did before courses had a selector.
  int? get viewedTermIdParam => viewedTerm?.id;

  /// True while looking at anything other than the active course. Screens use
  /// this to show an "archive" banner instead of a plain course chip.
  bool get isViewingArchive =>
      viewedTerm != null && _activeTerm != null && viewedTerm!.id != _activeTerm!.id;

  bool get hasMultipleTerms => _terms.length > 1;

  // ── Writes ───────────────────────────────────────────────────────

  /// Load once per session unless [force] is set. Failures are surfaced in
  /// [error] and never thrown: a screen that cannot list courses still works,
  /// it just falls back to the active course the backend picks by default.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final terms = await _api.getTerms();
      _terms = terms;
      _activeTerm = _firstActive(terms);

      // Drop a selection that no longer exists (course deleted, or the user
      // signed in as someone else).
      if (_viewedTermId != null && !terms.any((t) => t.id == _viewedTermId)) {
        _viewedTermId = null;
      }
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Point the app at a different course to read its history. Viewing only —
  /// it never changes where new records go.
  void viewTerm(int? termId) {
    if (_viewedTermId == termId) return;
    _viewedTermId = termId;
    notifyListeners();
  }

  void viewActiveTerm() => viewTerm(null);

  /// Admin action: make [termId] the active course.
  ///
  /// Nothing is deleted or reset. Students, their history and every previous
  /// course's points stay exactly where they are; the new course simply has
  /// no points yet, so every balance in it starts at 0.
  Future<void> activate(int termId) async {
    await _api.activateTerm(termId);
    await load(force: true);
    viewActiveTerm();
  }

  /// Admin action: create a course, optionally starting it immediately.
  Future<Term> create({
    required String name,
    required String nameAr,
    required DateTime startDate,
    DateTime? endDate,
    bool activateNow = false,
  }) async {
    final term = await _api.createTerm(
      name: name,
      nameAr: nameAr,
      startDate: startDate,
      endDate: endDate,
      activateNow: activateNow,
    );
    await load(force: true);
    if (activateNow) viewActiveTerm();
    return term;
  }

  Future<void> rename(int termId, String nameAr) async {
    await _api.updateTerm(termId, nameAr: nameAr);
    await load(force: true);
  }

  /// Clear everything on sign-out so the next user does not inherit a
  /// selection or a stale course list.
  void reset() {
    _terms = const [];
    _activeTerm = null;
    _viewedTermId = null;
    _hasLoaded = false;
    _error = null;
    notifyListeners();
  }

  static Term? _firstActive(List<Term> terms) {
    for (final t in terms) {
      if (t.isActive) return t;
    }
    return null;
  }
}
