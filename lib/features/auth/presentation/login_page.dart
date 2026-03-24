import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/costa_norte_logo.dart';
import '../application/auth_app_service.dart';
import '../application/session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authAppService,
    required this.sessionController,
    super.key,
  });

  final AuthAppService authAppService;
  final SessionController sessionController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool compactLayout = MediaQuery.of(context).size.width < 960;
    final Widget content = compactLayout
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildStoryPanel(context),
              const SizedBox(height: 16),
              _buildFormCard(context),
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _buildStoryPanel(context)),
                const SizedBox(width: 18),
                Expanded(child: _buildFormCard(context)),
              ],
            ),
          );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: CostaNorteBrand.ambientGradient,
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -120,
              top: -20,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.14,
                  child: Image.asset(
                    'assets/branding/costanorte_hero.jpg',
                    width: 620,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPanel(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/branding/costanorte_hero.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    CostaNorteBrand.royalBlueNight.withValues(alpha: 0.92),
                    CostaNorteBrand.royalBlue.withValues(alpha: 0.78),
                    CostaNorteBrand.gold.withValues(alpha: 0.54),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CostaNorteLogo(width: 210),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    'Sistema interno',
                    style: textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Hotel Costa Norte',
                  style: textTheme.displayMedium?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 24),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _StoryTag(label: 'Massagens'),
                    _StoryTag(label: 'Quadras'),
                    _StoryTag(label: 'Tours e viagens'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withValues(alpha: 0.95),
        border: Border.all(color: CostaNorteBrand.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    CostaNorteBrand.royalBlueNight,
                    CostaNorteBrand.royalBlueDeep,
                  ],
                ),
              ),
              child: const CostaNorteLogo(width: 178),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: CostaNorteBrand.goldAccentGradient,
              ),
              child: Text(
                'Acesso da equipe',
                style: textTheme.labelLarge?.copyWith(
                  color: CostaNorteBrand.charcoal,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Entrar', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Use suas credenciais autorizadas para operar os servicos internos do hotel.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o usuario.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Informe a senha.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFFFF1F0),
                  border: Border.all(
                    color: CostaNorteBrand.error.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: CostaNorteBrand.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_submitting ? 'Entrando...' : 'Acessar sistema'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.authAppService.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      widget.sessionController.startSession(session);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.tennisRental, (_) => false);
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });
  }
}

class _StoryTag extends StatelessWidget {
  const _StoryTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}
