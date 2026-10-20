import 'package:flutter/material.dart';

/// Brand and neutral colors shared by the application themes.
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  /// Creates application color tokens.
  const AppColors({
    required this.wechatGreen,
    required this.bgBase,
    required this.groupedBackground,
    required this.dialogBackground,
    required this.actionSheetBackground,
    required this.destructiveAction,
    required this.textBase,
    required this.textSecondary,
    required this.directMessageIncomingBubble,
    required this.directMessageOutgoingBubble,
    required this.directMessageInputBackground,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.divider,
    required this.snackBarBackground,
    required this.snackBarForeground,
    required this.directMessageLinkText,
    this.wechatLinkText,
    this.wechatStatusActionBackground,
  });

  /// Dan light theme color tokens.
  static const danLight = AppColors(
    wechatGreen: Color(0xFF38CD7E),
    bgBase: Color(0xFFFFFFFF),
    groupedBackground: Color(0xFFF5F5F5),
    dialogBackground: Color(0xFFFFFFFF),
    actionSheetBackground: Color(0xFFF5F5F5),
    destructiveAction: Color(0xFFFF3040),
    textBase: Color(0xFF000000),
    textSecondary: Color(0xFF999999),
    directMessageIncomingBubble: Color(0xFFF5F5F5),
    directMessageOutgoingBubble: Color(0xFF38CD7E),
    directMessageInputBackground: Color(0xFFF5F5F5),
    skeletonBase: Color(0xFFE1E1E1),
    skeletonHighlight: Color(0xFFF2F2F2),
    wechatLinkText: wechatLightLink,
    directMessageLinkText: directMessageLightLink,
    wechatStatusActionBackground: Color(0xFFF7F7F7),
    divider: Color(0xFFE5E5E5),
    snackBarBackground: Color(0xFF313131),
    snackBarForeground: Color(0xFFFBFBFB),
  );

  /// Dan dark theme color tokens.
  static const danDark = AppColors(
    wechatGreen: Color(0xFF099B4B),
    bgBase: Color(0xFF0F0F0F),
    groupedBackground: Color(0xFF181818),
    dialogBackground: Color(0xFF181818),
    actionSheetBackground: Color(0xFF1E1E1E),
    destructiveAction: Color(0xFFFF3040),
    textBase: Color(0xFFF3F5F7),
    textSecondary: Color(0xFF777777),
    directMessageIncomingBubble: Color(0xFF181818),
    directMessageOutgoingBubble: Color(0xFF099B4B),
    directMessageInputBackground: Color(0xFF1E1E1E),
    skeletonBase: Color(0xFF2C2C2C),
    skeletonHighlight: Color(0xFF3A3A3A),
    wechatLinkText: wechatDarkLink,
    directMessageLinkText: directMessageDarkLink,
    wechatStatusActionBackground: Color(0xFF202020),
    divider: Color(0xFF252525),
    snackBarBackground: Color(0xFF242424),
    snackBarForeground: Color(0xFFFBFBFB),
  );

  /// Foreground content displayed on the WeChat green accent color.
  static const wechatGreenForeground = Color(0xFFFFFFFF);

  /// WeChat red used for error and unread-badge accents.
  static const wechatRed = Color(0xFFFA5151);

  /// WeChat nickname, mention, and hashtag color for light mode.
  static const wechatLightLink = Color(0xFF576B95);

  /// WeChat nickname, mention, and hashtag color for dark mode.
  static const wechatDarkLink = Color(0xFF7D90A9);

  /// Direct-message link color for light mode.
  static const directMessageLightLink = Color(0xFF44677E);

  /// Direct-message link color for dark mode.
  static const directMessageDarkLink = Color(0xFF375082);

  /// Fully transparent color.
  static const transparent = Color(0x00000000);

  /// Full-screen image viewer background.
  static const imageViewerBackground = Color(0xFF000000);

  /// Full-screen image viewer foreground content.
  static const imageViewerForeground = Color(0xFFFFFFFF);

  /// Base page background.
  final Color bgBase;

  /// WeChat green accent color for the current theme.
  final Color wechatGreen;

  /// Grouped list page background.
  final Color groupedBackground;

  /// Centered alert dialog surface background.
  final Color dialogBackground;

  /// Background for a modal action sheet.
  final Color actionSheetBackground;

  /// Foreground for destructive actions.
  final Color destructiveAction;

  /// Primary text and content.
  final Color textBase;

  /// Secondary text and content.
  final Color textSecondary;

  /// Softer foreground for long-form document text.
  Color get documentBody => Color.lerp(bgBase, textBase, 0.73)!;

  /// Muted document metadata and list markers.
  Color get documentMuted => Color.lerp(bgBase, textBase, 0.55)!;

  /// Background for an incoming direct-message bubble.
  final Color directMessageIncomingBubble;

  /// Background for an outgoing direct-message bubble.
  final Color directMessageOutgoingBubble;

  /// Background of the direct-message text input.
  final Color directMessageInputBackground;

  /// Base fill used by loading skeleton elements.
  final Color skeletonBase;

  /// Moving highlight used by loading skeleton shimmer effects.
  final Color skeletonHighlight;

  /// WeChat linked or socially referenced text, when available.
  final Color? wechatLinkText;

  /// Link text color used in direct-message bubbles.
  final Color directMessageLinkText;

  /// WeChat status action button background, when available.
  final Color? wechatStatusActionBackground;

  /// Hairline divider and separator.
  final Color divider;

  /// Background for floating snack bars.
  final Color snackBarBackground;

  /// Text and action foreground for floating snack bars.
  final Color snackBarForeground;

  @override
  AppColors copyWith({
    Color? wechatGreen,
    Color? bgBase,
    Color? groupedBackground,
    Color? dialogBackground,
    Color? actionSheetBackground,
    Color? destructiveAction,
    Color? textBase,
    Color? textSecondary,
    Color? directMessageIncomingBubble,
    Color? directMessageOutgoingBubble,
    Color? directMessageInputBackground,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? wechatLinkText,
    Color? directMessageLinkText,
    Color? wechatStatusActionBackground,
    Color? divider,
    Color? snackBarBackground,
    Color? snackBarForeground,
  }) {
    return AppColors(
      wechatGreen: wechatGreen ?? this.wechatGreen,
      bgBase: bgBase ?? this.bgBase,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      actionSheetBackground:
          actionSheetBackground ?? this.actionSheetBackground,
      destructiveAction: destructiveAction ?? this.destructiveAction,
      textBase: textBase ?? this.textBase,
      textSecondary: textSecondary ?? this.textSecondary,
      directMessageIncomingBubble:
          directMessageIncomingBubble ?? this.directMessageIncomingBubble,
      directMessageOutgoingBubble:
          directMessageOutgoingBubble ?? this.directMessageOutgoingBubble,
      directMessageInputBackground:
          directMessageInputBackground ?? this.directMessageInputBackground,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      wechatLinkText: wechatLinkText ?? this.wechatLinkText,
      directMessageLinkText:
          directMessageLinkText ?? this.directMessageLinkText,
      wechatStatusActionBackground:
          wechatStatusActionBackground ?? this.wechatStatusActionBackground,
      divider: divider ?? this.divider,
      snackBarBackground: snackBarBackground ?? this.snackBarBackground,
      snackBarForeground: snackBarForeground ?? this.snackBarForeground,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;

    return AppColors(
      wechatGreen: Color.lerp(wechatGreen, other.wechatGreen, t)!,
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      groupedBackground: Color.lerp(
        groupedBackground,
        other.groupedBackground,
        t,
      )!,
      dialogBackground: Color.lerp(
        dialogBackground,
        other.dialogBackground,
        t,
      )!,
      actionSheetBackground: Color.lerp(
        actionSheetBackground,
        other.actionSheetBackground,
        t,
      )!,
      destructiveAction: Color.lerp(
        destructiveAction,
        other.destructiveAction,
        t,
      )!,
      textBase: Color.lerp(textBase, other.textBase, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      directMessageIncomingBubble: Color.lerp(
        directMessageIncomingBubble,
        other.directMessageIncomingBubble,
        t,
      )!,
      directMessageOutgoingBubble: Color.lerp(
        directMessageOutgoingBubble,
        other.directMessageOutgoingBubble,
        t,
      )!,
      directMessageInputBackground: Color.lerp(
        directMessageInputBackground,
        other.directMessageInputBackground,
        t,
      )!,
      skeletonBase: Color.lerp(
        skeletonBase,
        other.skeletonBase,
        t,
      )!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      wechatLinkText: Color.lerp(
        wechatLinkText,
        other.wechatLinkText,
        t,
      ),
      directMessageLinkText: Color.lerp(
        directMessageLinkText,
        other.directMessageLinkText,
        t,
      )!,
      wechatStatusActionBackground: Color.lerp(
        wechatStatusActionBackground,
        other.wechatStatusActionBackground,
        t,
      ),
      divider: Color.lerp(divider, other.divider, t)!,
      snackBarBackground: Color.lerp(
        snackBarBackground,
        other.snackBarBackground,
        t,
      )!,
      snackBarForeground: Color.lerp(
        snackBarForeground,
        other.snackBarForeground,
        t,
      )!,
    );
  }
}

/// Convenient access to application colors from the current theme.
extension AppColorsBuildContext on BuildContext {
  /// Application-specific color tokens.
  AppColors get appColors {
    final colors = Theme.of(this).extension<AppColors>();
    assert(colors != null, 'AppColors is not registered in ThemeData.');
    return colors!;
  }
}
