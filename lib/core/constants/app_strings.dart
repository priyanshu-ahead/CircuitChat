/// All user-facing string keys for localisation.
/// Actual translations live in the l10n ARB files.
class AppStrings {
  AppStrings._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String appName = 'CircuitChat';
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueWithApple = 'Continue with Apple';
  static const String continueWithFacebook = 'Continue with Facebook';

  // ── Login ─────────────────────────────────────────────────────────────────
  static const String newHere = 'New here?  ';
  static const String signUp = 'Sign Up';
  static const String signInToAccount = 'Sign in to your account';
  static const String loginPasswordHint = 'Enter your password';
  static const String termsOfService = 'Terms of Service';
  static const String privacy = 'Privacy';
  static const String aboutUs = 'About Us';

  // ── Register ──────────────────────────────────────────────────────────────
  static const String signup = 'Signup';
  static const String signupSubtitle = 'Fill in your details below to get started!';
  static const String alreadyHaveAccount = 'Already have account?  ';
  static const String name = 'Name';
  static const String confirmPassword = 'Password Again';
  static const String language = 'Language';
  static const String nameHint = 'Enter your name';
  static const String emailHint = 'Enter your email';
  static const String passwordHint = 'Enter password';
  static const String confirmPasswordHint = 'Enter password again';
  static const String agreeToTerms = 'I agree to the ';
  static const String termsAndConditions = 'terms and conditions';

  // ── Register validation ──────────────────────────────────────────────────
  static const String nameRequiredError = 'Name is required';
  static const String emailRequiredError = 'Email is required';
  static const String emailInvalidError = 'Please enter a valid email address';
  static const String passwordRequiredError = 'Password is required';
  static const String passwordMinLengthError =
      'Password must be at least 8 characters and include uppercase, lowercase, number and special character';
  static const String confirmPasswordRequiredError = 'Please confirm password';
  static const String passwordsDoNotMatchError = 'Password and confirm should be same';
  static const String languageRequiredError = 'Please select a language';
  static const String termsNotAgreedError = 'You must agree to the terms and conditions';

  // ── Forgot Password ─────────────────────────────────────────────────────
  static const String forgotPasswordTitle = 'Forgot Password';
  static const String forgotPasswordDescription =
      'Enter your email address and we will send you a link to reset your password.';
  static const String enterYourEmail = 'Enter your email';
  static const String sendEmail = 'Send Email';
  static const String sending = 'Sending...';
  static const String backToLogin = 'Back to Login';
  static const String emailSentSuccessfully =
      'Password reset link has been sent to your email address. Please check your inbox.';
  static const String emailNotFound = 'Email not found. Please check and try again.';

  // ── Reset Password ──────────────────────────────────────────────────────
  static const String resetPasswordTitle = 'Reset Password';
  static const String resetPasswordSubtitle =
      'Create a new password to regain access to your account securely.';
  static const String newPassword = 'New Password';
  static const String newPasswordHint = 'New Password';
  static const String resetPasswordButton = 'Reset Password';
  static const String resetting = 'Resetting...';
  static const String passwordResetSuccess = 'Password has been reset successfully.';

  // ── Verify Email ─────────────────────────────────────────────────────────
  static const String verifyEmailTitle = 'Verify Email';
  static const String verifying = 'Verifying...';
  static const String emailVerifiedSuccess = 'Email verified successfully!';
  static const String emailVerificationFailed = 'Email verification failed.';

  // ── Languages ────────────────────────────────────────────────────────────
  static const List<String> languages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'Arabic',
    'German',
    'Portuguese',
    'Russian',
    'Japanese',
    'Chinese',
  ];

  // ── Navigation ────────────────────────────────────────────────────────────
  static const String home = 'Home';
  static const String chats = 'Chats';
  static const String contacts = 'Contacts';
  static const String profile = 'Profile';
  static const String settings = 'Settings';

  // ── Chat ──────────────────────────────────────────────────────────────────
  static const String typeMessage = 'Type a message…';
  static const String send = 'Send';
  static const String delivered = 'Delivered';
  static const String seen = 'Seen';
  static const String you = 'You';
  static const String online = 'Online';
  static const String lastSeen = 'Last seen';
  static const String noMessages = 'No messages yet. Say hello! 👋';

  // ── General ───────────────────────────────────────────────────────────────
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String loading = 'Loading…';
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
  static const String noInternetConnection = 'No internet connection.';
}