import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';

/// Design-first change password. No backend endpoint yet.
///
/// Validation mirrors register (`>=8 chars, letter + number`).
/// Confirm simulates 900ms then shows success. Backend later:
/// `PUT /users/me/password {current_password, password, password_confirmation}`.
Future<void> showChangePasswordSheet(BuildContext context) {
  return AppSheet.show<void>(
    context: context,
    title: 'Change password',
    subtitle: 'Design preview',
    icon: CupertinoIcons.lock_fill,
    children: const <Widget>[_ChangePasswordBody()],
  );
}

String? _passwordRule(String? value) {
  final String password = value ?? '';
  if (password.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(password)) return 'Include at least one letter.';
  if (!RegExp(r'[0-9]').hasMatch(password)) return 'Include at least one number.';
  return null;
}

class _ChangePasswordBody extends StatefulWidget {
  const _ChangePasswordBody();

  @override
  State<_ChangePasswordBody> createState() => _ChangePasswordBodyState();
}

class _ChangePasswordBodyState extends State<_ChangePasswordBody> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;
  bool _hideCurrent = true;
  bool _hideNext = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Password updated on this device preview. You will stay signed in.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              Navigator.of(context).pop();
              showSnack(context, 'Password changed (design preview).');
            },
            child: const Text('Done'),
          ),
          const SizedBox(height: 8),
          const SheetNote(message: 'Design preview: nothing was sent. Backend will wire PUT /users/me/password later.'),
        ],
      );
    }

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _current,
            obscureText: _hideCurrent,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Current password',
              suffixIcon: IconButton(
                tooltip: _hideCurrent ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                icon: Icon(_hideCurrent ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 18),
              ),
            ),
            validator: (String? v) => (v == null || v.isEmpty) ? 'Enter your current password.' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _next,
            obscureText: _hideNext,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'New password',
              helperText: 'At least 8 characters, with a letter and a number.',
              suffixIcon: IconButton(
                tooltip: _hideNext ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hideNext = !_hideNext),
                icon: Icon(_hideNext ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 18),
              ),
            ),
            validator: _passwordRule,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _confirm,
            obscureText: _hideConfirm,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              suffixIcon: IconButton(
                tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                icon: Icon(_hideConfirm ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 18),
              ),
            ),
            validator: (String? v) {
              if (v == null || v.isEmpty) return 'Repeat the new password.';
              if (v != _next.text) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(CupertinoIcons.lock_fill, size: 17),
            label: Text(_busy ? 'Updating…' : 'Update password'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          const SheetNote(message: 'Design preview: validation runs locally. Backend wires the real endpoint later.'),
        ],
      ),
    );
  }
}
