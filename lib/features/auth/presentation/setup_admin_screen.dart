import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/loading_button.dart';
import '../domain/services/auth_service.dart';
import 'widgets/password_field.dart';

/// Shown only on first launch, when no account exists yet. Creates the
/// school's first administrator account; afterwards the normal login screen
/// appears (per the specification's onboarding flow).
class SetupAdminScreen extends StatefulWidget {
  const SetupAdminScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends State<SetupAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await widget.authService.createInitialAdmin(
      displayName: _displayNameController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == AuthResult.success) {
      await _showSuccessAndContinue();
    } else {
      setState(() {
        _errorMessage =
            'Could not create the account. Please check the information and try again.';
      });
    }
  }

  Future<void> _showSuccessAndContinue() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
        title: const Text('Account created'),
        content: const Text(
          'Your administrator account is ready. You can now log in.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue to login'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    widget.authService.completeSetup();
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name.';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username or email.';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password.';
    }
    if (value.length < AppConfig.setupPasswordMinLength) {
      return 'Password must be at least ${AppConfig.setupPasswordMinLength} characters.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Set up your school account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create the first administrator account for ${AppConfig.appName}.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const Key('setup_display_name'),
                        controller: _displayNameController,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          hintText: 'e.g. Mr. Ahmed Khan',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: _validateDisplayName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('setup_username'),
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username or email',
                          hintText: 'e.g. admin@school.edu',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _validateUsername,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        key: const Key('setup_password'),
                        controller: _passwordController,
                        label: 'Password',
                        hintText:
                            'At least ${AppConfig.setupPasswordMinLength} characters',
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        key: const Key('setup_confirm'),
                        controller: _confirmController,
                        label: 'Confirm password',
                        hintText: 'Re-enter your password',
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _create(),
                        validator: _validateConfirm,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('setup_error'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 20,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      LoadingButton(
                        key: const Key('setup_submit'),
                        label: 'Create administrator account',
                        icon: Icons.check,
                        isLoading: _submitting,
                        onPressed: _create,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
