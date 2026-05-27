import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

Widget buildGSignInButton({double? width}) {
  return (GoogleSignInPlatform.instance as GoogleSignInPlugin).renderButton(
    configuration: GSIButtonConfiguration(
      type: GSIButtonType.standard,
      theme: GSIButtonTheme.filledBlue,
      size: GSIButtonSize.large,
      text: GSIButtonText.continueWith,
      shape: GSIButtonShape.rectangular,
      minimumWidth: (width ?? 300).clamp(150, 400),
    ),
  );
}
