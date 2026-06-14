import UIKit

enum AliyunNumberAuthModelFactory {
  static func make(
    prefersDarkMode: Bool,
    termsURL: String?,
    privacyURL: String?,
    keyWindow: @escaping () -> UIWindow?
  ) -> TXCustomModel {
    let model = TXCustomModel()
    let theme = AliyunNumberAuthTheme.resolve(prefersDarkMode: prefersDarkMode)
    var hasCustomPrivacy = false
    let horizontalPadding: CGFloat = 24
    var sheetHandleView: UIView?
    var certificationBadgeView: UIView?
    var certificationIconView: UIImageView?
    var certificationLabel: UILabel?
    weak var authContentView: UIView?

    func safeAreaInsets() -> UIEdgeInsets {
      keyWindow()?.safeAreaInsets ?? .zero
    }

    func contentWidth(for superViewSize: CGSize) -> CGFloat {
      min(superViewSize.width - horizontalPadding * 2, 360)
    }

    func numberFrame(for superViewSize: CGSize, defaultFrame: CGRect) -> CGRect {
      let width = defaultFrame.width > 0
        ? defaultFrame.width
        : contentWidth(for: superViewSize)
      let height = defaultFrame.height > 0 ? defaultFrame.height : 48
      return CGRect(
        x: (superViewSize.width - width) / 2,
        y: 88,
        width: width,
        height: height
      )
    }

    func loginFrame(for superViewSize: CGSize) -> CGRect {
      let safeBottom = safeAreaInsets().bottom
      let width = superViewSize.width - horizontalPadding * 2
      let y = max(204, superViewSize.height - safeBottom - 24 - 54 - 16 - 56)
      return CGRect(x: horizontalPadding, y: y, width: width, height: 56)
    }

    func privacyFrame(for superViewSize: CGSize) -> CGRect {
      let frame = loginFrame(for: superViewSize)
      return CGRect(
        x: horizontalPadding,
        y: frame.maxY + 16,
        width: frame.width,
        height: 54
      )
    }

    func certificationFrame(
      for superViewSize: CGSize,
      numberFrame: CGRect
    ) -> CGRect {
      let width = min(172, superViewSize.width - horizontalPadding * 2)
      return CGRect(
        x: (superViewSize.width - width) / 2,
        y: numberFrame.maxY + 16,
        width: width,
        height: 40
      )
    }

    model.presentDirection = .bottom
    model.animationDuration = 0.28
    model.prefersStatusBarHidden = false
    model.preferredStatusBarStyle = {
      if prefersDarkMode {
        return .lightContent
      }
      if #available(iOS 13.0, *) {
        return .darkContent
      }
      return .default
    }()
    model.contentViewFrameBlock = { _, superViewSize, _ in
      let insets = safeAreaInsets()
      let preferredHeight = max(superViewSize.height * 0.45, 360 + insets.bottom)
      let maximumHeight = max(320, superViewSize.height - insets.top - 20)
      let sheetHeight = min(maximumHeight, preferredHeight)
      return CGRect(
        x: 0,
        y: superViewSize.height - sheetHeight,
        width: superViewSize.width,
        height: sheetHeight
      )
    }
    model.alertBlurViewColor = .black
    model.alertBlurViewAlpha = prefersDarkMode ? 0.58 : 0.40
    model.alertContentViewColor = theme.sheetBackground
    model.alertContentViewAlpha = 1.0
    model.alertCornerRadiusArray = [24, 0, 0, 24]
    model.alertTitleBarColor = theme.sheetBackground
    model.alertBarIsHidden = true
    model.alertCloseImage = authCloseIconImage(color: theme.primaryText)
    model.alertCloseItemIsHidden = true
    model.tapAuthPageMaskClosePage = true
    model.backgroundColor = theme.pageBackground
    model.navColor = theme.pageBackground
    model.navIsHidden = true
    model.navIsHiddenAfterLoginVCDisappear = false
    model.logoIsHidden = true
    model.sloganIsHidden = true
    model.checkBoxIsChecked = true
    model.checkBoxImages = [
      authCheckboxImage(isSelected: false, theme: theme),
      authCheckboxImage(isSelected: true, theme: theme)
    ]
    model.checkBoxWH = 18
    model.checkBoxVerticalCenter = true
    model.expandAuthPageCheckedScope = true
    model.changeBtnIsHidden = true
    model.navTitle = NSAttributedString(
      string: "本机号码验证",
      attributes: [
        .foregroundColor: theme.primaryText,
        .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
      ]
    )
    model.navBackImage = authBackIconImage(color: theme.primaryText)
    model.privacyNavColor = theme.pageBackground
    model.privacyNavTitleFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    model.privacyNavTitleColor = theme.primaryText
    model.privacyNavBackImage = authBackIconImage(color: theme.primaryText)
    model.numberColor = theme.primaryText
    model.numberFont = UIFont.systemFont(ofSize: 34, weight: .black)
    model.numberFrameBlock = { _, superViewSize, frame in
      numberFrame(for: superViewSize, defaultFrame: frame)
    }
    model.loginBtnText = NSAttributedString(
      string: "一键登录",
      attributes: [
        .foregroundColor: theme.buttonForeground,
        .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
      ]
    )
    model.loginBtnBgImgs = [
      authButtonBackgroundImage(color: theme.buttonBackground),
      authButtonBackgroundImage(color: theme.disabledButtonBackground),
      authButtonBackgroundImage(color: theme.pressedButtonBackground)
    ]
    model.loginBtnFrameBlock = { _, superViewSize, _ in loginFrame(for: superViewSize) }
    model.privacyAlignment = .center
    model.privacyFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    model.privacyOperatorFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    model.privacyLineSpaceDp = 3
    model.privacyFrameBlock = { _, superViewSize, _ in privacyFrame(for: superViewSize) }
    model.customViewBlock = { superCustomView in
      authContentView = superCustomView
      superCustomView.layer.borderColor = theme.sheetBorderColor.cgColor
      superCustomView.layer.borderWidth = 1 / UIScreen.main.scale
      superCustomView.layer.cornerRadius = 24
      if #available(iOS 11.0, *) {
        superCustomView.layer.maskedCorners = [
          .layerMinXMinYCorner,
          .layerMaxXMinYCorner
        ]
      }

      let handleView = UIView()
      handleView.backgroundColor = theme.handleColor
      handleView.layer.cornerRadius = 2.5
      handleView.isUserInteractionEnabled = false
      superCustomView.addSubview(handleView)
      sheetHandleView = handleView

      let badgeView = UIView()
      badgeView.backgroundColor = theme.certificationSuccessBackground
      badgeView.layer.cornerRadius = 16
      badgeView.isUserInteractionEnabled = false
      superCustomView.addSubview(badgeView)
      certificationBadgeView = badgeView

      let iconView = UIImageView(
        image: certificationIconImage(color: theme.certificationSuccessText)
      )
      iconView.contentMode = .scaleAspectFit
      badgeView.addSubview(iconView)
      certificationIconView = iconView

      let label = UILabel()
      label.text = "安全认证加密中"
      label.textColor = theme.certificationSuccessText
      label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
      label.textAlignment = .center
      badgeView.addSubview(label)
      certificationLabel = label
    }
    model.customViewLayoutBlock = { _, contentViewFrame, _, _, _, _, numberRect, loginRect, _, _ in
      sheetHandleView?.frame = CGRect(
        x: (contentViewFrame.width - 44) / 2,
        y: 24,
        width: 44,
        height: 5
      )
      let badgeFrame = certificationFrame(
        for: contentViewFrame.size,
        numberFrame: numberRect
      )
      let maxBadgeY = max(numberRect.maxY + 12, loginRect.minY - badgeFrame.height - 18)
      certificationBadgeView?.frame = CGRect(
        x: badgeFrame.origin.x,
        y: min(badgeFrame.origin.y, maxBadgeY),
        width: badgeFrame.width,
        height: badgeFrame.height
      )
      certificationIconView?.frame = CGRect(x: 16, y: 12, width: 16, height: 16)
      certificationLabel?.frame = CGRect(
        x: 40,
        y: 0,
        width: badgeFrame.width - 56,
        height: badgeFrame.height
      )
      centerNumberLabelIfNeeded(in: authContentView, matching: numberRect)
    }

    if let termsURL {
      model.privacyOne = ["Ling用户协议", termsURL]
      hasCustomPrivacy = true
    }
    if let privacyURL {
      model.privacyTwo = ["Ling隐私政策", privacyURL]
      hasCustomPrivacy = true
    }
    if hasCustomPrivacy {
      model.privacyPreText = "已阅读并同意 "
      model.privacySufText = ""
      model.privacyColors = [
        theme.secondaryText,
        theme.linkText
      ]
      model.privacyOperatorColor = theme.linkText
    }
    model.privacyAlertIsNeedShow = true
    model.privacyAlertIsNeedAutoLogin = true
    model.privacyAlertAnimationDuration = 0.25
    model.privacyAlertCornerRadiusArray = [15, 15, 15, 15]
    model.privacyAlertBackgroundColor = theme.sheetBackground
    model.privacyAlertAlpha = 1.0
    model.privacyAlertTitleContent = "请阅读并同意以下条款"
    model.privacyAlertTitleFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    model.privacyAlertTitleColor = theme.primaryText
    model.privacyAlertTitleBackgroundColor = theme.sheetBackground
    model.privacyAlertTitleAlignment = .center
    model.privacyAlertContentFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    model.privacyAlertLineSpaceDp = 4
    model.privacyAlertContentBackgroundColor = theme.sheetBackground
    model.privacyAlertContentColors = [
      theme.secondaryText,
      theme.linkText
    ]
    model.privacyAlertContentOperatorFont = UIFont.systemFont(
      ofSize: 13,
      weight: .semibold
    )
    model.privacyAlertOperatorColor = theme.linkText
    model.privacyAlertContentAlignment = .center
    model.privacyAlertBtnContent = "同意并继续"
    model.privacyAlertBtnCornerRadius = 16
    model.privacyAlertBtnBackgroundImages = [
      authButtonBackgroundImage(color: theme.buttonBackground),
      authButtonBackgroundImage(color: theme.pressedButtonBackground)
    ]
    model.privacyAlertButtonTextColors = [
      theme.buttonForeground,
      theme.buttonForeground.withAlphaComponent(0.92)
    ]
    model.privacyAlertButtonFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    model.privacyAlertCloseButtonImage = authCloseIconImage(color: theme.primaryText)
    model.privacyAlertCloseButtonIsNeedShow = true
    model.privacyAlertMaskIsNeedShow = true
    model.tapPrivacyAlertMaskCloseAlert = true
    model.privacyAlertMaskColor = .black
    model.privacyAlertMaskAlpha = prefersDarkMode ? 0.58 : 0.40
    model.privacyAlertFrameBlock = { _, superViewSize, _ in
      let width = min(superViewSize.width - 40, 340)
      return CGRect(
        x: (superViewSize.width - width) / 2,
        y: (superViewSize.height - 248) / 2,
        width: width,
        height: 248
      )
    }
    model.privacyAlertTitleFrameBlock = { _, superViewSize, _ in
      CGRect(x: 24, y: 24, width: superViewSize.width - 48, height: 28)
    }
    model.privacyAlertPrivacyContentFrameBlock = { _, superViewSize, _ in
      CGRect(x: 24, y: 72, width: superViewSize.width - 48, height: 86)
    }
    model.privacyAlertButtonFrameBlock = { _, superViewSize, _ in
      CGRect(x: 24, y: superViewSize.height - 80, width: superViewSize.width - 48, height: 56)
    }

    return model
  }

  private static func authButtonBackgroundImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 320, height: 56)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { _ in
      color.setFill()
      UIBezierPath(
        roundedRect: CGRect(origin: .zero, size: size),
        cornerRadius: 16
      ).fill()
    }
    return image.resizableImage(
      withCapInsets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
      resizingMode: .stretch
    )
  }

  private static func authCloseIconImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 44, height: 44)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let path = UIBezierPath()
      path.move(to: CGPoint(x: 12, y: 12))
      path.addLine(to: CGPoint(x: 32, y: 32))
      path.move(to: CGPoint(x: 32, y: 12))
      path.addLine(to: CGPoint(x: 12, y: 32))
      path.lineWidth = 3.25
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      color.setStroke()
      path.stroke()
    }.withRenderingMode(.alwaysOriginal)
  }

  private static func authBackIconImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 44, height: 44)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let path = UIBezierPath()
      path.move(to: CGPoint(x: 28, y: 11.5))
      path.addLine(to: CGPoint(x: 16, y: 22))
      path.addLine(to: CGPoint(x: 28, y: 32.5))
      path.lineWidth = 3.25
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      color.setStroke()
      path.stroke()
    }.withRenderingMode(.alwaysOriginal)
  }

  private static func authCheckboxImage(isSelected: Bool, theme: AliyunNumberAuthTheme) -> UIImage {
    let size = CGSize(width: 18, height: 18)
    let borderColor = isSelected ? theme.checkboxSelectedFill : theme.checkboxUncheckedBorder
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: 5)
      (isSelected ? theme.checkboxSelectedFill : UIColor.clear).setFill()
      path.fill()
      borderColor.setStroke()
      path.lineWidth = 1.5
      path.stroke()

      guard isSelected else {
        return
      }

      let checkmark = UIBezierPath()
      checkmark.move(to: CGPoint(x: 4.5, y: 9.5))
      checkmark.addLine(to: CGPoint(x: 7.5, y: 12.5))
      checkmark.addLine(to: CGPoint(x: 13.5, y: 6.5))
      checkmark.lineWidth = 1.8
      checkmark.lineCapStyle = .round
      checkmark.lineJoinStyle = .round
      theme.checkboxSelectedMark.setStroke()
      checkmark.stroke()
    }
  }

  private static func certificationIconImage(color: UIColor) -> UIImage? {
    if #available(iOS 13.0, *) {
      let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
      return UIImage(
        systemName: "checkmark.shield.fill",
        withConfiguration: configuration
      )?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    return nil
  }

  private static func centerNumberLabelIfNeeded(in rootView: UIView?, matching frame: CGRect) {
    guard
      let rootView,
      let label = findNumberLabel(in: rootView, rootView: rootView, matching: frame),
      let superview = label.superview
    else {
      return
    }
    label.frame = superview.convert(frame, from: rootView)
    label.textAlignment = .center
    label.baselineAdjustment = .alignCenters
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8
  }

  private static func findNumberLabel(
    in view: UIView,
    rootView: UIView,
    matching frame: CGRect
  ) -> UILabel? {
    if let label = view as? UILabel,
      isLikelyNumberLabel(label, in: rootView, matching: frame)
    {
      return label
    }
    for subview in view.subviews {
      if let label = findNumberLabel(in: subview, rootView: rootView, matching: frame) {
        return label
      }
    }
    return nil
  }

  private static func isLikelyNumberLabel(
    _ label: UILabel,
    in rootView: UIView,
    matching targetFrame: CGRect
  ) -> Bool {
    let frameInRoot = label.convert(label.bounds, to: rootView)
    let normalizedText = (label.text ?? "")
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "")
    let looksLikePhoneNumber = normalizedText.range(
      of: #"[0-9*•xX]{4,}"#,
      options: .regularExpression
    ) != nil
    let verticalMatch = abs(frameInRoot.midY - targetFrame.midY) <=
      max(12, targetFrame.height * 0.5)
    let horizontalOverlap = frameInRoot.maxX >= targetFrame.minX &&
      frameInRoot.minX <= targetFrame.maxX
    let reasonableHeight = frameInRoot.height >= targetFrame.height * 0.5 &&
      frameInRoot.height <= targetFrame.height * 1.5

    return looksLikePhoneNumber && verticalMatch && horizontalOverlap && reasonableHeight
  }
}
