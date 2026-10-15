import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppColors, () {
    test('provides the WeChat semantic color tokens', () {
      expect(AppColors.danLight.wechatGreen, const Color(0xFF38CD7E));
      expect(AppColors.danDark.wechatGreen, const Color(0xFF099B4B));
      expect(
        AppColors.wechatGreenForeground,
        const Color(0xFFFFFFFF),
      );
      expect(AppColors.danLight.bgBase, const Color(0xFFFFFFFF));
      expect(
        AppColors.danLight.groupedBackground,
        AppColors.danLight.actionSheetBackground,
      );
      expect(AppColors.danLight.dialogBackground, const Color(0xFFFFFFFF));
      expect(
        AppColors.danLight.actionSheetBackground,
        const Color(0xFFF5F5F5),
      );
      expect(AppColors.danLight.destructiveAction, const Color(0xFFFF3040));
      expect(AppColors.danLight.textBase, const Color(0xFF000000));
      expect(AppColors.danLight.textSecondary, const Color(0xFF999999));
      expect(
        AppColors.danLight.directMessageIncomingBubble,
        const Color(0xFFF5F5F5),
      );
      expect(
        AppColors.danLight.directMessageOutgoingBubble,
        const Color(0xFF38CD7E),
      );
      expect(AppColors.danLight.wechatLinkText, const Color(0xFF576B95));
      expect(
        AppColors.danLight.directMessageLinkText,
        const Color(0xFF44677E),
      );
      expect(
        AppColors.danLight.wechatStatusActionBackground,
        const Color(0xFFF7F7F7),
      );
      expect(
        AppColors.danLight.directMessageInputBackground,
        const Color(0xFFF5F5F5),
      );
      expect(
        AppColors.danLight.skeletonBase,
        const Color(0xFFE1E1E1),
      );
      expect(
        AppColors.danLight.skeletonHighlight,
        const Color(0xFFF2F2F2),
      );
      expect(AppColors.danLight.divider, const Color(0xFFE5E5E5));
      expect(AppColors.danDark.bgBase, const Color(0xFF0F0F0F));
      expect(
        AppColors.danDark.groupedBackground,
        const Color(0xFF181818),
      );
      expect(AppColors.danDark.dialogBackground, const Color(0xFF181818));
      expect(
        AppColors.danDark.actionSheetBackground,
        const Color(0xFF1E1E1E),
      );
      expect(AppColors.danDark.destructiveAction, const Color(0xFFFF3040));
      expect(AppColors.danDark.textBase, const Color(0xFFF3F5F7));
      expect(AppColors.danDark.textSecondary, const Color(0xFF777777));
      expect(
        AppColors.danDark.directMessageIncomingBubble,
        const Color(0xFF181818),
      );
      expect(
        AppColors.danDark.directMessageOutgoingBubble,
        const Color(0xFF099B4B),
      );
      expect(AppColors.danDark.wechatLinkText, const Color(0xFF7D90A9));
      expect(
        AppColors.danDark.directMessageLinkText,
        const Color(0xFF375082),
      );
      expect(
        AppColors.danDark.wechatStatusActionBackground,
        const Color(0xFF202020),
      );
      expect(
        AppColors.danDark.directMessageInputBackground,
        const Color(0xFF1E1E1E),
      );
      expect(
        AppColors.danDark.skeletonBase,
        const Color(0xFF2C2C2C),
      );
      expect(
        AppColors.danDark.skeletonHighlight,
        const Color(0xFF3A3A3A),
      );
      expect(AppColors.danDark.divider, const Color(0xFF252525));
    });

    test('provides full-screen image viewer colors', () {
      expect(AppColors.imageViewerBackground, const Color(0xFF000000));
      expect(AppColors.imageViewerForeground, const Color(0xFFFFFFFF));
    });

    test('copies one token without changing the remaining tokens', () {
      const replacement = Color(0xFF123456);

      final result = AppColors.danLight.copyWith(
        textSecondary: replacement,
      );

      expect(result.wechatGreen, AppColors.danLight.wechatGreen);
      expect(result.bgBase, AppColors.danLight.bgBase);
      expect(
        result.groupedBackground,
        AppColors.danLight.groupedBackground,
      );
      expect(result.dialogBackground, AppColors.danLight.dialogBackground);
      expect(
        result.actionSheetBackground,
        AppColors.danLight.actionSheetBackground,
      );
      expect(result.destructiveAction, AppColors.danLight.destructiveAction);
      expect(result.textBase, AppColors.danLight.textBase);
      expect(result.textSecondary, replacement);
      expect(
        result.skeletonBase,
        AppColors.danLight.skeletonBase,
      );
      expect(
        result.skeletonHighlight,
        AppColors.danLight.skeletonHighlight,
      );
      expect(result.wechatLinkText, AppColors.danLight.wechatLinkText);
      expect(
        result.directMessageLinkText,
        AppColors.danLight.directMessageLinkText,
      );
      expect(
        result.wechatStatusActionBackground,
        AppColors.danLight.wechatStatusActionBackground,
      );
      expect(result.divider, AppColors.danLight.divider);
    });
  });
}
