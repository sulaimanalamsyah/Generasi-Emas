# Graph Report - Generasi_Emas  (2026-09-19)

## Corpus Check
- 88 files · ~150,360 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 9, .xml 8, .xcconfig 8)

## Summary
- 1605 nodes · 2146 edges · 81 communities (61 shown, 13 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 47 edges (avg confidence: 0.63)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5edba634`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- profile_page.dart
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
- package:flutter/material.dart
- forgot_password_page.dart
- webform_page.dart
- fcm_service.dart
- common.dart
- ../core/constants.dart
- ../services/api_client.dart
- List
- wWinMain
- manifest.json
- youtube_helper.dart
- link_utils.dart
- _AddJournalSheet
- ../widgets/common.dart
- dart:async
- pdf_helper.dart
- _CreateLogbookSheet
- validators.dart
- MaterialPageRoute
- LogbookPage
- MainActivity.kt
- ApiError
- BabyJournalPage
- _EditJournalSheet
- _ExpandableGuideStepCard
- GuidePage
- ProfileMotherDetailPage
- @email
- String?

## God Nodes (most connected - your core abstractions)
1. `Routes` - 32 edges
2. `Win32Window` - 24 edges
3. `MessageHandler` - 12 edges
4. `build` - 10 edges
5. `FlutterWindow` - 10 edges
6. `Create` - 10 edges
7. `WndProc` - 10 edges
8. `MessageHandler` - 9 edges
9. `Generasi Emas App` - 9 edges
10. `NurseShell4` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Generasi Emas App` --uses--> `App Visual Assets`  [EXTRACTED]
  pubspec.yaml → assets/icon.png
- `Generasi Emas App` --implements--> `Dual-Role User System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --implements--> `Health Journaling System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --implements--> `Pre/Post Test Assessment System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --targets--> `Multi-Platform Flutter Build`  [EXTRACTED]
  pubspec.yaml → linux/CMakeLists.txt

## Import Cycles
- None detected.

## Communities (81 total, 13 thin omitted)

### Community 0 - "profile_page.dart"
Cohesion: 0.11
Nodes (19): _api, createState, _doLogout, icon, initState, isDestructive, _load, _loading (+11 more)

### Community 1 - "home_patient_page.dart"
Cohesion: 0.08
Nodes (26): _api, assetPath, _bannerController, _bannerItems, _bannerTimer, createState, _currentBannerIndex, _displayName (+18 more)

### Community 2 - "api_client.dart"
Cohesion: 0.02
Nodes (86): ApiClient, _attemptRefreshToken, base, category, _checkConnection, completePosttest, completePretest, confirmPasswordResetOtpWa (+78 more)

### Community 3 - "Generasi Emas App"
Cohesion: 0.25
Nodes (8): App Visual Assets, Pre/Post Test Assessment System, Firebase Integration, Multi-Platform Flutter Build, Generasi Emas App, Health Journaling System, Project Dependencies, Stunting Education Mission

### Community 4 - "nurse_agg_page.dart"
Cohesion: 0.05
Nodes (41): _api, _asString, _babyNameOf, bgColor, build, _buildBody, _buildFilterAndSearchBar, _buildMetricsHeader (+33 more)

### Community 5 - "notifications_page.dart"
Cohesion: 0.08
Nodes (26): _api, build, _buildEmptyState, _buildErrorCard, _buildLoadingShimmer, _buildMasterSwitchCard, _buildNotificationCard, _buildScheduleCard (+18 more)

### Community 6 - "modules_page.dart"
Cohesion: 0.10
Nodes (20): int?, _allModules, _api, build, _buildBody, createState, dispose, _errorMessage (+12 more)

### Community 7 - "login_page.dart"
Cohesion: 0.06
Nodes (35): api_client.dart, ../core/nav.dart, ../core/storage.dart, fcm_service.dart, _auth, createState, dispose, _email (+27 more)

### Community 9 - "logbook_page.dart"
Cohesion: 0.03
Nodes (70): int get, _api, _att, attended, build, _buildBadgeChip, _checkRole, _chip (+62 more)

### Community 10 - "routes.dart"
Cohesion: 0.03
Nodes (69): activate, babyJournal, brainstorming, consent, consentReadOnly, consentRegister, contactResearchers, fatherLink (+61 more)

### Community 11 - "Win32Window"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 12 - "baby_journal_page.dart"
Cohesion: 0.04
Nodes (48): _api, build, _buildEmptyState, _buildJournalCard, _buildObserverBanner, _buildPager, _checkRole, _computeHasLoggedToday (+40 more)

### Community 13 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.05
Nodes (34): Any, Cocoa, connectivity_plus, firebase_core, firebase_messaging, Flutter, flutter_local_notifications, flutter_localization (+26 more)

### Community 14 - "storage.dart"
Cohesion: 0.04
Nodes (44): dart:convert, async, clearAll, clearToken, getActivated, getBool, getCookie, getDisplayName (+36 more)

### Community 15 - "patient_detail_page.dart"
Cohesion: 0.05
Nodes (40): _api, _argsInited, build, _buildJournalTab, _buildLogbookTab, _buildPatientHeaderCard, _buildProfileTab, _buildScoreTab (+32 more)

### Community 16 - "brainstorming_nurse_page.dart"
Cohesion: 0.05
Nodes (37): _allResources, _api, author, BrainstormingNursePage, _BrainstormingNursePageState, build, _buildBody, _buildFilterChip (+29 more)

### Community 17 - "reference_detail_page.dart"
Cohesion: 0.05
Nodes (38): args, author, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView (+30 more)

### Community 18 - "reset_password_page.dart"
Cohesion: 0.05
Nodes (37): FocusNode?, build, controller, _cooldown, createState, didChangeDependencies, dispose, _doReset (+29 more)

### Community 19 - "module_detail_page.dart"
Cohesion: 0.06
Nodes (36): ../core/pdf_helper.dart, args, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView (+28 more)

### Community 20 - "constants.dart"
Cohesion: 0.06
Nodes (33): AppEnv, appName, environment, kApiBase, kAppName, kBrainModuleTitleKeys, kBrainTextParentsRole, kBrainTextVisitDaily (+25 more)

### Community 21 - "consent_pages.dart"
Cohesion: 0.06
Nodes (32): 2025, _agreeAndRegister, _atBottom, build, ConsentReadOnlyPage, _ConsentReadOnlyPageState, ConsentRegisterPage, _ConsentRegisterPageState (+24 more)

### Community 22 - "profile_mother_detail_page.dart"
Cohesion: 0.07
Nodes (27): _address, _age, _api, _babyName, _birthWeight, build, _buildDropdown, _buildSectionCard (+19 more)

### Community 23 - "profile_infant_detail_page.dart"
Cohesion: 0.07
Nodes (28): DateTime?, _admissionLocal, _api, build, _buildDateRow, _buildSectionCard, _buildTextField, createState (+20 more)

### Community 24 - "activate_page.dart"
Cohesion: 0.08
Nodes (25): _activate, ActivatePage, _ActivatePageState, build, controller, _cooldown, createState, didChangeDependencies (+17 more)

### Community 25 - "guide_page.dart"
Cohesion: 0.08
Nodes (25): build, _buildFatherSteps, _buildMotherSteps, _buildNurseSteps, category, categoryColor, categoryTextColor, createState (+17 more)

### Community 26 - "register_page.dart"
Cohesion: 0.05
Nodes (39): _buildNoInfantBanner, _buildNoStart, build, build, build, _buildInputDecoration, _buildLabel, createState (+31 more)

### Community 27 - "my_application.cc"
Cohesion: 0.10
Nodes (20): FlPluginRegistry, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins(), main() (+12 more)

### Community 28 - "nurse_assign_patient_page.dart"
Cohesion: 0.09
Nodes (23): _api, _assigningId, _assignPatient, build, _buildBody, createState, _debounce, _displayInfantRaw (+15 more)

### Community 29 - "in_app_viewer_page.dart"
Cohesion: 0.08
Nodes (24): ChewieController?, build, _c, _chewie, createState, dispose, _err, _errorMessage (+16 more)

### Community 30 - "video_page.dart"
Cohesion: 0.09
Nodes (22): ../core/youtube_helper.dart, _allModules, _api, BrainstormingPage, build, _buildBody, createState, dispose (+14 more)

### Community 31 - "home_nurse_page.dart"
Cohesion: 0.06
Nodes (37): build, build, _api, _auth, _bootstrap, build, createState, _displayName (+29 more)

### Community 32 - "video_detail_page.dart"
Cohesion: 0.09
Nodes (22): args, build, _controller, _copyLink, createState, _currentDescription, _currentModuleTitle, _currentTitle (+14 more)

### Community 33 - "nurse_shell_4.dart"
Cohesion: 0.11
Nodes (17): bool get, build, child, createState, didChangeDependencies, go, _index, initialIndex (+9 more)

### Community 34 - "quiz_nurse_page.dart"
Cohesion: 0.11
Nodes (19): Color, IconData, _api, bgColor, build, _buildQuizCard, color, createState (+11 more)

### Community 36 - "StatelessWidget"
Cohesion: 0.11
Nodes (19): _FilterBar, _MonthCalendar, _StreakBanner, _ConsentHeader, _ConsentText, _Shortcut, _DayCard, _DayMatrixGrid (+11 more)

### Community 37 - "pretest_page.dart"
Cohesion: 0.11
Nodes (18): _api, _bootstrap, build, _card, createState, _fmtDate, initState, isFather (+10 more)

### Community 38 - "references_page.dart"
Cohesion: 0.09
Nodes (22): _allReferences, _api, build, _buildBody, createState, dispose, _errorMessage, _fetchReferences (+14 more)

### Community 39 - "patient_shell.dart"
Cohesion: 0.12
Nodes (16): build, child, createState, didChangeDependencies, go, _index, initialIndex, initState (+8 more)

### Community 40 - "contact_researchers_page.dart"
Cohesion: 0.12
Nodes (16): Future, _api, build, _call, ContactResearchersPage, _ContactResearchersPageState, _copy, createState (+8 more)

### Community 41 - "State"
Cohesion: 0.16
Nodes (17): AutomaticKeepAliveClientMixin, _KeepAlive, PatientDetailPage, _PatientDetailPageState, VideoDetailPage, _VideoDetailPageState, _KeepAliveState, _KeepAliveState (+9 more)

### Community 42 - "posttest_page.dart"
Cohesion: 0.13
Nodes (15): _api, createState, _fmtDate, _getAverageScoreData, initState, isFather, _items, _load (+7 more)

### Community 43 - "quiz_page.dart"
Cohesion: 0.13
Nodes (15): _api, _averageScore, build, createState, _fmtDate, initState, _isFather, _latestSubmittedAt (+7 more)

### Community 44 - "main.dart"
Cohesion: 0.14
Nodes (13): @pragma, ../app.dart, firebase_options.dart, _firebaseMessagingBackgroundHandler, initializeApp, initializeDateFormatting, main, null (+5 more)

### Community 45 - "privacy_policy_page.dart"
Cohesion: 0.14
Nodes (14): build, createState, _date, _defaultPolicy, _formatDate, initState, _loadData, _loading (+6 more)

### Community 46 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (9): Dual-Role User System, goHomeByRole, FolderNursePage, Routes, NurseShell4, _NurseShell4State, package:flutter/material.dart, ../routes.dart (+1 more)

### Community 47 - "forgot_password_page.dart"
Cohesion: 0.15
Nodes (13): FormState, build, createState, dispose, ForgotPasswordPage, _ForgotPasswordPageState, _form, _loading (+5 more)

### Community 48 - "webform_page.dart"
Cohesion: 0.15
Nodes (13): build, _buildErrorView, createState, _ctrl, _hasError, initState, _loading, title (+5 more)

### Community 49 - "fcm_service.dart"
Cohesion: 0.13
Nodes (14): _api, disableNotifications, enableNotifications, FcmService, _firebaseMessaging, _handleNavigation, init, _instance (+6 more)

### Community 50 - "common.dart"
Cohesion: 0.15
Nodes (12): BoxFit, double?, AppLogo, build, commonAppBar, evaluationAppBar, fit, label (+4 more)

### Community 51 - "../core/constants.dart"
Cohesion: 0.25
Nodes (7): ../core/constants.dart, GlobalKey, build, GenerasiEmasApp, navigatorKey, NavigatorState, package:flutter_localizations/flutter_localizations.dart

### Community 52 - "../services/api_client.dart"
Cohesion: 0.17
Nodes (12): _api, build, createState, dispose, _doLogout, FatherLinkPage, _FatherLinkPageState, _isLoading (+4 more)

### Community 53 - "List"
Cohesion: 0.17
Nodes (12): build, createState, dispose, _index, initState, LoadingOverlay, _LoadingOverlayState, message (+4 more)

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
Cohesion: 0.22
Nodes (8): callPhone, launchUrl, normalizeIdPhone, openExternalUrl, openWhatsApp, p, uri, package:url_launcher/url_launcher.dart

### Community 59 - "../widgets/common.dart"
Cohesion: 0.33
Nodes (6): createState, initState, StartPage, _StartPageState, package:flutter/services.dart, ../widgets/common.dart

### Community 60 - "dart:async"
Cohesion: 0.25
Nodes (7): dart:async, EventBus, I, onPatientsRefresh, _patientsRefreshCtl, triggerPatientsRefresh, static final EventBus

### Community 61 - "pdf_helper.dart"
Cohesion: 0.25
Nodes (7): extractGoogleDriveFileId, formatDoiUrl, getDirectDownloadUrl, getPlayablePdfUrl, isInteractiveFlipbookUrl, isPdfOrDriveDoc, PdfHelper

### Community 63 - "validators.dart"
Cohesion: 0.33
Nodes (5): emailValidator, minLength, null, requiredValidator, return

### Community 64 - "MaterialPageRoute"
Cohesion: 0.40
Nodes (5): _openForm, _handleOpenForm, _handleOpenForm, _handleOpenForm, MaterialPageRoute

## Knowledge Gaps
- **1097 isolated node(s):** `navigatorKey`, `build`, `AppEnv`, `kAppName`, `kPrimary` (+1092 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1235 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Routes` connect `package:flutter/material.dart` to `profile_page.dart`, `nurse_agg_page.dart`, `notifications_page.dart`, `modules_page.dart`, `login_page.dart`, `logbook_page.dart`, `routes.dart`, `baby_journal_page.dart`, `patient_detail_page.dart`, `brainstorming_nurse_page.dart`, `reset_password_page.dart`, `consent_pages.dart`, `profile_mother_detail_page.dart`, `profile_infant_detail_page.dart`, `activate_page.dart`, `register_page.dart`, `quiz_nurse_page.dart`, `pretest_page.dart`, `references_page.dart`, `patient_shell.dart`, `contact_researchers_page.dart`, `posttest_page.dart`, `quiz_page.dart`, `privacy_policy_page.dart`, `forgot_password_page.dart`, `../core/constants.dart`, `../services/api_client.dart`, `../widgets/common.dart`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Why does `Generasi Emas App` connect `Generasi Emas App` to `package:flutter/material.dart`, `manifest.json`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `Health Journaling System` connect `Generasi Emas App` to `logbook_page.dart`, `baby_journal_page.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `navigatorKey`, `build`, `AppEnv` to the rest of the system?**
  _1097 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `profile_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Should `home_patient_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.07692307692307693 - nodes in this community are weakly interconnected._
- **Should `api_client.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.022988505747126436 - nodes in this community are weakly interconnected._