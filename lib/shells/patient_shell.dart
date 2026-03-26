import 'package:flutter/material.dart';
import '../pages/home_patient_page.dart';
import '../pages/baby_journal_page.dart';
import '../pages/logbook_page.dart';
import '../pages/contact_researchers_page.dart';
import '../pages/profile_page.dart';
import '../routes.dart';

class PatientShell extends StatefulWidget {
  final int initialIndex;
  const PatientShell({super.key, this.initialIndex = 0});

  static Future<void> go(BuildContext context, {int index = 0}) async {
    await Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.patientShell,
          (_) => false,
      arguments: {'index': index},
    );
  }

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  late int _index;

  final _tabs = const <Widget>[
    _KeepAlive(child: HomePatientPage()),
    _KeepAlive(child: BabyJournalPage()),
    _KeepAlive(child: LogbookPage()),
    _KeepAlive(child: ContactResearchersPage()),
    _KeepAlive(child: ProfilePage()),
  ];
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['index'] is int) {
      _index = (args['index'] as int).clamp(0, _tabs.length - 1);
    }
  }

  void _onSelect(int i) {
    if (i == _index) return; // cegah “nyangkut”
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) {
          // tekan back → kembali ke tab beranda
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onSelect,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Jurnal'),
            NavigationDestination(
                icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Logbook'),
            NavigationDestination(
                icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Kontak'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
