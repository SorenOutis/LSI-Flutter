import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/common.dart';
import '../state/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool _obscure = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  /// Mirrors the server rule: at least 8 characters with letters and numbers.
  static String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) return 'Include at least one letter.';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Include at least one number.';
    return null;
  }

  Future<void> _submit() async {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || !_acceptedTerms) return;
    FocusScope.of(context).unfocus();

    await ref
        .read(registerControllerProvider.notifier)
        .submit(
          firstName: _firstName.text,
          lastName: _lastName.text,
          middleName: _middleName.text,
          email: _email.text,
          password: _password.text,
          passwordConfirmation: _confirmPassword.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(registerControllerProvider);
    final ThemeData theme = Theme.of(context);

    ref.listen<AsyncValue<void>>(registerControllerProvider, (AsyncValue<void>? previous, AsyncValue<void> next) {
      final Object? error = next.hasError ? next.error : null;
      if (error == null || previous?.error == error) return;

      // A 422 carries per-field messages; surface them against the matching
      // inputs instead of as a generic snackbar.
      if (error is ApiException && error.isValidation && error.fieldErrors.isNotEmpty) {
        _formKey.currentState?.validate();
        showSnack(context, error.fieldErrors.values.first.first, isError: true);
        return;
      }

      showSnack(context, '$error', isError: true);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Join your class',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Use the name your teacher will recognise on your papers.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'First name'),
                            validator: (String? value) =>
                                (value?.trim().length ?? 0) < 2 ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Last name'),
                            validator: (String? value) =>
                                (value?.trim().length ?? 0) < 2 ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _middleName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Middle name (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (String? value) {
                        final String email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email.';
                        if (!email.contains('@')) return 'Enter a valid email address.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (String? value) => value != _password.text ? 'Passwords do not match.' : null,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (bool? value) => setState(() => _acceptedTerms = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I agree to the terms and privacy policy'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state.isLoading ? null : () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
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