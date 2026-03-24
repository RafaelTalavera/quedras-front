import 'package:flutter/material.dart';

import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/brand_section_hero.dart';

class ToursTravelPage extends StatelessWidget {
  const ToursTravelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const BrandSectionHero(
          eyebrow: 'Experiencias',
          title: 'Tours e viagens',
          description:
              'Organize passeios, deslocamentos e experiencias externas com um tom visual mais proximo da recepcao e do concierge do hotel.',
          icon: Icons.explore_rounded,
          photoAlignment: Alignment.centerRight,
        ),
        const SizedBox(height: 18),
        Text('Linhas de atendimento', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'A tela ja estrutura a oferta comercial. O proximo passo e conectar fornecedores, disponibilidade e confirmacao de saida.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _ExperienceCard(
              icon: Icons.directions_boat_rounded,
              title: 'Passeios costeiros',
              detail:
                  'Saidas para praias, escunas e roteiros panoramicos com ponto de encontro definido pelo hotel.',
            ),
            _ExperienceCard(
              icon: Icons.airport_shuttle_rounded,
              title: 'Traslados e deslocamentos',
              detail:
                  'Organizacao de transporte privativo, aeroporto, city tour e servicos sob reserva previa.',
            ),
            _ExperienceCard(
              icon: Icons.map_rounded,
              title: 'Roteiros personalizados',
              detail:
                  'Curadoria de experiencias para familias, casais e hospedes em viagens de bem-estar ou esporte.',
            ),
          ],
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: CostaNorteBrand.foam,
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: CostaNorteBrand.royalBlue,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: CostaNorteBrand.goldDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
