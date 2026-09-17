import 'package:flutter/material.dart';

class AppNotificationsScreen extends StatelessWidget {
  const AppNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AppSettingsPage(
      title: 'App notifications',
      showMore: false,
      rows: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('On', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w400, color: Color(0xFF1F2937)))),
            AppToggle(enabled: true),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Categories', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Color(0xFF1E9AD6))),
        const SizedBox(height: 26),
        const Padding(
          padding: EdgeInsets.only(left: 6),
          child: Text(
            'This app has not posted any\nnotifications',
            style: TextStyle(fontSize: 22, height: 1.4, color: Color(0xFF8A96A3), fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

class AppPermissionsScreen extends StatelessWidget {
  const AppPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AppSettingsPage(
      title: 'App permissions',
      showMore: true,
      rows: [
        const SizedBox(height: 14),
        _PermissionRow(label: 'Location', icon: Icons.location_on_outlined, enabled: true),
        const SizedBox(height: 10),
        _PermissionRow(label: 'SMS', icon: Icons.sms_outlined, enabled: true),
      ],
    );
  }
}

class _AppSettingsPage extends StatelessWidget {
  const _AppSettingsPage({
    required this.title,
    required this.rows,
    required this.showMore,
  });

  final String title;
  final List<Widget> rows;
  final bool showMore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: const Color(0xFFF2F3F5),
              child: Row(
                children: [
                  IconButton(
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 32, color: Color(0xFF1E9AD6)),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E9AD6),
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),
                  if (showMore)
                    IconButton(
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_vert_rounded, size: 30, color: Color(0xFF1F2937)),
                      onPressed: () {},
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF2F3F5),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    const BudgetaAppHeader(),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rows,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      color: const Color(0xFFF2F3F5),
                      padding: const EdgeInsets.only(bottom: 18),
                      child: const _AndroidNavBar(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetaAppHeader extends StatelessWidget {
  const BudgetaAppHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BudgetaLogo(size: 82),
          const SizedBox(width: 14),
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Budgeta',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w400, color: Color(0xFF1F2937), letterSpacing: -0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.icon, required this.enabled});

  final String label;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD9DEE3), width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF1F2937)),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Color(0xFF1F2937)),
            ),
          ),
          AppToggle(enabled: enabled),
        ],
      ),
    );
  }
}

class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: 58,
      height: 30,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF35B1F1) : const Color(0xFFD9DEE3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x29000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

class BudgetaLogo extends StatelessWidget {
  const BudgetaLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BudgetaLogoPainter(),
      ),
    );
  }
}

class _BudgetaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E9AD6);
    final path = Path();

    path.moveTo(size.width * 0.26, size.height * 0.12);
    path.lineTo(size.width * 0.74, size.height * 0.12);
    path.lineTo(size.width * 0.86, size.height * 0.34);
    path.lineTo(size.width * 0.63, size.height * 0.34);
    path.lineTo(size.width * 0.47, size.height * 0.52);
    path.lineTo(size.width * 0.83, size.height * 0.52);
    path.lineTo(size.width * 0.66, size.height * 0.71);
    path.lineTo(size.width * 0.18, size.height * 0.71);
    path.lineTo(size.width * 0.18, size.height * 0.26);
    path.close();

    canvas.drawPath(path, paint);

    final cut = Path();
    cut.moveTo(size.width * 0.46, size.height * 0.28);
    cut.lineTo(size.width * 0.54, size.height * 0.28);
    cut.lineTo(size.width * 0.54, size.height * 0.84);
    cut.lineTo(size.width * 0.46, size.height * 0.84);
    cut.close();
    canvas.drawPath(cut, Paint()..color = const Color(0xFFF2F3F5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AndroidNavBar extends StatelessWidget {
  const _AndroidNavBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        Icon(Icons.arrow_back_ios_new_rounded, size: 42, color: Color(0xFF1F2937)),
        SizedBox(width: 10),
        Icon(Icons.circle_outlined, size: 50, color: Color(0xFF1F2937)),
        SizedBox(width: 10),
        Icon(Icons.crop_square_rounded, size: 42, color: Color(0xFF1F2937)),
      ],
    );
  }
}
