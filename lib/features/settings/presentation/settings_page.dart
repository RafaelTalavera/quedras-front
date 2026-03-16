import 'package:flutter/material.dart';

import '../../auth/domain/auth_session.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.session, super.key});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Configurações',
          style: textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF14384A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ajustes visuais e operacionais voltados ao uso interno da equipe, sem expor detalhes técnicos de infraestrutura.',
          style: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5A6D77),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _SettingCard(
              icon: Icons.person_outline_rounded,
              title: 'Operador',
              value: session?.username ?? 'Sessão interna',
              detail: 'Acesso ativo para gestão de serviços e experiências.',
            ),
            const _SettingCard(
              icon: Icons.language_rounded,
              title: 'Idioma',
              value: 'Português (Brasil)',
              detail:
                  'Toda a experiência visível ao usuário permanece em pt-BR.',
            ),
            const _SettingCard(
              icon: Icons.palette_outlined,
              title: 'Identidade visual',
              value: 'Padrão Costa Norte',
              detail:
                  'Paleta inspirada em mar, areia e hospitalidade para manter coerência com a marca.',
            ),
            const _SettingCard(
              icon: Icons.notifications_none_rounded,
              title: 'Comunicação interna',
              value: 'Planejada',
              detail:
                  'Espaço reservado para alertas de agenda, confirmações e mudanças operacionais.',
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

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
                  color: const Color(0x1A0F4C5C),
                ),
                child: Icon(icon, color: const Color(0xFF0F4C5C)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5A6D77),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
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
