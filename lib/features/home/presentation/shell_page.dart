import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/costa_norte_logo.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../courts/application/court_app_service.dart';
import '../../massages/application/massage_app_service.dart';
import '../../massages/presentation/massage_booking_page.dart';
import '../../reservations/application/reservation_app_service.dart';
import '../../settings/presentation/settings_page.dart';
import '../../tennis/presentation/tennis_rental_page.dart';
import '../../tours/presentation/tours_travel_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    required this.section,
    required this.sessionController,
    required this.massageAppService,
    required this.reservationAppService,
    required this.courtAppService,
    super.key,
  });

  final AppSection section;
  final SessionController sessionController;
  final MassageAppService massageAppService;
  final ReservationAppService reservationAppService;
  final CourtAppService courtAppService;

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
          gradient: CostaNorteBrand.ambientGradient,
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -30,
              right: -180,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    'assets/branding/costanorte_hero.jpg',
                    width: 720,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -40,
              child: _GlowOrb(
                color: CostaNorteBrand.royalBlue.withValues(alpha: 0.12),
                diameter: 260,
              ),
            ),
            Positioned(
              bottom: -110,
              right: -70,
              child: _GlowOrb(
                color: CostaNorteBrand.gold.withValues(alpha: 0.15),
                diameter: 320,
              ),
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
        return MassageBookingPage(massageAppService: widget.massageAppService);
      case AppSection.tennisRental:
        return TennisRentalPage(courtAppService: widget.courtAppService);
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
          _GlassPanel(
            width: 302,
            child: _NavigationPanel(
              section: section,
              session: session,
              onSectionSelected: onSectionSelected,
              onLogout: onLogout,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _GlassPanel(
              padding: const EdgeInsets.all(26),
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
            child: _GlassPanel(
              padding: const EdgeInsets.all(18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey<AppSection>(section),
                  child: SingleChildScrollView(child: content),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.width, this.padding});

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: CostaNorteBrand.line),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
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
          padding: EdgeInsets.fromLTRB(18, 24, 18, 18),
          child: _BrandHeader(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: _SessionCard(session: session),
        ),
        Expanded(
          child: NavigationRail(
            selectedIndex: section.index,
            minExtendedWidth: 236,
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
                label: Text('Configuracoes'),
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
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  color: selected
                      ? Colors.white
                      : CostaNorteBrand.royalBlueDeep,
                ),
                selected: selected,
                onSelected: (_) => onSectionSelected(item),
                selectedColor: CostaNorteBrand.royalBlue,
                backgroundColor: Colors.white,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? Colors.white
                      : CostaNorteBrand.royalBlueDeep,
                ),
                side: const BorderSide(color: CostaNorteBrand.line),
              );
            }).toList(),
          ),
        ],
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

    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: CostaNorteBrand.foam,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sessao ativa',
            style: textTheme.labelLarge?.copyWith(
              color: CostaNorteBrand.mutedInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            activeSession.username,
            style: textTheme.titleLarge?.copyWith(color: CostaNorteBrand.ink),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[_SessionPill(label: 'Acesso autorizado')],
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
        gradient: CostaNorteBrand.goldAccentGradient,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: CostaNorteBrand.charcoal),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                CostaNorteBrand.royalBlueNight,
                CostaNorteBrand.royalBlueDeep,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CostaNorteLogo(width: compact ? 138 : 184),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: CostaNorteBrand.gold.withValues(alpha: 0.18),
          ),
          child: Text(
            'Hotel Costa Norte',
            style: textTheme.labelMedium?.copyWith(
              color: CostaNorteBrand.charcoal,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Servicos internos do hotel',
          style: textTheme.bodySmall?.copyWith(color: CostaNorteBrand.mutedInk),
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
