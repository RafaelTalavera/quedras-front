import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
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
    final bool compactLayout = MediaQuery.of(context).size.width < 920;
    final Widget content = compactLayout
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildStoryPanel(context),
              const SizedBox(height: 16),
              _buildFormCard(context),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(flex: 11, child: _buildStoryPanel(context)),
              const SizedBox(width: 18),
              Flexible(flex: 10, child: _buildFormCard(context)),
            ],
          );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0D3945),
              Color(0xFF167D85),
              Color(0xFFE2B56F),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.16),
            ),
            child: const Icon(
              Icons.waves_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Acesso interno Costa Norte',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Uma experiência mais limpa, mais comercial e mais alinhada com a operação do hotel para massagem, quadras de tênis e tours.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const _StoryBullet(
            title: 'Agendamento de massagens',
            detail: 'Fluxo preparado para organizar atendimentos de bem-estar.',
          ),
          const SizedBox(height: 14),
          const _StoryBullet(
            title: 'Aluguel de quadras',
            detail: 'Agenda diária e criação de reservas em uma única área.',
          ),
          const SizedBox(height: 14),
          const _StoryBullet(
            title: 'Tours e viagens',
            detail: 'Espaço dedicado à gestão de experiências e deslocamentos.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.black.withValues(alpha: 0.16),
            ),
            child: Text(
              'Toda a comunicação visível ao operador deve permanecer em português do Brasil.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.95),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Entrar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF0B2942),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use as credenciais autorizadas para acessar os serviços internos do hotel.',
              style: TextStyle(
                color: Color(0xFF55687B),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Usuário',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o usuário.';
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
                  color: const Color(0xFFFDECEC),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFA12C2C),
                    fontWeight: FontWeight.w600,
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

class _StoryBullet extends StatelessWidget {
  const _StoryBullet({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFF4D0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
