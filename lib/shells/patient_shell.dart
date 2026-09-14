import 'package:flutter/material.dart';
import '../pages/home_patient_page.dart';
import '../pages/baby_journal_page.dart';
import '../pages/logbook_page.dart';
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
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              elevation: 0,
              height: 68,
              indicatorColor: const Color(0xFFD1FAE5),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Color(0xFF064E3B), size: 24);
                }
                return const IconThemeData(color: Color(0xFF64748B), size: 24);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF064E3B),
                  );
                }
                return const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onSelect,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Beranda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: 'Jurnal',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note_rounded),
                  label: 'Logbook',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
            ),
          ),
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
