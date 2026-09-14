# Graph Report - .  (2026-07-31)

## Corpus Check
- 144 files · ~470,110 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 52 nodes · 83 edges · 9 communities (8 shown, 1 thin omitted)
- Extraction: 65% EXTRACTED · 35% INFERRED · 0% AMBIGUOUS · INFERRED: 29 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Onboarding & Supporting Pages
- Patient Education & Assessment
- Data Layer & Health Journaling
- App Core & Domain Mission
- Nurse Role & Patient Monitoring
- Firebase & Push Notifications
- Web Content Display
- Authentication Flow
- Shared UI Widgets

## God Nodes (most connected - your core abstractions)
1. `Routes` - 31 edges
2. `ApiClient` - 10 edges
3. `Generasi Emas App` - 9 edges
4. `HomePatientPage` - 9 edges
5. `PatientShell` - 6 edges
6. `NurseShell4` - 5 edges
7. `ProfilePage` - 5 edges
8. `PretestPage` - 4 edges
9. `PosttestPage` - 4 edges
10. `LogbookPage` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Generasi Emas App` --uses--> `App Visual Assets`  [EXTRACTED]
  pubspec.yaml → assets/icon.png
- `Generasi Emas App` --implements--> `Pre/Post Test Assessment System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --implements--> `Dual-Role User System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `Generasi Emas App` --implements--> `Health Journaling System`  [EXTRACTED]
  pubspec.yaml → lib/routes.dart
- `FcmService` --uses--> `Firebase Integration`  [EXTRACTED]
  lib/services/fcm_service.dart → pubspec.yaml

## Communities (9 total, 1 thin omitted)

### Community 0 - "Onboarding & Supporting Pages"
Cohesion: 0.18
Nodes (13): ActivatePage, ConsentPages, FatherLinkPage, ForgotPasswordPage, BrainstormingNursePage, QuizNursePage, PrivacyPolicyPage, ProfileInfantDetailPage (+5 more)

### Community 1 - "Patient Education & Assessment"
Cohesion: 0.32
Nodes (8): Pre/Post Test Assessment System, BrainstormingPage, ContactResearchersPage, HomePatientPage, PosttestPage, PretestPage, QuizPage, ReferencesPage

### Community 2 - "Data Layer & Health Journaling"
Cohesion: 0.32
Nodes (8): Health Journaling System, BabyJournalPage, LogbookPage, PatientDetailPage, RegisterPage, ApiClient, PatientShell, LoadingOverlay

### Community 3 - "App Core & Domain Mission"
Cohesion: 0.33
Nodes (6): App Visual Assets, Multi-Platform Flutter Build, Generasi Emas App, Project Dependencies, Stunting Education Mission, Web App Manifest (PWA)

### Community 4 - "Nurse Role & Patient Monitoring"
Cohesion: 0.40
Nodes (5): Dual-Role User System, FolderNursePage, HomeNursePage, NurseAggPage, NurseShell4

### Community 5 - "Firebase & Push Notifications"
Cohesion: 0.50
Nodes (4): Firebase Integration, GenerasiEmasApp, NotificationsPage, FcmService

### Community 6 - "Web Content Display"
Cohesion: 0.67
Nodes (3): InAppViewerPage, ModulesPage, WebformPage

### Community 7 - "Authentication Flow"
Cohesion: 0.67
Nodes (3): LoginPage, SplashPage, AuthService

## Knowledge Gaps
- **17 isolated node(s):** `StartPage`, `ConsentPages`, `PrivacyPolicyPage`, `ActivatePage`, `ForgotPasswordPage` (+12 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Routes` connect `Onboarding & Supporting Pages` to `Patient Education & Assessment`, `Data Layer & Health Journaling`, `Nurse Role & Patient Monitoring`, `Firebase & Push Notifications`, `Web Content Display`, `Authentication Flow`?**
  _High betweenness centrality (0.666) - this node is a cross-community bridge._
- **Why does `Generasi Emas App` connect `App Core & Domain Mission` to `Patient Education & Assessment`, `Data Layer & Health Journaling`, `Nurse Role & Patient Monitoring`, `Firebase & Push Notifications`?**
  _High betweenness centrality (0.204) - this node is a cross-community bridge._
- **Why does `Pre/Post Test Assessment System` connect `Patient Education & Assessment` to `App Core & Domain Mission`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `ApiClient` (e.g. with `BabyJournalPage` and `LogbookPage`) actually correct?**
  _`ApiClient` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `HomePatientPage` (e.g. with `BrainstormingPage` and `ContactResearchersPage`) actually correct?**
  _`HomePatientPage` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `PatientShell` (e.g. with `BabyJournalPage` and `LogbookPage`) actually correct?**
  _`PatientShell` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `StartPage`, `ConsentPages`, `PrivacyPolicyPage` to the rest of the system?**
  _17 weakly-connected nodes found - possible documentation gaps or missing edges._