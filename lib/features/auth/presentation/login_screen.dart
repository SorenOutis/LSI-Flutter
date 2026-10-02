import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_motion.dart';
import '../state/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  int _shakeKey = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _shakeKey++);
      return;
    }
    FocusScope.of(context).unfocus();

    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(loginControllerProvider);
    final ThemeData theme = Theme.of(context);

    // The router owns navigation on success; this listener only reports failure
    // so a validation error is not silently swallowed.
    ref.listen<AsyncValue<void>>(loginControllerProvider, (AsyncValue<void>? previous, AsyncValue<void> next) {
      final Object? error = next.hasError ? next.error : null;
      if (error != null && previous?.error != error) {
        setState(() => _shakeKey++);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$error'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Shaker(
                  shakeKey: _shakeKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeSlideIn(child: _BrandMark()),
                      const SizedBox(height: 36),
                      FadeSlideIn(
                        delay: AppMotion.stagger(1),
                        scale: false,
                        child: Text('Welcome back',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: AppMotion.stagger(2),
                        scale: false,
                        child: Text(
                          'Sign in to see your dashboard, exams and XP.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        delay: AppMotion.stagger(3),
                        scale: false,
                        child: TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
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
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: AppMotion.stagger(4),
                        scale: false,
                        child: TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                            ),
                          ),
                          validator: (String? value) =>
                              (value == null || value.isEmpty) ? 'Enter your password.' : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        delay: AppMotion.stagger(5),
                        scale: false,
                        child: FilledButton(
                          onPressed: state.isLoading ? null : _submit,
                          child: state.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: AppMotion.stagger(6),
                        scale: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'New here?',
                                overflow: TextOverflow.ellipsis,
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                            TextButton(
                              onPressed: state.isLoading ? null : () => context.go('/register'),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.seed, Colors.purple]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          'LSI',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
      ],
    );
  }
}