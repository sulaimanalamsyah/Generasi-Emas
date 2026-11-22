# Graph Report - Generasi_Emas  (2026-11-22)

## Corpus Check
- 89 files · ~89,843 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 56 file(s) not represented in the graph (top: (none) 9, .xml 8, .xcconfig 8)
- WARNING: 56 of 199 files seen (28%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 1760 nodes · 2351 edges · 87 communities (63 shown, 24 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 43 edges (avg confidence: 0.65)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8c6b220d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- profile_page.dart
- home_patient_page.dart
- api_client.dart
- Generasi Emas App
- nurse_agg_page.dart
- notifications_page.dart
- quiz_nurse_page.dart
- login_page.dart
- dependencies
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
- package:flutter/material.dart
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
- package:flutter/foundation.dart
- StatelessWidget
- pretest_page.dart
- posttest_page.dart
- MaterialPageRoute
- contact_researchers_page.dart
- State
- ../core/storage.dart
- quiz_page.dart
- main.dart
- privacy_policy_page.dart
- _buildRingkasanSiKecilCard
- infant_analytics_dashboard_page.dart
- _openDetail
- fcm_service.dart
- common.dart
- ../routes.dart
- growth_chart.dart
- loading_overlay.dart
- wWinMain
- manifest.json
- youtube_helper.dart
- link_utils.dart
- analysis_options.yaml
- ../services/api_client.dart
- pdf_helper.dart
- age_calculator.dart
- _PatientDetailPageState
- _ExpandableGuideStepCard
- forgot_password_page.dart
- MainActivity.kt
- father_link_page.dart
- ApiError
- _NurseAggPageState
- BabyJournalPage
- _EditJournalSheet
- _CreateLogbookSheet
- LogbookPage
- modules_page.dart
- weight_formatter.dart
- weight_formatter_test.dart
- GuidePage

## God Nodes (most connected - your core abstractions)
1. `Routes` - 31 edges
2. `Win32Window` - 24 edges
3. `dependencies` - 20 edges
4. `MessageHandler` - 12 edges
5. `FlutterWindow` - 10 edges
6. `Create` - 10 edges
7. `WndProc` - 10 edges
8. `build` - 9 edges
9. `MessageHandler` - 9 edges
10. `NurseShell4` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Generasi Emas App` --uses--> `App Visual Assets`  [EXTRACTED]
  pubspec.yaml → assets/icon.png
- `Generasi Emas App` --targets--> `Multi-Platform Flutter Build`  [EXTRACTED]
  pubspec.yaml → linux/CMakeLists.txt
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `GenerasiEmasApp` --uses--> `Routes`  [EXTRACTED]
  lib/app.dart → lib/routes.dart

## Import Cycles
- None detected.

## Communities (87 total, 24 thin omitted)

### Community 0 - "profile_page.dart"
Cohesion: 0.05
Nodes (40): _api, _buildPartnerContent, _buildPartnerInfoRow, _buildPartnerMenuTile, _cancelOutgoingRequest, _confirmUnlinkPartner, createState, dispose (+32 more)

### Community 1 - "home_patient_page.dart"
Cohesion: 0.06
Nodes (32): _api, assetPath, _bannerController, _bannerItems, _bannerTimer, _buildPendingPartnerBanner, createState, _currentBannerIndex (+24 more)

### Community 2 - "api_client.dart"
Cohesion: 0.02
Nodes (95): addGrowthMeasurement, addNurseReview, ApiClient, _attemptRefreshToken, base, cancelPartnerRequest, category, _checkConnection (+87 more)

### Community 3 - "Generasi Emas App"
Cohesion: 0.40
Nodes (5): App Visual Assets, Firebase Integration, Multi-Platform Flutter Build, Generasi Emas App, Stunting Education Mission

### Community 4 - "nurse_agg_page.dart"
Cohesion: 0.05
Nodes (36): _api, _asString, _babyNameOf, bgColor, build, _buildBody, _buildFilterAndSearchBar, _buildMetricsHeader (+28 more)

### Community 5 - "notifications_page.dart"
Cohesion: 0.08
Nodes (26): _api, build, _buildEmptyState, _buildErrorCard, _buildLoadingShimmer, _buildMasterSwitchCard, _buildNotificationCard, _buildScheduleCard (+18 more)

### Community 6 - "quiz_nurse_page.dart"
Cohesion: 0.11
Nodes (17): _api, bgColor, build, _buildQuizCard, color, createState, desc, icon (+9 more)

### Community 7 - "login_page.dart"
Cohesion: 0.17
Nodes (12): _api, createState, dispose, _email, _goHomeByRole, _loading, LoginPage, _LoginPageState (+4 more)

### Community 8 - "dependencies"
Cohesion: 0.05
Nodes (39): dependencies, chewie, connectivity_plus, cupertino_ui, firebase_core, firebase_messaging, flutter, flutter_local_notifications (+31 more)

### Community 9 - "logbook_page.dart"
Cohesion: 0.03
Nodes (68): _api, _att, attended, build, _buildBadgeChip, _checkRole, _chip, _co (+60 more)

### Community 10 - "routes.dart"
Cohesion: 0.03
Nodes (38): activate, babyJournal, brainstorming, consent, consentReadOnly, consentRegister, contactResearchers, fatherLink (+30 more)

### Community 11 - "Win32Window"
Cohesion: 0.05
Nodes (39): RegisterPlugins(), FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), MessageHandler, OnCreate, OnDestroy, project_ (+31 more)

### Community 12 - "baby_journal_page.dart"
Cohesion: 0.04
Nodes (51): _api, build, _buildEmptyState, _buildJournalCard, _buildObserverBanner, _buildPager, _checkRole, _computeHasLoggedToday (+43 more)

### Community 13 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.05
Nodes (23): Cocoa, connectivity_plus, firebase_core, firebase_messaging, Flutter, flutter_local_notifications, flutter_secure_storage_darwin, FlutterMacOS (+15 more)

### Community 14 - "storage.dart"
Cohesion: 0.04
Nodes (40): async, clearAll, clearPendingFcmRevocation, clearToken, getActivated, getBool, getCookie, getDisplayName (+32 more)

### Community 15 - "patient_detail_page.dart"
Cohesion: 0.04
Nodes (52): _api, _argsInited, build, _buildFilterChip, _buildJournalTab, _buildLogbookTab, _buildMetricTile, _buildProfileTab (+44 more)

### Community 16 - "brainstorming_nurse_page.dart"
Cohesion: 0.05
Nodes (35): _allResources, _api, author, BrainstormingNursePage, _BrainstormingNursePageState, build, _buildBody, _buildFilterChip (+27 more)

### Community 17 - "reference_detail_page.dart"
Cohesion: 0.05
Nodes (43): args, author, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView (+35 more)

### Community 18 - "reset_password_page.dart"
Cohesion: 0.05
Nodes (36): build, controller, _cooldown, createState, didChangeDependencies, dispose, _doReset, focusNode (+28 more)

### Community 19 - "module_detail_page.dart"
Cohesion: 0.05
Nodes (38): args, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView, _buildRelatedMaterialsSection (+30 more)

### Community 20 - "package:flutter/material.dart"
Cohesion: 0.17
Nodes (8): apiTimeoutSeconds, AppEnv, appName, environment, kApiBase, kAppName, kConsentLastUpdated, kPrimary

### Community 21 - "consent_pages.dart"
Cohesion: 0.06
Nodes (29): 2025, _agreeAndRegister, _atBottom, build, ConsentReadOnlyPage, _ConsentReadOnlyPageState, ConsentRegisterPage, _ConsentRegisterPageState (+21 more)

### Community 22 - "profile_mother_detail_page.dart"
Cohesion: 0.06
Nodes (32): _address, _age, _api, _babyBirthDate, _babyName, _birthWeight, build, _buildDateRow (+24 more)

### Community 23 - "profile_infant_detail_page.dart"
Cohesion: 0.05
Nodes (38): _admissionLocal, _api, _birthDateLocal, build, _buildDateRow, _buildSectionCard, _buildTextField, _buildViewRow (+30 more)

### Community 24 - "activate_page.dart"
Cohesion: 0.08
Nodes (24): _activate, ActivatePage, _ActivatePageState, build, controller, _cooldown, createState, didChangeDependencies (+16 more)

### Community 25 - "guide_page.dart"
Cohesion: 0.08
Nodes (25): build, _buildFatherSteps, _buildMotherSteps, _buildNurseSteps, category, categoryColor, categoryTextColor, createState (+17 more)

### Community 26 - "register_page.dart"
Cohesion: 0.05
Nodes (29): _buildNoInfantBanner, _buildNoStart, build, build, build, _buildInputDecoration, _buildLabel, createState (+21 more)

### Community 27 - "my_application.cc"
Cohesion: 0.10
Nodes (13): fl_register_plugins(), main(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 28 - "nurse_assign_patient_page.dart"
Cohesion: 0.09
Nodes (23): _api, _assigningId, _assignPatient, build, _buildBody, createState, _debounce, _displayInfantRaw (+15 more)

### Community 29 - "in_app_viewer_page.dart"
Cohesion: 0.08
Nodes (19): build, _c, _chewie, createState, dispose, _err, _errorMessage, _init (+11 more)

### Community 30 - "video_page.dart"
Cohesion: 0.10
Nodes (19): _allModules, _api, BrainstormingPage, build, _buildBody, createState, dispose, _errorMessage (+11 more)

### Community 31 - "home_nurse_page.dart"
Cohesion: 0.06
Nodes (24): build, build, _api, _bootstrap, build, createState, _displayName, HomeNursePage (+16 more)

### Community 32 - "video_detail_page.dart"
Cohesion: 0.07
Nodes (27): args, build, _controller, _copyLink, createState, _currentDescription, _currentModuleTitle, _currentTitle (+19 more)

### Community 33 - "nurse_shell_4.dart"
Cohesion: 0.12
Nodes (12): FolderNursePage, Routes, build, createState, didChangeDependencies, go, _index, initialIndex (+4 more)

### Community 34 - "package:flutter/foundation.dart"
Cohesion: 0.33
Nodes (3): notifier, notify, PartnerSync

### Community 36 - "StatelessWidget"
Cohesion: 0.10
Nodes (19): _FilterBar, _MonthCalendar, _StreakBanner, _ConsentHeader, _ConsentText, _Shortcut, _DayCard, _DayMatrixGrid (+11 more)

### Community 37 - "pretest_page.dart"
Cohesion: 0.12
Nodes (17): _api, _bootstrap, build, _card, createState, _fmtDate, initState, isFather (+9 more)

### Community 38 - "posttest_page.dart"
Cohesion: 0.12
Nodes (15): _api, createState, _fmtDate, _getAverageScoreData, initState, isFather, _items, _load (+7 more)

### Community 39 - "MaterialPageRoute"
Cohesion: 0.22
Nodes (8): _setupCustomWidgetCallbacks, _openForm, _handleOpenForm, _handleOpenForm, _handleOpenForm, _setupCustomWidgetCallbacks, _setupCustomWidgetCallbacks, _setupCustomWidgetCallbacks

### Community 40 - "contact_researchers_page.dart"
Cohesion: 0.12
Nodes (14): _api, build, _call, ContactResearchersPage, _ContactResearchersPageState, _copy, createState, _future (+6 more)

### Community 41 - "State"
Cohesion: 0.23
Nodes (10): _AddJournalSheet, _AddJournalSheetState, VideoDetailPage, _VideoDetailPageState, InAppViewerPage, _InAppViewerPageState, _PdfOrWeb, _PdfOrWebState (+2 more)

### Community 42 - "../core/storage.dart"
Cohesion: 0.22
Nodes (5): createState, initState, _lastBackPress, StartPage, _StartPageState

### Community 43 - "quiz_page.dart"
Cohesion: 0.12
Nodes (14): _api, _averageScore, build, createState, _fmtDate, initState, _isFather, _latestSubmittedAt (+6 more)

### Community 44 - "main.dart"
Cohesion: 0.15
Nodes (5): _firebaseMessagingBackgroundHandler, initializeApp, initializeDateFormatting, main, null

### Community 45 - "privacy_policy_page.dart"
Cohesion: 0.14
Nodes (13): build, createState, _date, _defaultPolicy, _formatDate, initState, _loadData, _loading (+5 more)

### Community 47 - "infant_analytics_dashboard_page.dart"
Cohesion: 0.05
Nodes (42): _activeMetric, _api, build, _buildBottomActionBar, _buildClinicalDisclaimerCard, _buildDashboardContent, _buildErrorView, _buildInfantProfileCard (+34 more)

### Community 49 - "fcm_service.dart"
Cohesion: 0.12
Nodes (12): _api, disableNotifications, enableNotifications, FcmService, _firebaseMessaging, _handleNavigation, init, _instance (+4 more)

### Community 50 - "common.dart"
Cohesion: 0.11
Nodes (13): AppLogo, build, child, commonAppBar, createState, evaluationAppBar, fit, isError (+5 more)

### Community 51 - "../routes.dart"
Cohesion: 0.18
Nodes (4): build, GenerasiEmasApp, navigatorKey, scaffoldMessengerKey

### Community 52 - "growth_chart.dart"
Cohesion: 0.09
Nodes (18): activeMetric, build, _buildLegendPill, _buildMetricTab, _buildPointDetailCard, createState, GrowthChart, _GrowthChartPainter (+10 more)

### Community 53 - "loading_overlay.dart"
Cohesion: 0.17
Nodes (10): build, createState, dispose, _index, initState, LoadingOverlay, _LoadingOverlayState, message (+2 more)

### Community 54 - "wWinMain"
Cohesion: 0.24
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 55 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 56 - "youtube_helper.dart"
Cohesion: 0.20
Nodes (8): buildPlayerHtml, charset, class, extractVideoId, getPlayableUrl, getThumbnailUrl, name, YouTubeHelper

### Community 57 - "link_utils.dart"
Cohesion: 0.25
Nodes (5): launchUrl, normalizeIdPhone, openWhatsApp, p, uri

### Community 58 - "analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 59 - "../services/api_client.dart"
Cohesion: 0.22
Nodes (7): build, createState, _initApp, initState, _isVersionOlder, SplashPage, _SplashPageState

### Community 61 - "pdf_helper.dart"
Cohesion: 0.33
Nodes (5): extractGoogleDriveFileId, formatDoiUrl, getPlayablePdfUrl, isInteractiveFlipbookUrl, PdfHelper

### Community 62 - "age_calculator.dart"
Cohesion: 0.22
Nodes (8): calculate, days, formatted, InfantAge, months, monthsFraction, shortFormatted, totalDays

### Community 66 - "forgot_password_page.dart"
Cohesion: 0.15
Nodes (11): build, createState, dispose, ForgotPasswordPage, _ForgotPasswordPageState, _form, _loading, _phone (+3 more)

### Community 68 - "father_link_page.dart"
Cohesion: 0.11
Nodes (18): _api, build, _buildInputCard, _buildPendingCard, _cancelRequest, _checkInitialStatus, createState, dispose (+10 more)

### Community 76 - "modules_page.dart"
Cohesion: 0.05
Nodes (37): _allModules, _api, build, _buildBody, createState, dispose, _errorMessage, _fetchModules (+29 more)

### Community 77 - "weight_formatter.dart"
Cohesion: 0.40
Nodes (4): formatGrams, formatKgToGrams, parseGramsInputToKg, WeightFormatter

## Knowledge Gaps
- **1186 isolated node(s):** `navigatorKey`, `scaffoldMessengerKey`, `build`, `AppEnv`, `kAppName` (+1181 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1377 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Generasi Emas App` connect `Generasi Emas App` to `dependencies`, `manifest.json`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **What connects `navigatorKey`, `scaffoldMessengerKey`, `build` to the rest of the system?**
  _1186 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `profile_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.045328399629972246 - nodes in this community are weakly interconnected._
- **Why does `Firebase Integration` connect `Generasi Emas App` to `fcm_service.dart`, `main.dart`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **Should `home_patient_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.058823529411764705 - nodes in this community are weakly interconnected._
- **Why does `Routes` connect `nurse_shell_4.dart` to `profile_page.dart`, `nurse_agg_page.dart`, `notifications_page.dart`, `quiz_nurse_page.dart`, `login_page.dart`, `logbook_page.dart`, `routes.dart`, `baby_journal_page.dart`, `patient_detail_page.dart`, `brainstorming_nurse_page.dart`, `reset_password_page.dart`, `consent_pages.dart`, `profile_mother_detail_page.dart`, `profile_infant_detail_page.dart`, `activate_page.dart`, `register_page.dart`, `pretest_page.dart`, `posttest_page.dart`, `contact_researchers_page.dart`, `../core/storage.dart`, `quiz_page.dart`, `privacy_policy_page.dart`, `../routes.dart`, `../services/api_client.dart`, `forgot_password_page.dart`, `father_link_page.dart`, `modules_page.dart`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Should `api_client.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.020202020202020204 - nodes in this community are weakly interconnected._