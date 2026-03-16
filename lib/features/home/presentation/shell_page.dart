import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../massages/presentation/massage_booking_page.dart';
import '../../reservations/application/reservation_app_service.dart';
import '../../settings/presentation/settings_page.dart';
import '../../tennis/presentation/tennis_rental_page.dart';
import '../../tours/presentation/tours_travel_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    required this.section,
    required this.sessionController,
    required this.reservationAppService,
    super.key,
  });

  final AppSection section;
  final SessionController sessionController;
  final ReservationAppService reservationAppService;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late AppSection _selectedSection;
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.section;
    widget.sessionController.addListener(_handleSessionChanged);
  }

  @override
  void didUpdateWidget(covariant ShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController.removeListener(_handleSessionChanged);
      widget.sessionController.addListener(_handleSessionChanged);
    }
    if (oldWidget.section != widget.section) {
      _selectedSection = widget.section;
    }
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_handleSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool compactLayout = MediaQuery.of(context).size.width < 960;
    final Widget content = _buildContent();
    final AuthSession? session = widget.sessionController.session;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF1E9DC),
              Color(0xFFE3F0EC),
              Color(0xFFF8F6EF),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -80,
              left: -60,
              child: _GlowOrb(color: const Color(0x55167D85), diameter: 260),
            ),
            Positioned(
              bottom: -120,
              right: -80,
              child: _GlowOrb(color: const Color(0x44E0B36A), diameter: 300),
            ),
            SafeArea(
              child: compactLayout
                  ? _CompactShell(
                      section: _selectedSection,
                      session: session,
                      onSectionSelected: _goToSection,
                      onLogout: _logout,
                      content: content,
                    )
                  : _DesktopShell(
                      section: _selectedSection,
                      session: session,
                      onSectionSelected: _goToSection,
                      onLogout: _logout,
                      content: content,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case AppSection.massageBooking:
        return const MassageBookingPage();
      case AppSection.tennisRental:
        return TennisRentalPage(
          reservationAppService: widget.reservationAppService,
        );
      case AppSection.toursTravel:
        return const ToursTravelPage();
      case AppSection.settings:
        return SettingsPage(session: widget.sessionController.session);
    }
  }

  void _goToSection(AppSection section) {
    if (_selectedSection == section) {
      return;
    }

    setState(() {
      _selectedSection = section;
    });

    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.routeBySection(section));
  }

  void _logout() {
    widget.sessionController.clearSession();
  }

  void _handleSessionChanged() {
    if (widget.sessionController.isAuthenticated ||
        !mounted ||
        _redirectingToLogin) {
      return;
    }

    _redirectingToLogin = true;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.section,
    required this.session,
    required this.onSectionSelected,
    required this.onLogout,
    required this.content,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback onLogout;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _NavigationPanel(
                  section: section,
                  session: session,
                  onSectionSelected: onSectionSelected,
                  onLogout: onLogout,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey<AppSection>(section),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.section,
    required this.session,
    required this.onSectionSelected,
    required this.onLogout,
    required this.content,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback onLogout;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: <Widget>[
          _CompactTopBar(
            section: section,
            session: session,
            onSectionSelected: onSectionSelected,
            onLogout: onLogout,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey<AppSection>(section),
                      child: SingleChildScrollView(child: content),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.section,
    required this.session,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 26, 18, 20),
          child: _BrandHeader(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: _SessionCard(session: session),
        ),
        Expanded(
          child: NavigationRail(
            selectedIndex: section.index,
            minExtendedWidth: 230,
            extended: true,
            onDestinationSelected: (int index) {
              onSectionSelected(AppSection.values[index]);
            },
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.spa_outlined),
                selectedIcon: Icon(Icons.spa_rounded),
                label: Text('Massagens'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_tennis_outlined),
                selectedIcon: Icon(Icons.sports_tennis_rounded),
                label: Text('Quadras'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: Text('Tours e viagens'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: Text('Configurações'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.section,
    required this.session,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(child: _BrandHeader(compact: true)),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sair'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SessionCard(session: session, compact: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppSection.values.map((AppSection item) {
                  final bool selected = item == section;
                  return ChoiceChip(
                    label: Text(_labelForSection(item)),
                    avatar: Icon(
                      _iconForSection(item),
                      size: 18,
                      color: selected ? Colors.white : const Color(0xFF0F4C5C),
                    ),
                    selected: selected,
                    onSelected: (_) => onSectionSelected(item),
                    selectedColor: const Color(0xFF0F4C5C),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF0F4C5C),
                      fontWeight: FontWeight.w700,
                    ),
                    side: const BorderSide(color: Color(0x1F0F4C5C)),
                    backgroundColor: Colors.white,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.compact = false});

  final AuthSession? session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AuthSession? activeSession = session;
    if (activeSession == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF0F7F6),
        border: Border.all(color: const Color(0x1F167D85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sessão ativa',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF4D6574),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            activeSession.username,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0A3440),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[_SessionPill(label: 'Acesso ativo')],
          ),
        ],
      ),
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF167D85),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle headlineStyle = Theme.of(context).textTheme.titleLarge!
        .copyWith(
          fontSize: compact ? 20 : 24,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0A3440),
          letterSpacing: 0.7,
        );

    return Row(
      children: <Widget>[
        Container(
          width: compact ? 34 : 44,
          height: compact ? 34 : 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF167D85), Color(0xFF3EA97A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.waves_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('COSTA NORTE', style: headlineStyle),
            Text(
              'Serviços e experiências',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF536477),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.diameter});

  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

String _labelForSection(AppSection section) {
  switch (section) {
    case AppSection.massageBooking:
      return 'Massagens';
    case AppSection.tennisRental:
      return 'Quadras';
    case AppSection.toursTravel:
      return 'Tours';
    case AppSection.settings:
      return 'Config.';
  }
}

IconData _iconForSection(AppSection section) {
  switch (section) {
    case AppSection.massageBooking:
      return Icons.spa_rounded;
    case AppSection.tennisRental:
      return Icons.sports_tennis_rounded;
    case AppSection.toursTravel:
      return Icons.explore_rounded;
    case AppSection.settings:
      return Icons.tune_rounded;
  }
}
