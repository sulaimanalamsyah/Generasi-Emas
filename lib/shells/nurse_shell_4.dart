import 'package:material_ui/material_ui.dart';

import '../pages/nurse/home_nurse_page.dart';
import '../pages/nurse/nurse_agg_page.dart';
import '../pages/nurse/folder_nurse_page.dart';
import '../pages/nurse/quiz_nurse_page.dart';
import '../widgets/common.dart';
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
    KeepAliveWrapper(child: HomeNursePage()),
    KeepAliveWrapper(child: NurseAggPage()),
    KeepAliveWrapper(child: FolderNursePage()),
    KeepAliveWrapper(child: QuizNursePage()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
    );
  }
}
