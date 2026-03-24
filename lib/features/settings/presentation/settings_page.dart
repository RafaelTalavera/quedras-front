import 'package:flutter/material.dart';

import '../../../core/theme/costa_norte_brand.dart';
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
        Text('Configuracoes', style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Ajustes visuais e operacionais voltados ao uso interno da equipe, sem expor detalhes tecnicos de infraestrutura.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _SettingCard(
              icon: Icons.person_outline_rounded,
              title: 'Operador',
              value: session?.username ?? 'Sessao interna',
              detail: 'Acesso ativo para gestao de servicos e experiencias.',
            ),
            const _SettingCard(
              icon: Icons.language_rounded,
              title: 'Idioma',
              value: 'Portugues (Brasil)',
              detail:
                  'Toda a experiencia visivel ao usuario permanece em pt-BR.',
            ),
            const _SettingCard(
              icon: Icons.palette_outlined,
              title: 'Identidade visual',
              value: 'Referencia Costa Norte',
              detail:
                  'Paleta, logo e imagem inspirados no Hotel Costa Norte Ingleses.',
            ),
            const _SettingCard(
              icon: Icons.notifications_none_rounded,
              title: 'Comunicacao interna',
              value: 'Planejada',
              detail:
                  'Espaco reservado para alertas de agenda, confirmacoes e mudancas operacionais.',
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
    final TextTheme textTheme = Theme.of(context).textTheme;

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
                  color: CostaNorteBrand.foam,
                ),
                child: Icon(icon, color: CostaNorteBrand.royalBlueDeep),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.labelLarge?.copyWith(
                  color: CostaNorteBrand.mutedInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(value, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(detail, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
