# Graph Report - Generasi_Emas  (2026-09-21)

## Corpus Check
- 84 files · ~126,114 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 9, .xml 8, .xcconfig 8)

## Summary
- 1632 nodes · 2177 edges · 76 communities (59 shown, 11 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 43 edges (avg confidence: 0.65)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5edba634`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- build
- home_patient_page.dart
- api_client.dart
- Generasi Emas App
- nurse_agg_page.dart
- notifications_page.dart
- modules_page.dart
- login_page.dart
- Common Widgets
- logbook_page.dart
- routes.dart
- Win32Window
- baby_journal_page.dart
- GeneratedPluginRegistrant.swift
- storage.dart
- patient_detail_page.dart
- brainstorming_nurse_page.dart
- reference_detail_page.dart
- reset_password_page.dart
- module_detail_page.dart
- constants.dart
- consent_pages.dart
- profile_mother_detail_page.dart
- profile_infant_detail_page.dart
- activate_page.dart
- guide_page.dart
- register_page.dart
- my_application.cc
- nurse_assign_patient_page.dart
- in_app_viewer_page.dart
- video_page.dart
- home_nurse_page.dart
- video_detail_page.dart
- nurse_shell_4.dart
- quiz_nurse_page.dart
- Generasi Emas — Mobile Application
- StatelessWidget
- pretest_page.dart
- references_page.dart
- patient_shell.dart
- contact_researchers_page.dart
- State
- posttest_page.dart
- quiz_page.dart
- main.dart
- privacy_policy_page.dart
- _NurseAggPageState
- infant_analytics_dashboard_page.dart
- _openDetail
- fcm_service.dart
- common.dart
- app.dart
- package:flutter/material.dart
- loading_overlay.dart
- wWinMain
- manifest.json
- youtube_helper.dart
- link_utils.dart
- _AddJournalSheet
- ../services/api_client.dart
- pdf_helper.dart
- _CreateLogbookSheet
- MaterialPageRoute
- LogbookPage
- MainActivity.kt
- ApiError
- BabyJournalPage
- _EditJournalSheet
- @email
- String?

## God Nodes (most connected - your core abstractions)
1. `Routes` - 31 edges
2. `Win32Window` - 24 edges
3. `Generasi Emas — Mobile Application` - 15 edges
4. `MessageHandler` - 12 edges
5. `build` - 10 edges
6. `FlutterWindow` - 10 edges
7. `Create` - 10 edges
8. `WndProc` - 10 edges
9. `MessageHandler` - 9 edges
10. `Generasi Emas App` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Generasi Emas App` --uses--> `App Visual Assets`  [EXTRACTED]
  pubspec.yaml → assets/icon.png
- `Generasi Emas App` --implements--> `Health Journaling System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --implements--> `Pre/Post Test Assessment System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --implements--> `Dual-Role User System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --targets--> `Multi-Platform Flutter Build`  [EXTRACTED]
  pubspec.yaml → linux/CMakeLists.txt

## Import Cycles
- None detected.

## Communities (76 total, 11 thin omitted)

### Community 0 - "build"
Cohesion: 0.07
Nodes (31): _buildNoInfantBanner, build, _buildNoStart, build, build, build, _buildPatientHeaderCard, build (+23 more)

### Community 1 - "home_patient_page.dart"
Cohesion: 0.08
Nodes (26): _api, assetPath, _bannerController, _bannerItems, _bannerTimer, createState, _currentBannerIndex, _displayName (+18 more)

### Community 2 - "api_client.dart"
Cohesion: 0.02
Nodes (91): ../core/link_utils.dart, addGrowthMeasurement, addNurseReview, ApiClient, _attemptRefreshToken, base, category, _checkConnection (+83 more)

### Community 3 - "Generasi Emas App"
Cohesion: 0.22
Nodes (9): App Visual Assets, Pre/Post Test Assessment System, Dual-Role User System, Firebase Integration, Multi-Platform Flutter Build, Generasi Emas App, Health Journaling System, Project Dependencies (+1 more)

### Community 4 - "nurse_agg_page.dart"
Cohesion: 0.05
Nodes (36): _api, _asString, _babyNameOf, bgColor, build, _buildBody, _buildFilterAndSearchBar, _buildMetricsHeader (+28 more)

### Community 5 - "notifications_page.dart"
Cohesion: 0.08
Nodes (26): _api, build, _buildEmptyState, _buildErrorCard, _buildLoadingShimmer, _buildMasterSwitchCard, _buildNotificationCard, _buildScheduleCard (+18 more)

### Community 6 - "modules_page.dart"
Cohesion: 0.11
Nodes (18): _allModules, _api, build, _buildBody, createState, dispose, _errorMessage, _fetchModules (+10 more)

### Community 7 - "login_page.dart"
Cohesion: 0.18
Nodes (10): _api, createState, dispose, _email, _goHomeByRole, _loading, _obscure, _pass (+2 more)

### Community 9 - "logbook_page.dart"
Cohesion: 0.03
Nodes (69): int get, _api, _att, attended, build, _buildBadgeChip, _checkRole, _chip (+61 more)

### Community 10 - "routes.dart"
Cohesion: 0.03
Nodes (70): activate, babyJournal, brainstorming, consent, consentReadOnly, consentRegister, contactResearchers, fatherLink (+62 more)

### Community 11 - "Win32Window"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 12 - "baby_journal_page.dart"
Cohesion: 0.04
Nodes (48): _api, build, _buildEmptyState, _buildJournalCard, _buildObserverBanner, _buildPager, _checkRole, _computeHasLoggedToday (+40 more)

### Community 13 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.05
Nodes (33): Any, Cocoa, connectivity_plus, firebase_core, firebase_messaging, Flutter, flutter_local_notifications, flutter_secure_storage_macos (+25 more)

### Community 14 - "storage.dart"
Cohesion: 0.04
Nodes (44): dart:convert, async, clearAll, clearToken, getActivated, getBool, getCookie, getDisplayName (+36 more)

### Community 15 - "patient_detail_page.dart"
Cohesion: 0.05
Nodes (42): _api, _argsInited, build, _buildJournalTab, _buildLogbookTab, _buildProfileTab, _buildScoreTab, createState (+34 more)

### Community 16 - "brainstorming_nurse_page.dart"
Cohesion: 0.05
Nodes (37): _allResources, _api, author, BrainstormingNursePage, _BrainstormingNursePageState, build, _buildBody, _buildFilterChip (+29 more)

### Community 17 - "reference_detail_page.dart"
Cohesion: 0.05
Nodes (36): args, author, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView (+28 more)

### Community 18 - "reset_password_page.dart"
Cohesion: 0.05
Nodes (37): FocusNode?, build, controller, _cooldown, createState, didChangeDependencies, dispose, _doReset (+29 more)

### Community 19 - "module_detail_page.dart"
Cohesion: 0.06
Nodes (36): ../core/pdf_helper.dart, args, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView (+28 more)

### Community 20 - "constants.dart"
Cohesion: 0.10
Nodes (19): AppEnv, appName, environment, kApiBase, kAppName, kBrainModuleTitleKeys, kBrainTextParentsRole, kBrainTextVisitDaily (+11 more)

### Community 21 - "consent_pages.dart"
Cohesion: 0.06
Nodes (32): 2025, _agreeAndRegister, _atBottom, build, ConsentReadOnlyPage, _ConsentReadOnlyPageState, ConsentRegisterPage, _ConsentRegisterPageState (+24 more)

### Community 22 - "profile_mother_detail_page.dart"
Cohesion: 0.07
Nodes (29): _address, _age, _api, _babyName, _birthWeight, build, _buildDropdown, _buildSectionCard (+21 more)

### Community 23 - "profile_infant_detail_page.dart"
Cohesion: 0.07
Nodes (28): DateTime?, _admissionLocal, _api, build, _buildDateRow, _buildSectionCard, _buildTextField, createState (+20 more)

### Community 24 - "activate_page.dart"
Cohesion: 0.08
Nodes (25): _activate, ActivatePage, _ActivatePageState, build, controller, _cooldown, createState, didChangeDependencies (+17 more)

### Community 25 - "guide_page.dart"
Cohesion: 0.07
Nodes (27): build, _buildFatherSteps, _buildMotherSteps, _buildNurseSteps, category, categoryColor, categoryTextColor, createState (+19 more)

### Community 26 - "register_page.dart"
Cohesion: 0.08
Nodes (25): _buildInputDecoration, _buildLabel, createState, dispose, _email, _formKey, initState, _isConsentChecked (+17 more)

### Community 27 - "my_application.cc"
Cohesion: 0.10
Nodes (20): FlPluginRegistry, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins(), main() (+12 more)

### Community 28 - "nurse_assign_patient_page.dart"
Cohesion: 0.09
Nodes (23): _api, _assigningId, _assignPatient, build, _buildBody, createState, _debounce, _displayInfantRaw (+15 more)

### Community 29 - "in_app_viewer_page.dart"
Cohesion: 0.08
Nodes (27): ChewieController?, build, _c, _chewie, createState, dispose, _err, _errorMessage (+19 more)

### Community 30 - "video_page.dart"
Cohesion: 0.05
Nodes (43): ../core/youtube_helper.dart, CustomPainter, int?, _allModules, _api, BrainstormingPage, build, _buildBody (+35 more)

### Community 31 - "home_nurse_page.dart"
Cohesion: 0.05
Nodes (41): IconData, _api, _bootstrap, createState, _displayName, HomeNursePage, _HomeNursePageState, icon (+33 more)

### Community 32 - "video_detail_page.dart"
Cohesion: 0.08
Nodes (25): args, build, _controller, _copyLink, createState, _currentDescription, _currentModuleTitle, _currentTitle (+17 more)

### Community 33 - "nurse_shell_4.dart"
Cohesion: 0.10
Nodes (21): AutomaticKeepAliveClientMixin, bool get, _KeepAlive, build, child, createState, didChangeDependencies, go (+13 more)

### Community 34 - "quiz_nurse_page.dart"
Cohesion: 0.11
Nodes (18): Color, _api, bgColor, build, _buildQuizCard, color, createState, desc (+10 more)

### Community 35 - "Generasi Emas — Mobile Application"
Cohesion: 0.08
Nodes (25): 10. Security, 11. How to Contribute?, 12. What's Next? (Roadmap), 13. License, 14. Acknowledgements, 15. Author & Contact, 3. About The Project, 4. Features (+17 more)

### Community 36 - "StatelessWidget"
Cohesion: 0.11
Nodes (19): _FilterBar, _MonthCalendar, _StreakBanner, _ConsentHeader, _ConsentText, _Shortcut, _DayCard, _DayMatrixGrid (+11 more)

### Community 37 - "pretest_page.dart"
Cohesion: 0.11
Nodes (18): _api, _bootstrap, build, _card, createState, _fmtDate, initState, isFather (+10 more)

### Community 38 - "references_page.dart"
Cohesion: 0.10
Nodes (21): _allReferences, _api, build, _buildBody, createState, dispose, _errorMessage, _fetchReferences (+13 more)

### Community 39 - "patient_shell.dart"
Cohesion: 0.12
Nodes (16): build, child, createState, didChangeDependencies, go, _index, initialIndex, initState (+8 more)

### Community 40 - "contact_researchers_page.dart"
Cohesion: 0.12
Nodes (16): Future, _api, build, _call, ContactResearchersPage, _ContactResearchersPageState, _copy, createState (+8 more)

### Community 41 - "State"
Cohesion: 0.14
Nodes (20): FatherLinkPage, _FatherLinkPageState, _ExpandableGuideStepCard, _ExpandableGuideStepCardState, LoginPage, _LoginPageState, ModulesPage, _ModulesPageState (+12 more)

### Community 42 - "posttest_page.dart"
Cohesion: 0.12
Nodes (16): _api, createState, _fmtDate, _getAverageScoreData, initState, isFather, _items, _load (+8 more)

### Community 43 - "quiz_page.dart"
Cohesion: 0.13
Nodes (15): _api, _averageScore, build, createState, _fmtDate, initState, _isFather, _latestSubmittedAt (+7 more)

### Community 44 - "main.dart"
Cohesion: 0.13
Nodes (14): @pragma, ../app.dart, firebase_options.dart, _firebaseMessagingBackgroundHandler, initializeApp, initializeDateFormatting, main, null (+6 more)

### Community 45 - "privacy_policy_page.dart"
Cohesion: 0.14
Nodes (14): build, createState, _date, _defaultPolicy, _formatDate, initState, _loadData, _loading (+6 more)

### Community 46 - "_NurseAggPageState"
Cohesion: 0.67
Nodes (3): NurseAggPage, _NurseAggPageState, WidgetsBindingObserver

### Community 47 - "infant_analytics_dashboard_page.dart"
Cohesion: 0.05
Nodes (42): FormState, build, createState, dispose, ForgotPasswordPage, _ForgotPasswordPageState, _form, _loading (+34 more)

### Community 49 - "fcm_service.dart"
Cohesion: 0.13
Nodes (14): api_client.dart, _api, disableNotifications, enableNotifications, FcmService, _firebaseMessaging, _handleNavigation, init (+6 more)

### Community 50 - "common.dart"
Cohesion: 0.14
Nodes (13): BoxFit, double?, AppLogo, build, commonAppBar, evaluationAppBar, fit, isError (+5 more)

### Community 51 - "app.dart"
Cohesion: 0.22
Nodes (8): ../core/constants.dart, GlobalKey, build, navigatorKey, scaffoldMessengerKey, NavigatorState, package:flutter_localizations/flutter_localizations.dart, ScaffoldMessengerState

### Community 52 - "package:flutter/material.dart"
Cohesion: 0.13
Nodes (16): GenerasiEmasApp, _api, build, createState, dispose, _doLogout, _isLoading, _phoneCtrl (+8 more)

### Community 53 - "loading_overlay.dart"
Cohesion: 0.17
Nodes (12): dart:async, build, createState, dispose, _index, initState, LoadingOverlay, _LoadingOverlayState (+4 more)

### Community 54 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 55 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 56 - "youtube_helper.dart"
Cohesion: 0.20
Nodes (9): , buildPlayerHtml, charset, class, extractVideoId, getPlayableUrl, getThumbnailUrl, name (+1 more)

### Community 57 - "link_utils.dart"
Cohesion: 0.20
Nodes (9): callPhone, launchUrl, normalizeIdPhone, openExternalUrl, openWhatsApp, p, uri, package:url_launcher/url_launcher.dart (+1 more)

### Community 59 - "../services/api_client.dart"
Cohesion: 0.15
Nodes (12): ../core/storage.dart, build, createState, _initApp, initState, _isVersionOlder, createState, initState (+4 more)

### Community 61 - "pdf_helper.dart"
Cohesion: 0.25
Nodes (7): extractGoogleDriveFileId, formatDoiUrl, getDirectDownloadUrl, getPlayablePdfUrl, isInteractiveFlipbookUrl, isPdfOrDriveDoc, PdfHelper

### Community 64 - "MaterialPageRoute"
Cohesion: 0.40
Nodes (5): _openForm, _handleOpenForm, _handleOpenForm, _handleOpenForm, MaterialPageRoute

## Knowledge Gaps
- **1119 isolated node(s):** `navigatorKey`, `scaffoldMessengerKey`, `build`, `AppEnv`, `kAppName` (+1114 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1259 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Routes` connect `package:flutter/material.dart` to `nurse_agg_page.dart`, `notifications_page.dart`, `modules_page.dart`, `login_page.dart`, `logbook_page.dart`, `routes.dart`, `baby_journal_page.dart`, `patient_detail_page.dart`, `brainstorming_nurse_page.dart`, `reset_password_page.dart`, `consent_pages.dart`, `profile_mother_detail_page.dart`, `profile_infant_detail_page.dart`, `activate_page.dart`, `register_page.dart`, `home_nurse_page.dart`, `quiz_nurse_page.dart`, `pretest_page.dart`, `references_page.dart`, `patient_shell.dart`, `contact_researchers_page.dart`, `posttest_page.dart`, `quiz_page.dart`, `privacy_policy_page.dart`, `infant_analytics_dashboard_page.dart`, `../services/api_client.dart`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **Why does `Generasi Emas App` connect `Generasi Emas App` to `manifest.json`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `ApiError` connect `ApiError` to `api_client.dart`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `navigatorKey`, `scaffoldMessengerKey`, `build` to the rest of the system?**
  _1119 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `build` be split into smaller, more focused modules?**
  _Cohesion score 0.06881720430107527 - nodes in this community are weakly interconnected._
- **Should `home_patient_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.07692307692307693 - nodes in this community are weakly interconnected._
- **Should `api_client.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.021739130434782608 - nodes in this community are weakly interconnected._