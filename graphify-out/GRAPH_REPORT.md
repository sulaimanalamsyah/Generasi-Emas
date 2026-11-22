# Graph Report - Generasi_Emas  (2026-11-22)

## Corpus Check
- 91 files · ~98,729 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 56 file(s) not represented in the graph (top: (none) 9, .xml 8, .xcconfig 8)
- WARNING: 56 of 201 files seen (28%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 1976 nodes · 2671 edges · 89 communities (64 shown, 25 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 43 edges (avg confidence: 0.65)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `11bded4f`
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
- ENICare Mobile App (`Generasi_Emas`)
- StatelessWidget
- pretest_page.dart
- posttest_page.dart
- MaterialPageRoute
- contact_researchers_page.dart
- State
- patient_shell.dart
- quiz_page.dart
- main.dart
- privacy_policy_page.dart
- modules_page.dart
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
- List
- analysis_options.yaml
- _KeepAliveWrapperState
- pdf_helper.dart
- age_calculator.dart
- _PatientDetailPageState
- _TabBarHeaderDelegate
- forgot_password_page.dart
- MainActivity.kt
- father_link_page.dart
- ApiError
- _NurseAggPageState
- _onSubmit
- RegisterPage
- _CreateLogbookSheet
- LogbookPage
- modules_page.dart
- weight_formatter.dart
- AppVersionFooter
- weight_formatter_test.dart
- InAppViewerPage

## God Nodes (most connected - your core abstractions)
1. `Routes` - 31 edges
2. `Win32Window` - 24 edges
3. `dependencies` - 20 edges
4. `ENICare Mobile App (`Generasi_Emas`)` - 15 edges
5. `MessageHandler` - 12 edges
6. `FlutterWindow` - 10 edges
7. `Create` - 10 edges
8. `WndProc` - 10 edges
9. `build` - 9 edges
10. `MessageHandler` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Generasi Emas App` --uses--> `App Visual Assets`  [EXTRACTED]
  pubspec.yaml → assets/icon.png
- `Generasi Emas App` --targets--> `Multi-Platform Flutter Build`  [EXTRACTED]
  pubspec.yaml → linux/CMakeLists.txt
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Routes` --routes_to--> `NurseShell4`  [EXTRACTED]
  lib/routes.dart → lib/shells/nurse_shell_4.dart

## Import Cycles
- None detected.

## Communities (89 total, 25 thin omitted)

### Community 0 - "profile_page.dart"
Cohesion: 0.05
Nodes (38): _buildNoInfantBanner, _buildNoStart, build, _api, _applyProfilePayload, build, _buildGuestProfile, _buildPartnerContent (+30 more)

### Community 1 - "home_patient_page.dart"
Cohesion: 0.05
Nodes (39): _api, assetPath, _bannerController, _bannerItems, _bannerTimer, _buildGuestWelcomeCard, _buildPendingPartnerBanner, _buildRingkasanSiKecilCard (+31 more)

### Community 2 - "api_client.dart"
Cohesion: 0.02
Nodes (102): addGrowthMeasurement, addNurseReview, ApiClient, _attemptRefreshToken, base, cancelPartnerRequest, category, _checkConnection (+94 more)

### Community 3 - "Generasi Emas App"
Cohesion: 0.40
Nodes (5): App Visual Assets, Firebase Integration, Multi-Platform Flutter Build, Generasi Emas App, Stunting Education Mission

### Community 4 - "nurse_agg_page.dart"
Cohesion: 0.05
Nodes (37): _api, _asString, _babyNameOf, bgColor, build, _buildBodySlivers, _buildFilterAndSearchBar, _buildMetricsHeader (+29 more)

### Community 5 - "notifications_page.dart"
Cohesion: 0.06
Nodes (32): _api, _applyNotifPayload, build, _buildEmptyState, _buildErrorCard, _buildLoadingShimmer, _buildMasterSwitchCard, _buildNotificationCard (+24 more)

### Community 6 - "quiz_nurse_page.dart"
Cohesion: 0.10
Nodes (18): _api, bgColor, build, _buildQuizCard, _canonicalKeys, color, createState, desc (+10 more)

### Community 7 - "login_page.dart"
Cohesion: 0.11
Nodes (15): _api, createState, dispose, _email, _goHomeByRole, _loading, _obscure, _pass (+7 more)

### Community 8 - "dependencies"
Cohesion: 0.05
Nodes (39): dependencies, chewie, connectivity_plus, cupertino_ui, firebase_core, firebase_messaging, flutter, flutter_local_notifications (+31 more)

### Community 9 - "logbook_page.dart"
Cohesion: 0.03
Nodes (69): _api, _applyLogbookPayload, _att, attended, _buildBadgeChip, _checkRole, _chip, _co (+61 more)

### Community 10 - "routes.dart"
Cohesion: 0.03
Nodes (38): activate, babyJournal, brainstorming, consent, consentReadOnly, consentRegister, contactResearchers, fatherLink (+30 more)

### Community 11 - "Win32Window"
Cohesion: 0.05
Nodes (39): RegisterPlugins(), FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), MessageHandler, OnCreate, OnDestroy, project_ (+31 more)

### Community 12 - "baby_journal_page.dart"
Cohesion: 0.04
Nodes (53): _api, _applyJournalState, build, _buildEmptyState, _buildJournalCard, _buildObserverBanner, _buildPager, _checkRole (+45 more)

### Community 13 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.05
Nodes (23): Cocoa, connectivity_plus, firebase_core, firebase_messaging, Flutter, flutter_local_notifications, flutter_secure_storage_darwin, FlutterMacOS (+15 more)

### Community 14 - "storage.dart"
Cohesion: 0.04
Nodes (50): async, clearAll, clearPendingFcmRevocation, clearToken, getActivated, getBool, getCachedJson, getCookie (+42 more)

### Community 15 - "patient_detail_page.dart"
Cohesion: 0.03
Nodes (58): _api, _argsInited, build, _buildFilterChip, _buildJournalTab, _buildLogbookTab, _buildMetricTile, _buildProfileTab (+50 more)

### Community 16 - "brainstorming_nurse_page.dart"
Cohesion: 0.05
Nodes (38): _allResources, _api, author, BrainstormingNursePage, _BrainstormingNursePageState, build, _buildBody, _buildFilterChip (+30 more)

### Community 17 - "reference_detail_page.dart"
Cohesion: 0.04
Nodes (46): args, author, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView (+38 more)

### Community 18 - "reset_password_page.dart"
Cohesion: 0.05
Nodes (37): build, controller, _cooldown, createState, didChangeDependencies, dispose, _doReset, focusNode (+29 more)

### Community 19 - "module_detail_page.dart"
Cohesion: 0.05
Nodes (41): args, build, _buildBadge, _buildMetadataCard, _buildQuickActionsBar, _buildReaderSection, _buildReaderView, _buildRelatedMaterialsSection (+33 more)

### Community 20 - "package:flutter/material.dart"
Cohesion: 0.18
Nodes (8): apiTimeoutSeconds, AppEnv, appName, environment, kApiBase, kAppName, kConsentLastUpdated, kPrimary

### Community 21 - "consent_pages.dart"
Cohesion: 0.06
Nodes (31): 2025, _agreeAndRegister, _atBottom, build, _ConsentHeader, ConsentReadOnlyPage, _ConsentReadOnlyPageState, ConsentRegisterPage (+23 more)

### Community 22 - "profile_mother_detail_page.dart"
Cohesion: 0.05
Nodes (40): AppDateFormatter, dateTime, fullDate, score, shortDate, tryParseLocal, _address, _age (+32 more)

### Community 23 - "profile_infant_detail_page.dart"
Cohesion: 0.05
Nodes (42): _admissionLocal, _api, _applyInfantPayload, _birthDateLocal, _birthWeightCtrl, build, _buildDateRow, _buildSectionCard (+34 more)

### Community 24 - "activate_page.dart"
Cohesion: 0.08
Nodes (23): _activate, _ActivateField, ActivatePage, _ActivatePageState, build, controller, _cooldown, createState (+15 more)

### Community 25 - "guide_page.dart"
Cohesion: 0.06
Nodes (34): build, _buildFatherSteps, _buildMotherSteps, _buildNurseSteps, category, categoryColor, categoryTextColor, createState (+26 more)

### Community 26 - "register_page.dart"
Cohesion: 0.06
Nodes (29): badgeBg, badgeFg, _buildInputDecoration, _buildLabel, _canSubmit, createState, dispose, _email (+21 more)

### Community 27 - "my_application.cc"
Cohesion: 0.10
Nodes (13): fl_register_plugins(), main(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 28 - "nurse_assign_patient_page.dart"
Cohesion: 0.09
Nodes (23): _api, _assigningId, _assignPatient, build, _buildBody, createState, _debounce, _displayInfantRaw (+15 more)

### Community 29 - "in_app_viewer_page.dart"
Cohesion: 0.06
Nodes (25): build, _c, _chewie, createState, dispose, _err, _errorMessage, _init (+17 more)

### Community 30 - "video_page.dart"
Cohesion: 0.09
Nodes (20): _allModules, _api, BrainstormingPage, build, _buildBody, createState, dispose, _errorMessage (+12 more)

### Community 31 - "home_nurse_page.dart"
Cohesion: 0.05
Nodes (27): build, build, build, _api, _bootstrap, build, createState, _displayName (+19 more)

### Community 32 - "video_detail_page.dart"
Cohesion: 0.06
Nodes (31): args, build, _controller, _copyLink, createState, _currentDescription, _currentItemId, _currentModuleTitle (+23 more)

### Community 33 - "nurse_shell_4.dart"
Cohesion: 0.14
Nodes (10): build, createState, didChangeDependencies, go, _index, initialIndex, initState, NurseShell4 (+2 more)

### Community 34 - "package:flutter/foundation.dart"
Cohesion: 0.33
Nodes (3): notifier, notify, PartnerSync

### Community 35 - "ENICare Mobile App (`Generasi_Emas`)"
Cohesion: 0.10
Nodes (19): 10. Security, 11. How to Contribute?, 12. What's Next?, 13. License, 14. Acknowledgements, 15. Author, 2. Table of Contents, 3. About (+11 more)

### Community 36 - "StatelessWidget"
Cohesion: 0.09
Nodes (22): _FilterBar, _MonthCalendar, _StreakBanner, _RoleTab, _Shortcut, _DayCard, _DayMatrixGrid, _LogbookProgressCard (+14 more)

### Community 37 - "pretest_page.dart"
Cohesion: 0.09
Nodes (20): _api, _applyScoreItems, _bootstrap, build, _card, createState, initState, isFather (+12 more)

### Community 38 - "posttest_page.dart"
Cohesion: 0.11
Nodes (16): _api, createState, _getAverageScoreData, _handleOpenForm, initState, isFather, _items, _kPosttestCacheKey (+8 more)

### Community 39 - "MaterialPageRoute"
Cohesion: 0.29
Nodes (6): _setupCustomWidgetCallbacks, _openForm, _handleOpenForm, _setupCustomWidgetCallbacks, _setupCustomWidgetCallbacks, _setupCustomWidgetCallbacks

### Community 40 - "contact_researchers_page.dart"
Cohesion: 0.11
Nodes (14): _api, build, _call, _copy, createState, _fetchContacts, _future, initState (+6 more)

### Community 41 - "State"
Cohesion: 0.16
Nodes (16): _AddJournalSheet, _AddJournalSheetState, BabyJournalPage, _BabyJournalPageState, _EditJournalSheet, _EditJournalSheetState, ContactResearchersPage, _ContactResearchersPageState (+8 more)

### Community 42 - "patient_shell.dart"
Cohesion: 0.08
Nodes (19): activeIcon, build, _buildTab, createState, didChangeDependencies, go, icon, _index (+11 more)

### Community 43 - "quiz_page.dart"
Cohesion: 0.12
Nodes (15): _api, _averageScore, build, createState, _handleOpenForm, initState, _isFather, _kScoresCacheKey (+7 more)

### Community 44 - "main.dart"
Cohesion: 0.15
Nodes (5): _firebaseMessagingBackgroundHandler, initializeApp, initializeDateFormatting, main, null

### Community 45 - "privacy_policy_page.dart"
Cohesion: 0.14
Nodes (13): build, createState, _date, _defaultPolicy, _formatDate, initState, _loadData, _loading (+5 more)

### Community 46 - "modules_page.dart"
Cohesion: 0.10
Nodes (19): _allModules, _api, build, _buildBody, createState, dispose, _errorMessage, _fetchModules (+11 more)

### Community 47 - "infant_analytics_dashboard_page.dart"
Cohesion: 0.04
Nodes (46): _activeMetric, _analyticsCacheKey, _api, build, _buildBottomActionBar, _buildClinicalDisclaimerCard, _buildClinicalStatusField, _buildDashboardContent (+38 more)

### Community 49 - "fcm_service.dart"
Cohesion: 0.09
Nodes (15): _api, disableNotifications, enableNotifications, FcmService, _firebaseMessaging, _handleNavigation, init, _instance (+7 more)

### Community 50 - "common.dart"
Cohesion: 0.03
Nodes (63): accent, actions, badgeBg, build, buttonLabel, cancelLabel, candId, candTitle (+55 more)

### Community 51 - "../routes.dart"
Cohesion: 0.15
Nodes (6): build, GenerasiEmasApp, navigatorKey, scaffoldMessengerKey, FolderNursePage, Routes

### Community 52 - "growth_chart.dart"
Cohesion: 0.08
Nodes (20): activeMetric, birthWeightGrams, build, _buildLegendPill, _buildMetricTab, _buildPointDetailCard, createState, gestationalWeeks (+12 more)

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

### Community 57 - "List"
Cohesion: 0.12
Nodes (11): launchUrl, normalizeIdPhone, openWhatsApp, p, uri, activeMaternalGuideSlot, cached, fetchMaternalGuideWithFallback (+3 more)

### Community 58 - "analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 61 - "pdf_helper.dart"
Cohesion: 0.33
Nodes (5): extractGoogleDriveFileId, formatDoiUrl, getPlayablePdfUrl, isInteractiveFlipbookUrl, PdfHelper

### Community 62 - "age_calculator.dart"
Cohesion: 0.22
Nodes (8): calculate, days, formatted, InfantAge, months, monthsFraction, shortFormatted, totalDays

### Community 66 - "forgot_password_page.dart"
Cohesion: 0.10
Nodes (14): build, createState, dispose, ForgotPasswordPage, _ForgotPasswordPageState, _form, _loading, _phone (+6 more)

### Community 68 - "father_link_page.dart"
Cohesion: 0.11
Nodes (18): _api, build, _buildInputCard, _buildPendingCard, _cancelRequest, _checkInitialStatus, createState, dispose (+10 more)

### Community 76 - "modules_page.dart"
Cohesion: 0.09
Nodes (20): _allReferences, _api, build, _buildBody, createState, dispose, _errorMessage, _fetchReferences (+12 more)

### Community 77 - "weight_formatter.dart"
Cohesion: 0.40
Nodes (4): formatGrams, formatKgToGrams, parseGramsInputToKg, WeightFormatter

## Knowledge Gaps
- **1354 isolated node(s):** `navigatorKey`, `scaffoldMessengerKey`, `build`, `AppDateFormatter`, `tryParseLocal` (+1349 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1565 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Routes` connect `../routes.dart` to `profile_page.dart`, `nurse_agg_page.dart`, `notifications_page.dart`, `quiz_nurse_page.dart`, `login_page.dart`, `logbook_page.dart`, `routes.dart`, `baby_journal_page.dart`, `patient_detail_page.dart`, `brainstorming_nurse_page.dart`, `reset_password_page.dart`, `consent_pages.dart`, `profile_mother_detail_page.dart`, `profile_infant_detail_page.dart`, `activate_page.dart`, `register_page.dart`, `nurse_shell_4.dart`, `pretest_page.dart`, `posttest_page.dart`, `contact_researchers_page.dart`, `patient_shell.dart`, `quiz_page.dart`, `privacy_policy_page.dart`, `modules_page.dart`, `forgot_password_page.dart`, `father_link_page.dart`, `modules_page.dart`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **What connects `navigatorKey`, `scaffoldMessengerKey`, `build` to the rest of the system?**
  _1354 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `profile_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04591836734693878 - nodes in this community are weakly interconnected._
- **Why does `Firebase Integration` connect `Generasi Emas App` to `fcm_service.dart`, `main.dart`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Should `home_patient_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.047619047619047616 - nodes in this community are weakly interconnected._
- **Why does `Generasi Emas App` connect `Generasi Emas App` to `dependencies`, `manifest.json`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Should `api_client.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.018867924528301886 - nodes in this community are weakly interconnected._