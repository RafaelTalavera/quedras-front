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

const double _desktopSidebarWidth = 302;
const double _desktopSidebarCompactHeight = 880;
const double _desktopSidebarTightHeight = 760;

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
  late final MassageBookingPageController _massageBookingPageController;
  late final TennisRentalPageController _tennisRentalPageController;
  late final Widget _massageBookingPage;
  late final Widget _tennisRentalPage;
  late final Widget _toursTravelPage;
  bool _redirectingToLogin = false;
  MassageBookingSection _selectedMassageSection =
      MassageBookingSection.selectedDay;
  TennisRentalSection _selectedTennisSection = TennisRentalSection.selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.section;
    _massageBookingPageController = MassageBookingPageController();
    _tennisRentalPageController = TennisRentalPageController();
    _massageBookingPage = MassageBookingPage(
      massageAppService: widget.massageAppService,
      controller: _massageBookingPageController,
      onSectionChanged: _handleMassageSectionChanged,
    );
    _tennisRentalPage = TennisRentalPage(
      courtAppService: widget.courtAppService,
      controller: _tennisRentalPageController,
      onSectionChanged: _handleTennisSectionChanged,
    );
    _toursTravelPage = const SingleChildScrollView(child: ToursTravelPage());
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
                      massageSection: _selectedMassageSection,
                      onMassageSectionSelected: _goToMassageSection,
                      tennisSection: _selectedTennisSection,
                      onTennisSectionSelected: _goToTennisSection,
                      onLogout: _logout,
                      content: content,
                    )
                  : _DesktopShell(
                      section: _selectedSection,
                      session: session,
                      onSectionSelected: _goToSection,
                      massageSection: _selectedMassageSection,
                      onMassageSectionSelected: _goToMassageSection,
                      tennisSection: _selectedTennisSection,
                      onTennisSectionSelected: _goToTennisSection,
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
    return IndexedStack(
      index: _selectedSection.index,
      children: <Widget>[
        _massageBookingPage,
        _tennisRentalPage,
        _toursTravelPage,
        SingleChildScrollView(
          child: SettingsPage(session: widget.sessionController.session),
        ),
      ],
    );
  }

  void _goToSection(AppSection section) {
    if (_selectedSection == section) {
      return;
    }

    setState(() {
      _selectedSection = section;
    });
  }

  Future<void> _goToTennisSection(TennisRentalSection section) async {
    if (_selectedSection != AppSection.tennisRental) {
      setState(() {
        _selectedSection = AppSection.tennisRental;
        _selectedTennisSection = section;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tennisRentalPageController.scrollToSection(section);
      });
      return;
    }

    setState(() {
      _selectedTennisSection = section;
    });
    await _tennisRentalPageController.scrollToSection(section);
  }

  Future<void> _goToMassageSection(MassageBookingSection section) async {
    if (_selectedSection != AppSection.massageBooking) {
      setState(() {
        _selectedSection = AppSection.massageBooking;
        _selectedMassageSection = section;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _massageBookingPageController.scrollToSection(section);
      });
      return;
    }

    setState(() {
      _selectedMassageSection = section;
    });
    await _massageBookingPageController.scrollToSection(section);
  }

  void _logout() {
    widget.sessionController.clearSession();
  }

  void _handleTennisSectionChanged(TennisRentalSection section) {
    if (!mounted || _selectedTennisSection == section) {
      return;
    }
    setState(() {
      _selectedTennisSection = section;
    });
  }

  void _handleMassageSectionChanged(MassageBookingSection section) {
    if (!mounted || _selectedMassageSection == section) {
      return;
    }
    setState(() {
      _selectedMassageSection = section;
    });
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
    required this.massageSection,
    required this.onMassageSectionSelected,
    required this.tennisSection,
    required this.onTennisSectionSelected,
    required this.onLogout,
    required this.content,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final MassageBookingSection massageSection;
  final ValueChanged<MassageBookingSection> onMassageSectionSelected;
  final TennisRentalSection tennisSection;
  final ValueChanged<TennisRentalSection> onTennisSectionSelected;
  final VoidCallback onLogout;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          _GlassPanel(
            width: _desktopSidebarWidth,
            child: _NavigationPanel(
              section: section,
              session: session,
              onSectionSelected: onSectionSelected,
              massageSection: massageSection,
              onMassageSectionSelected: onMassageSectionSelected,
              tennisSection: tennisSection,
              onTennisSectionSelected: onTennisSectionSelected,
              onLogout: onLogout,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _GlassPanel(
              padding: const EdgeInsets.all(26),
              child: content,
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
    required this.massageSection,
    required this.onMassageSectionSelected,
    required this.tennisSection,
    required this.onTennisSectionSelected,
    required this.onLogout,
    required this.content,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final MassageBookingSection massageSection;
  final ValueChanged<MassageBookingSection> onMassageSectionSelected;
  final TennisRentalSection tennisSection;
  final ValueChanged<TennisRentalSection> onTennisSectionSelected;
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
            massageSection: massageSection,
            onMassageSectionSelected: onMassageSectionSelected,
            tennisSection: tennisSection,
            onTennisSectionSelected: onTennisSectionSelected,
            onLogout: onLogout,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _GlassPanel(
              padding: const EdgeInsets.all(18),
              child: content,
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
    required this.massageSection,
    required this.onMassageSectionSelected,
    required this.tennisSection,
    required this.onTennisSectionSelected,
    required this.onLogout,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final MassageBookingSection massageSection;
  final ValueChanged<MassageBookingSection> onMassageSectionSelected;
  final TennisRentalSection tennisSection;
  final ValueChanged<TennisRentalSection> onTennisSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compactHeader =
            constraints.maxHeight < _desktopSidebarCompactHeight;
        final bool tightSidebar =
            constraints.maxHeight < _desktopSidebarTightHeight;
        final EdgeInsets headerPadding = EdgeInsets.fromLTRB(
          18,
          compactHeader ? 18 : 24,
          18,
          compactHeader ? 14 : 18,
        );
        final EdgeInsets sessionPadding = EdgeInsets.fromLTRB(
          18,
          0,
          18,
          tightSidebar ? 12 : 18,
        );
        final EdgeInsets logoutPadding = EdgeInsets.fromLTRB(
          18,
          0,
          18,
          tightSidebar ? 18 : 22,
        );

        return Column(
          children: <Widget>[
            Padding(
              padding: headerPadding,
              child: _BrandHeader(compact: compactHeader),
            ),
            Padding(
              padding: sessionPadding,
              child: _SessionCard(
                session: session,
                compact: compactHeader,
                showStatusPill: !tightSidebar,
              ),
            ),
            if (section == AppSection.massageBooking)
              Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, tightSidebar ? 12 : 14),
                child: _MassageSectionMenu(
                  selectedSection: massageSection,
                  onSelected: onMassageSectionSelected,
                  compact: compactHeader,
                  showDescription: !tightSidebar,
                ),
              ),
            if (section == AppSection.tennisRental)
              Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, tightSidebar ? 12 : 14),
                child: _TennisSectionMenu(
                  selectedSection: tennisSection,
                  onSelected: onTennisSectionSelected,
                  compact: compactHeader,
                  showDescription: !tightSidebar,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _DesktopSectionList(
                  section: section,
                  onSectionSelected: onSectionSelected,
                ),
              ),
            ),
            Padding(
              padding: logoutPadding,
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
      },
    );
  }
}

class _DesktopSectionList extends StatelessWidget {
  const _DesktopSectionList({
    required this.section,
    required this.onSectionSelected,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      itemCount: AppSection.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final AppSection item = AppSection.values[index];
        final bool selected = item == section;
        return _DesktopSectionButton(
          label: _labelForSection(item),
          icon: _iconForSection(item),
          selected: selected,
          onTap: () => onSectionSelected(item),
        );
      },
    );
  }
}

class _DesktopSectionButton extends StatelessWidget {
  const _DesktopSectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? CostaNorteBrand.gold.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.72),
            border: Border.all(
              color: selected
                  ? CostaNorteBrand.goldDeep.withValues(alpha: 0.24)
                  : CostaNorteBrand.line,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? CostaNorteBrand.royalBlue
                      : CostaNorteBrand.mist,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : CostaNorteBrand.royalBlueDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: selected
                        ? CostaNorteBrand.royalBlueNight
                        : CostaNorteBrand.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.section,
    required this.session,
    required this.onSectionSelected,
    required this.massageSection,
    required this.onMassageSectionSelected,
    required this.tennisSection,
    required this.onTennisSectionSelected,
    required this.onLogout,
  });

  final AppSection section;
  final AuthSession? session;
  final ValueChanged<AppSection> onSectionSelected;
  final MassageBookingSection massageSection;
  final ValueChanged<MassageBookingSection> onMassageSectionSelected;
  final TennisRentalSection tennisSection;
  final ValueChanged<TennisRentalSection> onTennisSectionSelected;
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
          if (section == AppSection.tennisRental) ...<Widget>[
            const SizedBox(height: 10),
            _TennisSectionMenu(
              selectedSection: tennisSection,
              onSelected: onTennisSectionSelected,
              compact: true,
            ),
          ],
          if (section == AppSection.massageBooking) ...<Widget>[
            const SizedBox(height: 10),
            _MassageSectionMenu(
              selectedSection: massageSection,
              onSelected: onMassageSectionSelected,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _MassageSectionMenu extends StatelessWidget {
  const _MassageSectionMenu({
    required this.selectedSection,
    required this.onSelected,
    this.compact = false,
    this.showDescription = true,
  });

  final MassageBookingSection selectedSection;
  final ValueChanged<MassageBookingSection> onSelected;
  final bool compact;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final BorderRadius borderRadius = BorderRadius.circular(compact ? 18 : 20);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: CostaNorteBrand.mist,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Menu de massagens',
            style: textTheme.titleSmall?.copyWith(
              color: CostaNorteBrand.royalBlueDeep,
            ),
          ),
          if (showDescription) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Acesso rapido a cada bloco da operacao.',
              style: textTheme.bodySmall,
            ),
          ],
          SizedBox(height: showDescription ? 12 : 10),
          ...MassageBookingSection.values.map((MassageBookingSection item) {
            final bool selected = item == selectedSection;
            return Padding(
              padding: EdgeInsets.only(bottom: compact ? 6 : 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: selected
                          ? CostaNorteBrand.foam
                          : Colors.white.withValues(alpha: 0.72),
                      border: Border.all(
                        color: selected
                            ? CostaNorteBrand.royalBlue.withValues(alpha: 0.22)
                            : CostaNorteBrand.line,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _iconForMassageSection(item),
                          size: 18,
                          color: selected
                              ? CostaNorteBrand.royalBlueDeep
                              : CostaNorteBrand.mutedInk,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _labelForMassageSection(item),
                            style: textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? CostaNorteBrand.royalBlueDeep
                                  : CostaNorteBrand.ink,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 18,
                          color: selected
                              ? CostaNorteBrand.royalBlueDeep
                              : CostaNorteBrand.mutedInk,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TennisSectionMenu extends StatelessWidget {
  const _TennisSectionMenu({
    required this.selectedSection,
    required this.onSelected,
    this.compact = false,
    this.showDescription = true,
  });

  final TennisRentalSection selectedSection;
  final ValueChanged<TennisRentalSection> onSelected;
  final bool compact;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final BorderRadius borderRadius = BorderRadius.circular(compact ? 18 : 20);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: CostaNorteBrand.mist,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Menu de quadras',
            style: textTheme.titleSmall?.copyWith(
              color: CostaNorteBrand.royalBlueDeep,
            ),
          ),
          if (showDescription) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Acesso rapido a cada bloco da operacao.',
              style: textTheme.bodySmall,
            ),
          ],
          SizedBox(height: showDescription ? 12 : 10),
          ...TennisRentalSection.values.map((TennisRentalSection item) {
            final bool selected = item == selectedSection;
            return Padding(
              padding: EdgeInsets.only(bottom: compact ? 6 : 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: selected
                          ? CostaNorteBrand.foam
                          : Colors.white.withValues(alpha: 0.72),
                      border: Border.all(
                        color: selected
                            ? CostaNorteBrand.royalBlue.withValues(alpha: 0.22)
                            : CostaNorteBrand.line,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _iconForTennisSection(item),
                          size: 18,
                          color: selected
                              ? CostaNorteBrand.royalBlueDeep
                              : CostaNorteBrand.mutedInk,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _labelForTennisSection(item),
                            style: textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? CostaNorteBrand.royalBlueDeep
                                  : CostaNorteBrand.ink,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 18,
                          color: selected
                              ? CostaNorteBrand.royalBlueDeep
                              : CostaNorteBrand.mutedInk,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    this.compact = false,
    this.showStatusPill = true,
  });

  final AuthSession? session;
  final bool compact;
  final bool showStatusPill;

  @override
  Widget build(BuildContext context) {
    final AuthSession? activeSession = session;
    if (activeSession == null) {
      return const SizedBox.shrink();
    }

    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 5,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: CostaNorteBrand.foam,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sessao ativa',
            style: textTheme.labelMedium?.copyWith(
              color: CostaNorteBrand.mutedInk,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 0.5),
          Text(
            activeSession.username,
            style: textTheme.titleSmall?.copyWith(
              color: CostaNorteBrand.ink,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (showStatusPill) ...<Widget>[
            const SizedBox(height: 1),
            const _SessionPill(label: 'Acesso autorizado', compact: true),
          ],
        ],
      ),
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 10,
        vertical: compact ? 2 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: CostaNorteBrand.goldAccentGradient,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: CostaNorteBrand.charcoal,
          fontSize: compact ? 8 : null,
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

String _labelForMassageSection(MassageBookingSection section) {
  switch (section) {
    case MassageBookingSection.selectedDay:
      return 'Dia selecionado';
    case MassageBookingSection.monthlyAgenda:
      return 'Agenda mensal';
    case MassageBookingSection.monthlySummary:
      return 'Resumo do mes';
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

IconData _iconForMassageSection(MassageBookingSection section) {
  switch (section) {
    case MassageBookingSection.selectedDay:
      return Icons.today_rounded;
    case MassageBookingSection.monthlyAgenda:
      return Icons.calendar_month_rounded;
    case MassageBookingSection.monthlySummary:
      return Icons.ssid_chart_rounded;
  }
}

String _labelForTennisSection(TennisRentalSection section) {
  switch (section) {
    case TennisRentalSection.selectedDay:
      return 'Dia selecionado';
    case TennisRentalSection.monthlyAgenda:
      return 'Agenda mensal';
    case TennisRentalSection.summary:
      return 'Resumo do periodo';
  }
}

IconData _iconForTennisSection(TennisRentalSection section) {
  switch (section) {
    case TennisRentalSection.selectedDay:
      return Icons.today_rounded;
    case TennisRentalSection.monthlyAgenda:
      return Icons.calendar_month_rounded;
    case TennisRentalSection.summary:
      return Icons.analytics_rounded;
  }
}
