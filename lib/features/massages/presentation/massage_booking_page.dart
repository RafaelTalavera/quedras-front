import 'package:flutter/material.dart';

class MassageBookingPage extends StatelessWidget {
  const MassageBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HeroCard(
          title: 'Agendamento de Massagens',
          subtitle:
              'Centralize os atendimentos de spa e bem-estar com uma apresentação mais acolhedora e alinhada ao padrão Costa Norte.',
          accentColor: const Color(0xFF0F6A70),
          actionLabel: 'Solicitar integração',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Integração operacional de massagens em definição.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          'Experiências disponíveis',
          style: textTheme.titleLarge?.copyWith(
            color: const Color(0xFF14384A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A tela já nasce com a linguagem correta para operação e comercialização. A conexão com agenda e confirmação fica preparada para a próxima etapa.',
          style: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5A6D77),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _ServiceCard(
              icon: Icons.spa_rounded,
              title: 'Massagem relaxante',
              detail:
                  'Atendimento com foco em descanso, acolhimento e ritmo leve para hóspedes em estadias de lazer.',
              accentColor: Color(0xFF0F6A70),
            ),
            _ServiceCard(
              icon: Icons.self_improvement_rounded,
              title: 'Drenagem e recuperação',
              detail:
                  'Opção voltada a bem-estar, circulação e recuperação pós-praia ou pós-esporte.',
              accentColor: Color(0xFF3E8C73),
            ),
            _ServiceCard(
              icon: Icons.favorite_border_rounded,
              title: 'Experiência premium',
              detail:
                  'Bloco reservado para terapias especiais, ambiente silencioso e atendimento sob consulta.',
              accentColor: Color(0xFFE0A458),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'Próxima entrega',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173348),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Cadastrar terapeutas, horários disponíveis, duração de sessões e confirmação por atendimento interno.',
                  style: TextStyle(color: Color(0xFF5A6D77), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accentColor,
            const Color(0xFF15384A),
            const Color(0xFFE6D1A3),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.16),
            ),
            child: const Text(
              'Bem-estar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFF7F8FA),
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173348),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: const TextStyle(color: Color(0xFF5A6D77), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
