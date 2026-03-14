import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../reservations/application/reservation_app_service.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../reservations/presentation/new_reservation_page.dart';
import '../../schedule/presentation/schedule_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    required this.section,
    required this.apiClient,
    required this.reservationAppService,
    super.key,
  });

  final AppSection section;
  final ApiClient apiClient;
  final ReservationAppService reservationAppService;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late AppSection _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.section;
  }

  @override
  void didUpdateWidget(covariant ShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _selectedSection = widget.section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compactLayout = MediaQuery.of(context).size.width < 960;
    final Widget content = _buildContent();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFE9F5F1),
              Color(0xFFF7F0D8),
              Color(0xFFE8EEF6),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -80,
              left: -60,
              child: _GlowOrb(color: const Color(0x55167D85), diameter: 220),
            ),
            Positioned(
              bottom: -110,
              right: -70,
              child: _GlowOrb(color: const Color(0x44E09F3E), diameter: 280),
            ),
            SafeArea(
              child: compactLayout
                  ? _CompactShell(
                      section: _selectedSection,
                      onSectionSelected: _goToSection,
                      content: content,
                    )
                  : _DesktopShell(
                      section: _selectedSection,
                      onSectionSelected: _goToSection,
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
      case AppSection.dashboard:
        return DashboardPage(apiClient: widget.apiClient);
      case AppSection.schedule:
        return SchedulePage(
          reservationAppService: widget.reservationAppService,
        );
      case AppSection.newReservation:
        return NewReservationPage(
          reservationAppService: widget.reservationAppService,
        );
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
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.section,
    required this.onSectionSelected,
    required this.content,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;
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
                  color: Colors.white.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _NavigationPanel(
                  section: section,
                  onSectionSelected: onSectionSelected,
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
                    color: Colors.white.withValues(alpha: 0.84),
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
    required this.onSectionSelected,
    required this.content,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: <Widget>[
          _CompactTopBar(
            section: section,
            onSectionSelected: onSectionSelected,
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
                    color: Colors.white.withValues(alpha: 0.86),
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
    required this.onSectionSelected,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 26, 18, 20),
          child: _BrandHeader(),
        ),
        Expanded(
          child: NavigationRail(
            selectedIndex: section.index,
            labelType: NavigationRailLabelType.all,
            minExtendedWidth: 230,
            extended: true,
            onDestinationSelected: (int index) {
              onSectionSelected(AppSection.values[index]);
            },
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: Text('Resumen'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: Text('Agenda diaria'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.add_box_outlined),
                selectedIcon: Icon(Icons.add_box_rounded),
                label: Text('Nueva reserva'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.section,
    required this.onSectionSelected,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: <Widget>[
              const _BrandHeader(compact: true),
              const SizedBox(height: 10),
              SegmentedButton<AppSection>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<AppSection>>[
                  ButtonSegment<AppSection>(
                    value: AppSection.dashboard,
                    label: Text('Resumen'),
                    icon: Icon(Icons.dashboard_outlined),
                  ),
                  ButtonSegment<AppSection>(
                    value: AppSection.schedule,
                    label: Text('Agenda'),
                    icon: Icon(Icons.event_note_outlined),
                  ),
                  ButtonSegment<AppSection>(
                    value: AppSection.newReservation,
                    label: Text('Reserva'),
                    icon: Icon(Icons.playlist_add_rounded),
                  ),
                ],
                selected: <AppSection>{section},
                onSelectionChanged: (Set<AppSection> selectedSet) {
                  onSectionSelected(selectedSet.first);
                },
              ),
            ],
          ),
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
          child: const Icon(
            Icons.sports_tennis_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('COSTANORTE', style: headlineStyle),
            Text(
              'Reservas internas del hotel',
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
