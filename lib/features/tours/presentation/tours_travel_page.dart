import 'package:flutter/material.dart';

class ToursTravelPage extends StatelessWidget {
  const ToursTravelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF15425A),
                Color(0xFF167D85),
                Color(0xFFE7C78C),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: const Text(
                  'Experiências',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tours e Viagens',
                style: textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Organize passeios, deslocamentos e experiências externas com uma comunicação mais próxima da recepção e do concierge.',
                style: TextStyle(
                  color: Color(0xFFF7F8FA),
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Linhas de atendimento',
          style: textTheme.titleLarge?.copyWith(
            color: const Color(0xFF14384A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A tela já estrutura a oferta comercial. O próximo passo é conectar fornecedores, disponibilidade e confirmação de saída.',
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
            _ExperienceCard(
              icon: Icons.directions_boat_rounded,
              title: 'Passeios costeiros',
              detail:
                  'Saídas para praias, escunas e roteiros panorâmicos com ponto de encontro definido pelo hotel.',
            ),
            _ExperienceCard(
              icon: Icons.airport_shuttle_rounded,
              title: 'Traslados e deslocamentos',
              detail:
                  'Organização de transporte privativo, aeroporto, city tour e serviços sob reserva prévia.',
            ),
            _ExperienceCard(
              icon: Icons.map_rounded,
              title: 'Roteiros personalizados',
              detail:
                  'Curadoria de experiências para famílias, casais e hóspedes em viagens de bem-estar ou esporte.',
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0x1A167D85),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Color(0xFF167D85),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: const Color(0xFF0F6A70)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF173348),
                      ),
                    ),
                  ),
                ],
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
