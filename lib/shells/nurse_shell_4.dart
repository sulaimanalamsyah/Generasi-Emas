import 'package:flutter/material.dart';
import 'dart:async';

// Ganti import halaman perawat sesuai struktur proyekmu
import '../pages/nurse/home_nurse_page.dart';
import '../pages/nurse/nurse_agg_page.dart';
import '../pages/nurse/folder_nurse_page.dart';
import '../pages/nurse/quiz_nurse_page.dart';
import '../routes.dart';

class NurseShell4 extends StatefulWidget {
  final int initialIndex;
  const NurseShell4({super.key, this.initialIndex = 0});

  static Future<void> go(BuildContext context, {int index = 0}) async {
    await Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.nurseShell4,
          (_) => false,
      arguments: {'index': index},
    );
  }

  @override
  State<NurseShell4> createState() => _NurseShell4State();
}

class _NurseShell4State extends State<NurseShell4> {
  late int _index;

  final _tabs = const <Widget>[
    _KeepAlive(child: HomeNursePage()),
    _KeepAlive(child: NurseAggPage()),
    _KeepAlive(child: FolderNursePage()),
    _KeepAlive(child: QuizNursePage()),
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
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onSelect,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.people_alt), label: 'Pasien'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'Folder'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Quiz'),
        ],
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
