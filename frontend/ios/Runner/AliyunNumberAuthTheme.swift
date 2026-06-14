import UIKit

struct AliyunNumberAuthTheme {
  let pageBackground: UIColor
  let sheetBackground: UIColor
  let sheetBorderColor: UIColor
  let handleColor: UIColor
  let primaryText: UIColor
  let secondaryText: UIColor
  let linkText: UIColor
  let certificationSuccessText: UIColor
  let certificationSuccessBackground: UIColor
  let buttonBackground: UIColor
  let buttonForeground: UIColor
  let disabledButtonBackground: UIColor
  let pressedButtonBackground: UIColor
  let checkboxSelectedFill: UIColor
  let checkboxSelectedMark: UIColor
  let checkboxUncheckedBorder: UIColor

  static func resolve(prefersDarkMode: Bool) -> AliyunNumberAuthTheme {
    if prefersDarkMode {
      let pageBackground = UIColor(argb: 0xFF020407)
      let primaryText = UIColor(argb: 0xFFF8FAFC)
      let secondaryText = UIColor(argb: 0xFFAEB7C2)
      let buttonBackground = UIColor(argb: 0xFF0A84FF)
      return AliyunNumberAuthTheme(
        pageBackground: pageBackground,
        sheetBackground: pageBackground,
        sheetBorderColor: UIColor(argb: 0xFF303A49),
        handleColor: primaryText.withAlphaComponent(0.18),
        primaryText: primaryText,
        secondaryText: secondaryText.withAlphaComponent(0.74),
        linkText: primaryText.withAlphaComponent(0.90),
        certificationSuccessText: UIColor(argb: 0xFF30D158),
        certificationSuccessBackground: UIColor(argb: 0xFF30D158)
          .withAlphaComponent(0.14),
        buttonBackground: buttonBackground,
        buttonForeground: primaryText,
        disabledButtonBackground: UIColor(argb: 0xFF17324A),
        pressedButtonBackground: buttonBackground.withAlphaComponent(0.82),
        checkboxSelectedFill: buttonBackground,
        checkboxSelectedMark: primaryText,
        checkboxUncheckedBorder: UIColor(argb: 0xFF303A49)
      )
    }

    let pageBackground = UIColor(argb: 0xFFFFFFFF)
    let primaryText = UIColor(argb: 0xFF111318)
    let secondaryText = UIColor(argb: 0xFF68707A)
    let buttonBackground = UIColor(argb: 0xFF007AFF)
    return AliyunNumberAuthTheme(
      pageBackground: pageBackground,
      sheetBackground: pageBackground,
      sheetBorderColor: UIColor(argb: 0xFFDCE3EA).withAlphaComponent(0.70),
      handleColor: primaryText.withAlphaComponent(0.05),
      primaryText: primaryText,
      secondaryText: secondaryText.withAlphaComponent(0.74),
      linkText: primaryText.withAlphaComponent(0.80),
      certificationSuccessText: UIColor(argb: 0xFF34C759),
      certificationSuccessBackground: UIColor(
        red: 234 / 255,
        green: 248 / 255,
        blue: 241 / 255,
        alpha: 1
      ),
      buttonBackground: buttonBackground,
      buttonForeground: UIColor(argb: 0xFFFFFFFF),
      disabledButtonBackground: UIColor(argb: 0x4D64D2FF),
      pressedButtonBackground: buttonBackground.withAlphaComponent(0.82),
      checkboxSelectedFill: buttonBackground,
      checkboxSelectedMark: UIColor(argb: 0xFFFFFFFF),
      checkboxUncheckedBorder: UIColor(argb: 0xFFDCE3EA).withAlphaComponent(0.70)
    )
  }
}

extension UIColor {
  convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
