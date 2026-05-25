import 'package:flutter/material.dart';

import '../../../core/feedback/app_alerts.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../application/user_management_app_service.dart';
import '../domain/user_management_models.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.session,
    required this.sessionController,
    required this.userManagementAppService,
    super.key,
  });

  final AuthSession? session;
  final SessionController sessionController;
  final UserManagementAppService userManagementAppService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loadingUsers = false;
  List<ManagedUser> _users = const <ManagedUser>[];

  bool get _isSupervisor => widget.session?.isSupervisor ?? false;
  String get _roleLabel => _isSupervisor ? 'Supervisor' : 'Operador';

  @override
  void initState() {
    super.initState();
    if (_isSupervisor) {
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int enabledUsers =
        _users.where((ManagedUser user) => user.enabled).length;
    final double width = MediaQuery.of(context).size.width;
    final bool stackedLayout = width < 980;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Configuracoes', style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _isSupervisor
              ? 'Painel administrativo para identidade, politica de acesso e gestao de usuarios.'
              : 'Painel pessoal de identidade e seguranca da sessao ativa.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        stackedLayout
            ? Column(
                children: <Widget>[
                  _buildProfilePanel(context, enabledUsers: enabledUsers),
                  const SizedBox(height: 18),
                  _buildPolicyPanel(context, enabledUsers: enabledUsers),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _buildProfilePanel(
                      context,
                      enabledUsers: enabledUsers,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildPolicyPanel(
                      context,
                      enabledUsers: enabledUsers,
                    ),
                  ),
                ],
              ),
        if (_isSupervisor) ...<Widget>[
          const SizedBox(height: 24),
          _buildUserSummaryStrip(context, enabledUsers: enabledUsers),
        ],
        const SizedBox(height: 24),
        _buildSecurityPanel(context),
        if (_isSupervisor) ...<Widget>[
          const SizedBox(height: 24),
          _buildUserManagementPanel(context),
        ],
      ],
    );
  }

  Widget _buildProfilePanel(
    BuildContext context, {
    required int enabledUsers,
  }) {
    final String username = widget.session?.username ?? 'Sessao interna';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PanelHeader(
              icon: Icons.badge_outlined,
              title: 'Perfil',
              subtitle:
                  'Identidade autenticada e escopo atual de permissao neste dispositivo.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _MetricTile(
                  icon: Icons.account_circle_outlined,
                  label: 'Usuario',
                  value: username,
                  accent: CostaNorteBrand.foam,
                ),
                _MetricTile(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Perfil',
                  value: _roleLabel,
                  accent: CostaNorteBrand.mist,
                ),
                _MetricTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Estado',
                  value: 'Sessao ativa',
                  accent: CostaNorteBrand.mint,
                ),
                _MetricTile(
                  icon: Icons.group_outlined,
                  label: 'Usuarios ativos',
                  value: _isSupervisor ? '$enabledUsers de ${_users.length}' : 'Nao disponivel',
                  accent: CostaNorteBrand.sand,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _NarrativeRow(
              icon: Icons.assignment_ind_outlined,
              title: 'Alcance do acesso',
              message: _isSupervisor
                  ? 'Pode administrar usuarios, perfis, bloqueios e redefinicoes de senha.'
                  : 'Pode operar os modulos de negocio, sem administrar credenciais de terceiros.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyPanel(
    BuildContext context, {
    required int enabledUsers,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _PanelHeader(
              icon: Icons.policy_outlined,
              title: 'Politica',
              subtitle:
                  'Regras efetivas de autenticacao, autorizacao e invalidez de sessao.',
            ),
            const SizedBox(height: 18),
            const _PolicyRule(
              icon: Icons.password_rounded,
              title: 'Senha minima',
              message: 'Credenciais exigem ao menos 12 caracteres.',
            ),
            const SizedBox(height: 12),
            const _PolicyRule(
              icon: Icons.vpn_key_outlined,
              title: 'Revogacao de token',
              message:
                  'Trocas de senha, alteracoes de perfil e bloqueios invalidam JWT emitidos antes da mudanca.',
            ),
            const SizedBox(height: 12),
            _PolicyRule(
              icon: Icons.gavel_outlined,
              title: 'Controle por papel',
              message: _isSupervisor
                  ? 'Seu papel atual libera a administracao de usuarios e politicas operacionais.'
                  : 'Seu papel atual nao libera administracao de usuarios nem redefinicao de contas de terceiros.',
            ),
            const SizedBox(height: 12),
            _PolicyRule(
              icon: Icons.shield_outlined,
              title: 'Governanca minima',
              message: _isSupervisor
                  ? 'O sistema preserva ao menos um supervisor ativo para evitar perda total de administracao.'
                  : 'A governanca de usuarios fica restrita ao supervisor habilitado no backend.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSummaryStrip(
    BuildContext context, {
    required int enabledUsers,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: <Color>[
            CostaNorteBrand.royalBlueDeep,
            CostaNorteBrand.royalBlue,
          ],
        ),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const _SummaryChip(
            icon: Icons.manage_accounts_outlined,
            label: 'Administracao habilitada',
          ),
          _SummaryChip(
            icon: Icons.group_outlined,
            label: '$enabledUsers usuarios ativos',
          ),
          _SummaryChip(
            icon: Icons.lock_person_outlined,
            label: '${_users.length - enabledUsers} bloqueados',
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _PanelHeader(
              icon: Icons.lock_outline_rounded,
              title: 'Seguranca da conta',
              subtitle:
                  'Troca de senha da conta autenticada com encerramento da sessao atual ao concluir.',
            ),
            const SizedBox(height: 8),
            const _PolicyRule(
              icon: Icons.logout_rounded,
              title: 'Encerramento imediato',
              message:
                  'Depois da alteracao, a sessao ativa perde validade e exige novo login.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showChangeOwnPasswordDialog,
              icon: const Icon(Icons.password_rounded),
              label: const Text('Trocar minha senha'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: const _PanelHeader(
                    icon: Icons.group_outlined,
                    title: 'Gestao de usuarios',
                    subtitle:
                        'Alta, bloqueio, perfil e redefinicao de senha para acessos internos.',
                  ),
                ),
                IconButton(
                  onPressed: _loadingUsers ? null : _loadUsers,
                  tooltip: 'Atualizar usuarios',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Novo usuario'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loadingUsers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_users.isEmpty)
              const Text('Nenhum usuario disponivel no backend configurado.')
            else
              Column(
                children: _users
                    .map(
                      (ManagedUser user) => _UserAccessCard(
                        user: user,
                        currentUsername: widget.session?.username,
                        onEdit: () => _showEditUserDialog(user),
                        onResetPassword: () => _showResetPasswordDialog(user),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUsers() async {
    if (!_isSupervisor) {
      return;
    }
    setState(() => _loadingUsers = true);
    try {
      final List<ManagedUser> users = await widget.userManagementAppService
          .listUsers();
      if (!mounted) {
        return;
      }
      setState(() => _users = users);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Nao foi possivel carregar usuarios',
        message: '$error',
      );
    } finally {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<void> _showCreateUserDialog() async {
    final _CreateUserDraft? draft = await showDialog<_CreateUserDraft>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateUserDialog(),
    );
    if (draft == null) {
      return;
    }

    try {
      await widget.userManagementAppService.createUser(
        CreateManagedUserInput(
          username: draft.username,
          password: draft.password,
          role: draft.role,
          enabled: draft.enabled,
        ),
      );
      await _loadUsers();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Usuario creado',
        message: 'O acesso ${draft.username} foi cadastrado com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Nao foi possivel criar o usuario',
        message: '$error',
      );
    }
  }

  Future<void> _showEditUserDialog(ManagedUser user) async {
    final _EditUserDraft? draft = await showDialog<_EditUserDraft>(
      context: context,
      builder: (BuildContext dialogContext) => _EditUserDialog(user: user),
    );
    if (draft == null) {
      return;
    }

    try {
      await widget.userManagementAppService.updateUser(
        user.id,
        UpdateManagedUserInput(role: draft.role, enabled: draft.enabled),
      );
      await _loadUsers();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Acesso atualizado',
        message: 'As permissoes de ${user.username} foram atualizadas.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Nao foi possivel atualizar o acesso',
        message: '$error',
      );
    }
  }

  Future<void> _showResetPasswordDialog(ManagedUser user) async {
    final _ResetPasswordDraft? draft = await showDialog<_ResetPasswordDraft>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _ResetPasswordDialog(username: user.username),
    );
    if (draft == null) {
      return;
    }

    try {
      await widget.userManagementAppService.resetPassword(
        user.id,
        ResetManagedUserPasswordInput(newPassword: draft.newPassword),
      );
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Senha redefinida',
        message:
            'A senha de ${user.username} foi atualizada. Tokens antigos desse usuario deixaram de valer.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Nao foi possivel redefinir a senha',
        message: '$error',
      );
    }
  }

  Future<void> _showChangeOwnPasswordDialog() async {
    final _ChangeOwnPasswordDraft? draft =
        await showDialog<_ChangeOwnPasswordDraft>(
      context: context,
      builder: (BuildContext dialogContext) => const _ChangeOwnPasswordDialog(),
    );
    if (draft == null) {
      return;
    }

    try {
      await widget.userManagementAppService.changeOwnPassword(
        ChangeOwnPasswordInput(
          currentPassword: draft.currentPassword,
          newPassword: draft.newPassword,
        ),
      );
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Senha atualizada',
        message: 'Sua sessao sera encerrada para aplicar a nova credencial.',
      );
      widget.sessionController.clearSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Nao foi possivel trocar a senha',
        message: '$error',
      );
    }
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: CostaNorteBrand.foam,
          ),
          child: Icon(icon, color: CostaNorteBrand.royalBlueDeep),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: CostaNorteBrand.royalBlueDeep),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: CostaNorteBrand.mutedInk),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _PolicyRule extends StatelessWidget {
  const _PolicyRule({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: CostaNorteBrand.royalBlueDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: <InlineSpan>[
                TextSpan(
                  text: '$title: ',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                TextSpan(text: message),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrativeRow extends StatelessWidget {
  const _NarrativeRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: CostaNorteBrand.goldDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _UserAccessCard extends StatelessWidget {
  const _UserAccessCard({
    required this.user,
    required this.currentUsername,
    required this.onEdit,
    required this.onResetPassword,
  });

  final ManagedUser user;
  final String? currentUsername;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final bool isCurrentSession = currentUsername == user.username;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CostaNorteBrand.line),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  user.username,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusPill(
                label: user.enabled ? 'Ativo' : 'Bloqueado',
                background: user.enabled
                    ? CostaNorteBrand.success.withValues(alpha: 0.14)
                    : CostaNorteBrand.error.withValues(alpha: 0.12),
                foreground: user.enabled
                    ? CostaNorteBrand.success
                    : CostaNorteBrand.error,
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: user.role.label,
                background: CostaNorteBrand.foam,
                foreground: CostaNorteBrand.royalBlueDeep,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCurrentSession
                ? 'Conta atualmente em uso nesta sessao.'
                : 'Ultima atualizacao registrada: ${user.updatedAt?.toLocal().toString().replaceFirst('.000', '') ?? 'nao informada'}.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Editar acesso'),
              ),
              FilledButton.tonalIcon(
                onPressed: onResetPassword,
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Redefinir senha'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
        ),
      ),
    );
  }
}

class _CreateUserDraft {
  const _CreateUserDraft({
    required this.username,
    required this.password,
    required this.role,
    required this.enabled,
  });

  final String username;
  final String password;
  final ManagedUserRole role;
  final bool enabled;
}

class _EditUserDraft {
  const _EditUserDraft({required this.role, required this.enabled});

  final ManagedUserRole role;
  final bool enabled;
}

class _ResetPasswordDraft {
  const _ResetPasswordDraft({required this.newPassword});

  final String newPassword;
}

class _ChangeOwnPasswordDraft {
  const _ChangeOwnPasswordDraft({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  ManagedUserRole _role = ManagedUserRole.operator;
  bool _enabled = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo usuario'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: (String? value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o usuario.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha inicial'),
                validator: (String? value) => (value == null || value.length < 12)
                    ? 'A senha deve ter ao menos 12 caracteres.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ManagedUserRole>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Perfil'),
                items: ManagedUserRole.values
                    .map(
                      (ManagedUserRole role) => DropdownMenuItem<ManagedUserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (ManagedUserRole? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _role = value);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _enabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Usuario ativo'),
                onChanged: (bool value) => setState(() => _enabled = value),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Criar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _CreateUserDraft(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _role,
        enabled: _enabled,
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user});

  final ManagedUser user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late ManagedUserRole _role = widget.user.role;
  late bool _enabled = widget.user.enabled;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar ${widget.user.username}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<ManagedUserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Perfil'),
              items: ManagedUserRole.values
                  .map(
                    (ManagedUserRole role) => DropdownMenuItem<ManagedUserRole>(
                      value: role,
                      child: Text(role.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (ManagedUserRole? value) {
                if (value == null) {
                  return;
                }
                setState(() => _role = value);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _enabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Usuario ativo'),
              subtitle: const Text('Desative para bloquear novos logins.'),
              onChanged: (bool value) => setState(() => _enabled = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_EditUserDraft(role: _role, enabled: _enabled)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.username});

  final String username;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Redefinir senha de ${widget.username}'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nova senha'),
            validator: (String? value) => (value == null || value.length < 12)
                ? 'A senha deve ter ao menos 12 caracteres.'
                : null,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Atualizar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_ResetPasswordDraft(newPassword: _passwordController.text));
  }
}

class _ChangeOwnPasswordDialog extends StatefulWidget {
  const _ChangeOwnPasswordDialog();

  @override
  State<_ChangeOwnPasswordDialog> createState() =>
      _ChangeOwnPasswordDialogState();
}

class _ChangeOwnPasswordDialogState extends State<_ChangeOwnPasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trocar minha senha'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha atual'),
                validator: (String? value) => (value == null || value.isEmpty)
                    ? 'Informe a senha atual.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha'),
                validator: (String? value) => (value == null || value.length < 12)
                    ? 'A senha deve ter ao menos 12 caracteres.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Atualizar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ChangeOwnPasswordDraft(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      ),
    );
  }
}
