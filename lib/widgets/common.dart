import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/storage.dart';
import '../routes.dart';

/// Shared high-contrast light system bar overlay style (dark status & nav bar icons on light surfaces).
const SystemUiOverlayStyle kLightSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Color(0xFFE2E8F0),
);

/// Preset salutations available for Nurses. Empty string `''` represents `Tanpa Gelar`.
const List<Map<String, String>> kNurseSalutationOptions = [
  {'value': 'Ns.', 'label': 'Ns.', 'description': 'Ners (Keperawatan)'},
  {'value': 'Dr.', 'label': 'Dr.', 'description': 'Dokter'},
  {'value': 'Bd.', 'label': 'Bd.', 'description': 'Bidan'},
  {'value': '', 'label': 'Tanpa Gelar', 'description': 'Tampilkan nama tanpa gelar'},
];

/// Formats a nurse's display name according to finalized salutation rules:
/// - `salutation == null`: defaults to `'Ns.'`
/// - `salutation == ''` (`Tanpa Gelar`): omits prefix cleanly (`'<Name>'`)
/// - Prevents double-prefixing if [rawName] already begins with a known title.
String formatNurseDisplayName(String? rawName, String? salutation) {
  final cleanName = (rawName ?? '').trim();
  if (cleanName.isEmpty) return 'Perawat';

  final effectiveSalutation = salutation == null ? 'Ns.' : salutation.trim();
  if (effectiveSalutation.isEmpty) {
    return cleanName;
  }

  final lower = cleanName.toLowerCase();
  if (lower.startsWith('ns.') ||
      lower.startsWith('dr.') ||
      lower.startsWith('bd.') ||
      lower.startsWith('ners ')) {
    return cleanName;
  }
  return '$effectiveSalutation $cleanName';
}

/// Safe bottom padding for modal bottom sheets accounting for both keyboard and OS navigation bar insets.
EdgeInsets sheetBottomPadding(BuildContext context, {double horizontal = 20, double top = 16, double extra = 20}) {
  final mq = MediaQuery.of(context);
  final insetBottom = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, insetBottom + extra);
}

class AppLogo extends StatelessWidget {
  final double? size;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 96,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.health_and_safety,
          size: size ?? 64,
          color: const Color(0xFF10B981),
        );
      },
    );
  }
}

/// Unified ENICare top AppBar enforcing dark OS status icons, white surface, and clean ellipsis overflow.
PreferredSizeWidget enicareAppBar(
  BuildContext context, {
  required String title,
  bool showLogo = false,
  bool showBackButton = true,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    systemOverlayStyle: kLightSystemUiOverlayStyle,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    foregroundColor: const Color(0xFF0F172A),
    elevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: false,
    leadingWidth: showLogo ? 54 : (showBackButton ? 48 : 0),
    leading: showLogo
        ? const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Center(child: AppLogo(size: 30)),
          )
        : (showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Kembali',
              )
            : null),
    titleSpacing: showLogo || showBackButton ? 8 : 20,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: Color(0xFF0F172A),
      ),
    ),
    actions: actions,
    bottom: bottom ??
        const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        ),
  );
}

PreferredSizeWidget commonAppBar(
  String title, {
  List<Widget>? actions,
  bool showLogo = true,
}) =>
    AppBar(
      systemOverlayStyle: kLightSystemUiOverlayStyle,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF0F172A),
        ),
      ),
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: const Color(0xFF0F172A),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      ),
      automaticallyImplyLeading: false,
      leadingWidth: showLogo ? 54 : 0,
      titleSpacing: showLogo ? 8 : 20,
      leading: showLogo
          ? const Padding(padding: EdgeInsets.only(left: 16), child: Center(child: AppLogo(size: 30)))
          : null,
      actions: actions,
    );

PreferredSizeWidget evaluationAppBar({
  required BuildContext context,
  required String title,
  VoidCallback? onRefresh,
  bool showBackButton = true,
}) =>
    enicareAppBar(
      context,
      title: title,
      showLogo: false,
      showBackButton: showBackButton,
      actions: [
        if (onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: onRefresh,
            tooltip: 'Muat Ulang Data',
          ),
      ],
    );

enum InfoDialogVariant { success, error, info, warning }

/// Unified ENICare informational / alert dialog with max-font scroll safety & 48dp touch targets.
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
  InfoDialogVariant? variant,
  String buttonLabel = 'OK',
}) {
  final resolved = variant ?? (isError ? InfoDialogVariant.error : InfoDialogVariant.success);
  Color accent;
  Color badgeBg;
  IconData icon;
  switch (resolved) {
    case InfoDialogVariant.error:
      accent = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFFEE2E2);
      icon = Icons.error_outline_rounded;
      break;
    case InfoDialogVariant.warning:
      accent = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFEF3C7);
      icon = Icons.warning_amber_rounded;
      break;
    case InfoDialogVariant.info:
      accent = const Color(0xFF0284C7);
      badgeBg = const Color(0xFFE0F2FE);
      icon = Icons.info_outline_rounded;
      break;
    case InfoDialogVariant.success:
      accent = const Color(0xFF059669);
      badgeBg = const Color(0xFFD1FAE5);
      icon = Icons.check_circle_outline_rounded;
      break;
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: accent,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF475569),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Unified ENICare confirmation dialog returning `true` when confirmed.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya, Lanjutkan',
  String cancelLabel = 'Batal',
  bool isDestructive = false,
}) async {
  final accent = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF10B981);
  final badgeBg = isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);
  final icon = isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded;

  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Builder(
          builder: (actionCtx) {
            final isLargeText = MediaQuery.textScalerOf(actionCtx).scale(14) > 18;
            final cancelBtn = OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(88, 48),
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                cancelLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
            );
            final confirmBtn = FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(104, 48),
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                confirmLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
              ),
            );

            if (isLargeText) {
              return SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    confirmBtn,
                    const SizedBox(height: 8),
                    cancelBtn,
                  ],
                ),
              );
            }

            return SizedBox(
              width: double.infinity,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cancelBtn),
                    const SizedBox(width: 10),
                    Expanded(child: confirmBtn),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
  return res == true;
}

/// Clears Guest session state and returns cleanly to [StartPage].
Future<void> exitGuestMode(BuildContext context) async {
  await Prefs.clearAll();
  if (!context.mounted) return;
  Navigator.pushNamedAndRemoveUntil(context, Routes.start, (_) => false);
}

/// Consistent Guest Mode gate modal directing Guest users toward Login or Account Registration.
Future<void> showGuestGateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
            child: const Icon(Icons.lock_person_rounded, color: Color(0xFF059669), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Fitur Khusus Pengguna Terdaftar',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Text(
          'Silakan masuk atau daftar akun ENICare terlebih dahulu untuk mengakses fitur pemantauan bayi, Logbook Ibu, Jurnal Bayi, notifikasi, dan evaluasi secara lengkap.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.register);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Daftar Sekarang',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.login);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Masuk',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Nanti Saja',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void showAppSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Compact runtime App Version footer reading version & build number from `package_info_plus`.
class AppVersionFooter extends StatefulWidget {
  const AppVersionFooter({super.key});

  @override
  State<AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<AppVersionFooter> {
  String _label = 'ENI Care • Versi 1.0.0 (Build 1)';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      final build = info.buildNumber.trim().isEmpty ? '1' : info.buildNumber;
      setState(() {
        _label = 'ENI Care • Versi ${info.version} (Build $build)';
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        _label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

/// Shared wrapper to keep widget state alive across tabs without full rebuilds.
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Option item model used by [showEnicareOptionSheet].
class EnicarePickerOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;

  const EnicarePickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
  });
}

/// Opens a unified ENICare modal bottom sheet option picker aligned with `DESIGN.md`.
/// Fires [onSelected] only when an option is explicitly tapped (never on scrim dismissal),
/// making nullable option values (e.g. `null` for "Semua Bulan") unambiguous.
Future<T?> showEnicareOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<EnicarePickerOption<T>> options,
  T? selectedValue,
  ValueChanged<T>? onSelected,
}) async {
  final chosen = await showModalBottomSheet<EnicarePickerOption<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final maxListHeight = MediaQuery.sizeOf(ctx).height * 0.55;
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: sheetBottomPadding(ctx, horizontal: 20, top: 12, extra: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Tutup',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final opt = options[idx];
                  final selected = selectedValue == opt.value && !opt.isDestructive;
                  final Color borderColor = opt.isDestructive
                      ? const Color(0xFFFECACA)
                      : (selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0));
                  final Color bgColor = opt.isDestructive
                      ? const Color(0xFFFEF2F2)
                      : (selected ? const Color(0xFFECFDF5) : Colors.white);
                  final Color titleColor = opt.isDestructive
                      ? const Color(0xFFDC2626)
                      : (selected ? const Color(0xFF065F46) : const Color(0xFF0F172A));

                  return Material(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, opt),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            if (opt.icon != null) ...[
                              Icon(
                                opt.icon,
                                size: 20,
                                color: opt.iconColor ??
                                    (opt.isDestructive
                                        ? const Color(0xFFEF4444)
                                        : (selected ? const Color(0xFF059669) : const Color(0xFF64748B))),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: selected || opt.isDestructive ? FontWeight.w700 : FontWeight.w600,
                                      color: titleColor,
                                    ),
                                  ),
                                  if (opt.subtitle != null && opt.subtitle!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      opt.subtitle!,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!opt.isDestructive) ...[
                              const SizedBox(width: 8),
                              Icon(
                                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 20,
                                color: selected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  if (chosen != null) {
    onSelected?.call(chosen.value);
    return chosen.value;
  }
  return null;
}

/// Cohesive ENICare picker input field with max-font wrapping & minimum 48dp target.
class EnicarePickerField extends StatelessWidget {
  final String? label;
  final String displayText;
  final VoidCallback? onTap;
  final bool isActive;
  final bool enabled;
  final IconData? leadingIcon;

  const EnicarePickerField({
    super.key,
    this.label,
    required this.displayText,
    this.onTap,
    this.isActive = false,
    this.enabled = true,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = !enabled
        ? const Color(0xFFF8FAFC)
        : (isActive ? const Color(0xFFECFDF5) : Colors.white);
    final borderColor = !enabled
        ? const Color(0xFFE2E8F0)
        : (isActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1));
    final textColor = !enabled
        ? const Color(0xFF64748B)
        : (isActive ? const Color(0xFF065F46) : const Color(0xFF0F172A));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 18,
                  color: isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null && label!.trim().isNotEmpty) ...[
                      Text(
                        label!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      displayText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared date picker wrapper aligned with ENICare Indonesian localization and theme.
Future<DateTime?> showEnicareDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText ?? 'Pilih Tanggal',
    cancelText: 'Batal',
    confirmText: 'Pilih',
    locale: const Locale('id', 'ID'),
  );
}

/// Returns whether [candidate] matches the currently viewed library item.
/// Prefers stable IDs when present and otherwise compares title and URL together.
bool isSameLibraryItem({
  String? currentId,
  required String currentTitle,
  required String currentUrl,
  required Map<String, dynamic> candidate,
}) {
  final candId = candidate['id']?.toString().trim();
  final curId = currentId?.trim();
  if (curId != null && curId.isNotEmpty && candId != null && candId.isNotEmpty) {
    return candId == curId;
  }
  final candTitle = (candidate['title'] ?? '').toString().trim();
  final candUrl = (candidate['url'] ?? '').toString().trim();
  return candTitle == currentTitle.trim() && candUrl == currentUrl.trim();
}

/// Lays out 2 or 3 action buttons with equal height ([IntrinsicHeight]),
/// adapting cleanly at high system font scales to avoid uneven boxes or clipping.
class ResponsiveActionButtonBar extends StatelessWidget {
  final List<Widget> actions;
  final double largeTextThreshold;

  const ResponsiveActionButtonBar({
    super.key,
    required this.actions,
    this.largeTextThreshold = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final isLargeText = MediaQuery.textScalerOf(context).scale(13) > largeTextThreshold;

    if (isLargeText) {
      if (actions.length == 3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 8),
                  Expanded(child: actions[1]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            actions[2],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            actions[i],
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: actions[i]),
          ],
        ],
      ),
    );
  }
}

/// Framed document/PDF viewport with an explicit page-vs-document scroll lock
/// so scrolling past an embedded WebView never traps vertical swipes.
class EnicareReaderSectionFrame extends StatelessWidget {
  final bool isInteractive;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onToggleInteractive;
  final Widget child;

  const EnicareReaderSectionFrame({
    super.key,
    required this.isInteractive,
    required this.isLoading,
    required this.hasError,
    required this.onToggleInteractive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isInteractive
                      ? 'Mode Gulir Dokumen Aktif'
                      : 'Gulir Halaman Aktif (Ketuk dokumen untuk menggulir isi)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isInteractive ? const Color(0xFF047857) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: OutlinedButton.icon(
                  onPressed: onToggleInteractive,
                  icon: Icon(
                    isInteractive ? Icons.lock_rounded : Icons.touch_app_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isInteractive ? 'Gulir Halaman' : 'Gulir Dokumen',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isInteractive ? const Color(0xFFECFDF5) : Colors.white,
                    foregroundColor: isInteractive ? const Color(0xFF047857) : const Color(0xFF334155),
                    side: BorderSide(
                      color: isInteractive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isInteractive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: isInteractive ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              child,
              if (!isInteractive && !isLoading && !hasError)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleInteractive,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0F172A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, size: 15, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Ketuk untuk Gulir Dokumen',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
