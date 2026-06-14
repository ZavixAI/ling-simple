import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/chat/application/shared_item_text_sanitizer.dart';

void main() {
  test('keeps shared text when no image attachment was imported', () {
    const text =
        'file:///var/mobile/Containers/Data/Application/app/Library/WechatPrivate/MMImagePicker/Temp/99960.png';

    expect(
      sanitizeSharedTextForImportedAttachments(
        text,
        hasSharedImageFiles: false,
      ),
      text,
    );
  });

  test('drops WeChat local image file references after importing image', () {
    const text =
        '记录一下，终于有了\n\n'
        'file:///var/mobile/Containers/Data/Application/app/Library/WechatPrivate/MMImagePicker/Temp/99960.png';

    expect(
      sanitizeSharedTextForImportedAttachments(text, hasSharedImageFiles: true),
      '记录一下，终于有了',
    );
  });

  test('does not drop agent workspace file references', () {
    const text =
        '照片已保存：![照片](file:///app/agents/user/agent/upload_files/photo.png)';

    expect(
      sanitizeSharedTextForImportedAttachments(text, hasSharedImageFiles: true),
      text,
    );
  });
}
