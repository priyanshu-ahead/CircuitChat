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
  static const String search_messages = 'Search messages…';

  // ── General ───────────────────────────────────────────────────────────────
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String loading = 'Loading…';
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
  static const String noInternetConnection = 'No internet connection.';

  static const String copy = 'Copy';
  static const String reply = 'Reply';
  static const String forward = 'Forward';
  static const String pin = 'Pin';
  static const String unpin = 'Unpin';
  static const String chat = 'Chat';
  static const String chatInfo = 'Chat Info';
  static const String groupInfo = 'Group Info';
  static const String group = 'Group';
  static const String members = 'members';
  static const String archive = 'Archive';
  static const String unarchive = 'Unarchive';

  static const String mute = 'Mute';
  static const String unmute = 'Unmute';

  static const String markAsRead = 'Mark as Read';
  static const String markAsUnread = 'Mark as Unread';

  static const String block = 'Block';
  static const String unblock = 'Unblock';

  static const String exitGroup = 'Exit Group';
  static const String deleteChat = 'Delete Chat';
  static const String report = 'Report';

  // ── Chat Status ───────────────────────────────────────────────────────────
  static const String active = 'Active';
  static const String typing = 'typing…';
  static const String doNotDisturb = 'Do not disturb';

  // ── Message ───────────────────────────────────────────────────────────────
  static const String message = 'Message…';
  static const String messageInfo = 'Message Info';
  static const String copied = 'Copied';
  static const String unstar = 'Unstar';
  static const String star = 'Star';

  // ── Media / Files ─────────────────────────────────────────────────────────
  static const String file = 'file';
  static const String viewLocation = 'View Location';

  // ── Calls ─────────────────────────────────────────────────────────────────
  static const String voiceCall = 'Voice Call';
  static const String videoCall = 'Video Call';

  // ── Recording ─────────────────────────────────────────────────────────────
  static const String tapToRecord = 'Tap to record';

  // ── Dialogs ────────────────────────────────────────────────────────────────
  static const String reportedSuccessfully = 'Reported successfully.';
  static const String deleteConversation = 'Delete your conversation with';
  static const String reportToCircuitChat = 'to CircuitChat?';
  static const String deleteMessage = 'Delete Message';
  static const String deleteForMe = 'Delete for Me';
  static const String deleteForEveryone = 'Delete for Everyone';

  // ── Date / Time ────────────────────────────────────────────────────────────
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';

// ── Message ───────────────────────────────────────────────────────────────
  static const String messageDeleted = 'This message was deleted';
  static const String media = '📎 Media';



// ── Message / Chat ────────────────────────────────────────────────────────
  static const String pinnedMessage = 'Pinned Message';
  static const String noMessagesYet = 'No messages yet.\nSay hello! 👋';
  static const String failedToStopRecording = 'Failed to stop recording:';
  static const String failedToLoadMessages = 'Failed to load messages.';
}