import 'package:flutter/material.dart';
import 'pages/splash_page.dart';
import 'pages/start_page.dart';
import 'pages/register_page.dart';
import 'pages/consent_pages.dart';
import 'pages/activate_page.dart';
import 'pages/login_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/pretest_page.dart';
import 'pages/brainstorming_page.dart';
import 'pages/quiz_page.dart';
import 'pages/logbook_page.dart';
import 'pages/notifications_page.dart';
import 'pages/baby_journal_page.dart';
import 'pages/posttest_page.dart';
import 'pages/references_page.dart';
import 'pages/contact_researchers_page.dart';
import 'pages/modules_page.dart';
import 'pages/profile_page.dart';
import 'pages/nurse/folder_nurse_page.dart';
import 'pages/nurse/brainstorming_nurse_page.dart';
import 'pages/nurse/nurse_agg_page.dart';
import 'pages/nurse/patient_detail_page.dart';
import 'pages/nurse/quiz_nurse_page.dart';
import 'shells/patient_shell.dart';
import 'shells/nurse_shell_4.dart';
import 'pages/profile_mother_detail_page.dart';
import 'pages/profile_infant_detail_page.dart';
import 'pages/father_link_page.dart';

// [BARU] Import Privacy Policy Page
import 'pages/privacy_policy_page.dart';

class Routes {
  // Patient
  static const splash = '/';
  static const start = '/start';
  static const register = '/register';

  // Consent
  static const consentReadOnly = '/consent';
  static const consentRegister = '/consent/register';
  static const consent = consentReadOnly;

  // [BARU] Privacy Policy Route
  static const privacyPolicy = '/privacy-policy';

  static const activate = '/activate';
  static const login = '/login';
  static const forgot = '/forgot';
  static const reset = '/reset';
  static const homePatient = '/homePatient';
  static const pretest = '/pretest';
  static const brainstorming = '/brainstorming';
  static const quiz = '/quiz';
  static const logbook = '/logbook';
  static const notifications = '/notifications';
  static const babyJournal = '/babyJournal';
  static const posttest = '/posttest';
  static const references = '/references';
  static const contactResearchers = '/contactResearchers';
  static const modules = '/modules';
  static const profile = '/profile';
  static const profileMotherDetail = '/profile/mother-detail';
  static const profileInfantDetail = '/profile/infant-detail';
  static const fatherLink = '/father/link';

  // Nurse
  static const nurseHome = '/nurse/home';
  static const nurseFolder = '/nurse/folder';
  static const nurseBrainstorm = '/nurse/brainstorm';
  static const nurseAgg = '/nurse/agg';
  static const nursePatientDetail = '/nurse/patientDetail';
  static const nurseQuiz = '/nurse/quiz';

  // Shells
  static const patientShell = '/patient-shell';
  static const nurseShell4 = '/nurse-shell';

  static Route<dynamic> onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());

      case start:
        return MaterialPageRoute(builder: (_) => const StartPage(), settings: s);

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case consentReadOnly:
        return MaterialPageRoute(builder: (_) => const ConsentReadOnlyPage());

      case consentRegister:
        return MaterialPageRoute(
          builder: (_) => const ConsentRegisterPage(),
          settings: s,
        );

    // [BARU] Register Privacy Policy Route
      case privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyPage());

      case activate:
        return MaterialPageRoute(builder: (_) => const ActivatePage());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage(), settings: s);

      case forgot:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      case reset:
        final args = s.arguments;
        String? token;
        String? presetPhone;
        if (args is String) {
          token = args;
        } else if (args is Map) {
          final m = args.cast<String, dynamic>();
          token = m['token'] as String?;
          presetPhone = m['presetPhone'] as String?;
        }
        return MaterialPageRoute(
          builder: (_) => ResetPasswordPage(token: token, presetPhone: presetPhone),
        );

      case homePatient:
        return MaterialPageRoute(builder: (_) => const PatientShell());

      case pretest:
        return MaterialPageRoute(builder: (_) => const PretestPage());

      case brainstorming:
        return MaterialPageRoute(builder: (_) => const BrainstormingPage());

      case quiz:
        return MaterialPageRoute(builder: (_) => const QuizPage());

      case logbook:
        return MaterialPageRoute(builder: (_) => const LogbookPage());

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());

      case babyJournal:
        return MaterialPageRoute(builder: (_) => const BabyJournalPage());

      case posttest:
        return MaterialPageRoute(builder: (_) => const PosttestPage());

      case references:
        return MaterialPageRoute(builder: (_) => const ReferencesPage());

      case modules:
        return MaterialPageRoute(builder: (_) => const ModulesPage(), settings: s);

      case contactResearchers:
        return MaterialPageRoute(builder: (_) => const ContactResearchersPage(), settings: s);

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      case profileMotherDetail:
        return MaterialPageRoute(builder: (_) => const ProfileMotherDetailPage());

      case profileInfantDetail:
        return MaterialPageRoute(builder: (_) => const ProfileInfantDetailPage());

      case fatherLink:
        return MaterialPageRoute(builder: (_) => const FatherLinkPage());

      case nurseHome:
        return MaterialPageRoute(builder: (_) => const NurseShell4());

      case nurseFolder:
        return MaterialPageRoute(builder: (_) => const FolderNursePage());

      case nurseBrainstorm:
        return MaterialPageRoute(builder: (_) => const BrainstormingNursePage());

      case nurseAgg:
        return MaterialPageRoute(builder: (_) => const NurseAggPage());

      case nursePatientDetail:
        return MaterialPageRoute(
          builder: (_) => const PatientDetailPage(),
          settings: s,
        );

      case nurseQuiz:
        return MaterialPageRoute(builder: (_) => const QuizNursePage());

      case patientShell:
        final idxP = (s.arguments is Map && (s.arguments as Map)['index'] is int)
            ? (s.arguments as Map)['index'] as int
            : 0;
        return MaterialPageRoute(
          builder: (_) => PatientShell(initialIndex: idxP),
          settings: s,
        );

      case nurseShell4:
        final idxN = (s.arguments is Map && (s.arguments as Map)['index'] is int)
            ? (s.arguments as Map)['index'] as int
            : 0;
        return MaterialPageRoute(
          builder: (_) => NurseShell4(initialIndex: idxN),
          settings: s,
        );

      default:
        return MaterialPageRoute(builder: (_) => const StartPage(), settings: s);
    }
  }
}