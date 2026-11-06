import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/home_tone.dart';
import '../widgets/auth_scene.dart';
import '../widgets/overlap_header.dart';

/// Saves a new member's profile (`users/{uid}`) after sign-up. Tests pass
/// their own.
typedef ProfileWriter = Future<void> Function(User user, String name);

Future<void> _saveProfileToFirestore(User user, String name) async {
  await user.updateDisplayName(name);
  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'displayName': name,
    'email': user.email,
    'isVerified': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Sign In and Create Account. One screen with a shared header so switching
/// between the two only swaps the form. The violet header stays still and
/// only the white sheet scrolls.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    this.saveProfile = _saveProfileToFirestore,
    this.startWithSignUp = false,
    this.onBack,
  });

  final AuthService authService;
  final ProfileWriter saveProfile;

  /// Open on Create Account (from "Get Started") instead of Sign In.
  final bool startWithSignUp;

  /// Called by the back button on the first form, e.g. to return to the
  /// Start page. Without it, back leaves the screen as usual.
  final VoidCallback? onBack;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _signUp = widget.startWithSignUp;

  // Shared so an email typed on one form carries over to the other.
  final _email = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _email.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _switch(bool signUp) {
    FocusScope.of(context).unfocus();
    setState(() => _signUp = signUp);
    // Start the other form from its title.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // While typing, the header shrinks to a slim bar so the form has room.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final onFirstForm = _signUp == widget.startWithSignUp;
    return PopScope(
      // Back returns to the form you started on, then to [onBack].
      canPop: onFirstForm && widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!onFirstForm) {
          _switch(widget.startWithSignUp);
        } else {
          widget.onBack?.call();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: HomeTone.card,
          body: PinnedHeader(
            overlap: 34,
            radius: 36,
            sheetColor: HomeTone.card,
            header: AuthScene(compact: typing),
            body: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _signUp
                          ? _SignUpForm(
                              key: const ValueKey('up'),
                              authService: widget.authService,
                              saveProfile: widget.saveProfile,
                              email: _email,
                              onSignIn: () => _switch(false),
                            )
                          : _SignInForm(
                              key: const ValueKey('in'),
                              authService: widget.authService,
                              email: _email,
                              onCreateAccount: () => _switch(true),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ sign in

class _SignInForm extends StatefulWidget {
  const _SignInForm({
    super.key,
    required this.authService,
    required this.email,
    required this.onCreateAccount,
  });
  final AuthService authService;
  final TextEditingController email;
  final VoidCallback onCreateAccount;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.signInWithEmailAndPassword(
        email: widget.email.text.trim(),
        password: _password.text,
      );
      // AuthGate opens Home when the sign-in goes through.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title(
          'Sign In',
          'Welcome back! Sign in to your Community account.',
        ),
        const SizedBox(height: 26),
        const _Label('Email'),
        TextFormField(
          controller: widget.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: _fieldText,
          decoration: _field(
            hint: 'Enter your email',
            icon: Icons.mail_outline_rounded,
          ),
          validator: _validateEmail,
        ),
        const SizedBox(height: 18),
        const _Label('Password'),
        _PasswordField(
          controller: _password,
          hint: 'Enter your password',
          action: TextInputAction.done,
          onSubmitted: _submit,
          validator: (v) =>
              (v ?? '').isEmpty ? 'Please enter your password.' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showForgotPassword(
              context,
              widget.authService,
              widget.email.text.trim(),
            ),
            style: _linkStyle,
            child: const Text('Forgot Password?', style: _linkText),
          ),
        ),
        if (_error != null) _ErrorBox(_error!),
        const SizedBox(height: 8),
        _PrimaryButton(label: 'Sign In', busy: _busy, onPressed: _submit),
        const _OrDivider(),
        const _GoogleButton(),
        const SizedBox(height: 18),
        _SwitchLine(
          question: 'Don\'t have an account?',
          action: 'Create Account',
          onTap: widget.onCreateAccount,
        ),
      ],
    ),
  );
}

// ================================================================ sign up

class _SignUpForm extends StatefulWidget {
  const _SignUpForm({
    super.key,
    required this.authService,
    required this.saveProfile,
    required this.email,
    required this.onSignIn,
  });
  final AuthService authService;
  final ProfileWriter saveProfile;
  final TextEditingController email;
  final VoidCallback onSignIn;

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.signUpWithEmailAndPassword(
        email: widget.email.text.trim(),
        password: _password.text,
      );
      final user = widget.authService.currentUser;
      if (user != null) await widget.saveProfile(user, _name.text.trim());
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title('Create Account', 'Join your neighbours on Community.'),
        const SizedBox(height: 26),
        const _Label('Full Name'),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          style: _fieldText,
          decoration: _field(
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) =>
              (v ?? '').trim().length < 2 ? 'Please enter your name.' : null,
        ),
        const SizedBox(height: 18),
        const _Label('Email'),
        TextFormField(
          controller: widget.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: _fieldText,
          decoration: _field(
            hint: 'Enter your email',
            icon: Icons.mail_outline_rounded,
          ),
          validator: _validateEmail,
        ),
        const SizedBox(height: 18),
        const _Label('Password'),
        _PasswordField(
          controller: _password,
          hint: 'At least 6 characters',
          action: TextInputAction.next,
          newPassword: true,
          validator: (v) =>
              (v ?? '').length < 6 ? 'Use at least 6 characters.' : null,
        ),
        const SizedBox(height: 18),
        const _Label('Confirm Password'),
        _PasswordField(
          controller: _confirm,
          hint: 'Enter your password again',
          action: TextInputAction.done,
          newPassword: true,
          onSubmitted: _submit,
          validator: (v) =>
              v != _password.text ? 'The passwords don\'t match.' : null,
        ),
        const SizedBox(height: 18),
        if (_error != null) _ErrorBox(_error!),
        const SizedBox(height: 8),
        _PrimaryButton(
          label: 'Create Account',
          busy: _busy,
          onPressed: _submit,
        ),
        const _OrDivider(),
        const _GoogleButton(),
        const SizedBox(height: 18),
        _SwitchLine(
          question: 'Already have an account?',
          action: 'Sign In',
          onTap: widget.onSignIn,
        ),
      ],
    ),
  );
}

// ======================================================== forgot password

/// Asks for an email and sends a reset link to it.
Future<void> showForgotPassword(
  BuildContext context,
  AuthService authService,
  String email,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: HomeTone.card,
  builder: (_) => _ForgotSheet(authService: authService, email: email),
);

class _ForgotSheet extends StatefulWidget {
  const _ForgotSheet({required this.authService, required this.email});
  final AuthService authService;
  final String email;

  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _sent
            ? [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: HomeTone.violet,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We sent a link to ${_email.text.trim()} to set a new '
                  'password. It may take a minute to arrive.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: HomeTone.muted, height: 1.4),
                ),
                const SizedBox(height: 18),
                _PrimaryButton(
                  label: 'Back to Sign In',
                  onPressed: () => Navigator.pop(context),
                ),
              ]
            : [
                const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter your email and we\'ll send you a link to set a new '
                  'password.',
                  style: TextStyle(color: HomeTone.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  autofocus: widget.email.isEmpty,
                  keyboardType: TextInputType.emailAddress,
                  style: _fieldText,
                  decoration: _field(
                    hint: 'Enter your email',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: _validateEmail,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(_error!),
                ],
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'Send Reset Link',
                  busy: _busy,
                  onPressed: _send,
                ),
              ],
      ),
    ),
  );
}

// ================================================================ helpers

String? _validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Please enter your email.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
    return 'Please enter a valid email.';
  }
  return null;
}

/// Plain-language text for Firebase sign-in errors.
String authErrorText(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'INVALID_LOGIN_CREDENTIALS' => 'Wrong email or password. Please try again.',
  'invalid-email' => 'That email address doesn\'t look right.',
  'user-disabled' => 'This account has been turned off.',
  'email-already-in-use' =>
    'An account with this email already exists. Try signing in.',
  'weak-password' => 'That password is too weak. Use at least 6 characters.',
  'too-many-requests' =>
    'Too many attempts. Please wait a moment and try again.',
  'network-request-failed' =>
    'No internet connection. Check your network and try again.',
  _ => e.message ?? 'Something went wrong. Please try again.',
};

const _fieldText = TextStyle(color: HomeTone.ink, fontSize: 15);

// The text style goes on the Text itself, so the links keep the app's
// font (a ButtonStyle textStyle would replace it).
const _linkText = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);

const _linkStyle = ButtonStyle(
  foregroundColor: WidgetStatePropertyAll(HomeTone.violet),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 4, vertical: 8),
  ),
);

const _fieldFill = Color(0xFFFAF8FF);
const _fieldBorder = Color(0xFFE4DAFB);

InputDecoration _field({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: HomeTone.muted, fontSize: 15),
    prefixIcon: Icon(icon, color: HomeTone.muted, size: 22),
    suffixIcon: suffix,
    filled: true,
    fillColor: _fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(_fieldBorder),
    enabledBorder: border(_fieldBorder),
    focusedBorder: border(HomeTone.violet, 1.6),
    errorBorder: border(HomeTone.red),
    focusedErrorBorder: border(HomeTone.red, 1.6),
    errorStyle: const TextStyle(color: HomeTone.red),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: HomeTone.ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(color: HomeTone.muted, fontSize: 14),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: HomeTone.ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.action,
    required this.validator,
    this.onSubmitted,
    this.newPassword = false,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputAction action;
  final FormFieldValidator<String> validator;
  final VoidCallback? onSubmitted;
  final bool newPassword;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: !_show,
    textInputAction: widget.action,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    style: _fieldText,
    decoration: _field(
      hint: widget.hint,
      icon: Icons.lock_outline_rounded,
      suffix: IconButton(
        tooltip: _show ? 'Hide password' : 'Show password',
        onPressed: () => setState(() => _show = !_show),
        icon: Icon(
          _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: HomeTone.muted,
        ),
      ),
    ),
    validator: widget.validator,
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !busy,
    label: label,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: HomeTone.actionGradient),
        boxShadow: [
          BoxShadow(
            color: HomeTone.violet.withValues(alpha: .28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            height: 54,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(child: Divider(color: _fieldBorder, endIndent: 14)),
        Text('or', style: TextStyle(color: HomeTone.muted, fontSize: 14)),
        Expanded(child: Divider(color: _fieldBorder, indent: 14)),
      ],
    ),
  );
}

/// "Continue with Google", shown but muted until Google sign-in is set up
/// in Firebase (it needs the Google provider enabled and the app's SHA
/// keys added).
class _GoogleButton extends StatelessWidget {
  const _GoogleButton();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Google sign-in is coming soon',
    child: Opacity(
      opacity: .5,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: HomeTone.card,
          disabledForegroundColor: HomeTone.ink,
          side: const BorderSide(color: HomeTone.violet, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GoogleMark(size: 22),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Continue with Google',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.question,
    required this.action,
    required this.onTap,
  });
  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        question,
        style: const TextStyle(color: HomeTone.muted, fontSize: 14.5),
      ),
      TextButton(
        onPressed: onTap,
        style: _linkStyle,
        child: Text(action, style: _linkText),
      ),
    ],
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HomeTone.redDim,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: HomeTone.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(text, style: const TextStyle(color: HomeTone.ink)),
          ),
        ),
      ],
    ),
  );
}
