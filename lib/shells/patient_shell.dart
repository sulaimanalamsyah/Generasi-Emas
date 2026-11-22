import 'package:material_ui/material_ui.dart';
import '../pages/home_patient_page.dart';
import '../pages/baby_journal_page.dart';
import '../pages/logbook_page.dart';
import '../pages/profile_page.dart';
import '../core/partner_sync.dart';
import '../core/storage.dart';
import '../widgets/common.dart';
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
  bool _isGuest = false;
  late final List<bool> _mountedTabs;

  static const _navItems = [
    _NavItem(label: 'Beranda', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _NavItem(label: 'Jurnal Bayi', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded),
    _NavItem(label: 'Logbook Ibu', icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note_rounded),
    _NavItem(label: 'Profil', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
    _mountedTabs = [
      _index == 0,
      _index == 1,
      _index == 2,
      _index == 3,
    ];
    _loadRole();
  }

  Future<void> _loadRole() async {
    final guest = await Prefs.isGuest();
    if (!mounted) return;
    setState(() {
      _isGuest = guest;
      if (_isGuest && (_index == 1 || _index == 2)) {
        _index = 0;
        _mountedTabs[0] = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['index'] is int) {
      final target = (args['index'] as int).clamp(0, 3);
      if (!(_isGuest && (target == 1 || target == 2))) {
        _index = target;
        _mountedTabs[target] = true;
      }
    }
  }

  void _onSelect(int i) {
    if (_isGuest && (i == 1 || i == 2)) {
      showGuestGateDialog(context);
      return;
    }
    if (i == _index) return;
    setState(() {
      _index = i;
      _mountedTabs[i] = true;
    });
    if (!_isGuest) {
      PartnerSync.notify();
    }
  }

  Widget _buildTab(int i) {
    if (!_mountedTabs[i]) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return const KeepAliveWrapper(child: HomePatientPage());
      case 1:
        return const KeepAliveWrapper(child: BabyJournalPage());
      case 2:
        return const KeepAliveWrapper(child: LogbookPage());
      case 3:
      default:
        return const KeepAliveWrapper(child: ProfilePage());
    }
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
        body: IndexedStack(
          index: _index,
          children: List<Widget>.generate(4, _buildTab),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final selected = _index == i;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _onSelect(i),
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFFD1FAE5) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  selected ? item.activeIcon : item.icon,
                                  size: 24,
                                  color: selected ? const Color(0xFF064E3B) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: selected ? 'Nunito' : 'Inter',
                                  fontSize: 12,
                                  height: 1.15,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  color: selected ? const Color(0xFF064E3B) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
}
