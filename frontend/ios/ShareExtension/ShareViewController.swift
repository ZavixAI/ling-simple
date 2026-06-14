import UIKit

final class ShareViewController: UIViewController, UITextViewDelegate {
  private var didStart = false
  private var didComplete = false
  private var sharedFiles: [(filename: String, data: Data)] = []
  private var pasteboardValues: [String] = []
  private let inputLoader = ShareExtensionInputLoader()
  private let sender = ShareExtensionSender()

  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private let headerView = UIView()
  private let closeButton = UIButton(type: .system)
  private let titleLabel = UILabel()
  private let previewContainer = UIView()
  private let thumbnailScrollView = UIScrollView()
  private let thumbnailStackView = UIStackView()
  private let previewTextView = UITextView()
  private let messageInputContainer = UIView()
  private let messageTextView = UITextView()
  private let messagePlaceholderLabel = UILabel()
  private let actionSeparator = UIView()
  private let sendAction = UIControl()
  private let sendIconView = UIView()
  private let sendIconLabel = UILabel()
  private let sendTitleLabel = UILabel()
  private let chevronImageView = UIImageView()
  private let statusLabel = UILabel()
  private var sendActionBottomConstraint: NSLayoutConstraint?

  override func viewDidLoad() {
    super.viewDidLoad()
    configureSheet()
    configureHeader()
    configurePreview()
    configureMessageInput()
    configureSendAction()
    configureStatus()
    configureKeyboardDismissGesture()
    configureKeyboardAvoidance()
    showLoading()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didStart else {
      return
    }
    didStart = true
    receiveSharedItems()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateThumbnailBorderColors()
    updateMessageInputBorderColor()
  }

  private func receiveSharedItems() {
    inputLoader.load(from: extensionContext) { [weak self] payload in
      guard let self else {
        return
      }
      self.sharedFiles = payload.files
      self.pasteboardValues = payload.textValues
      self.showPreview()
    }
  }

  private func configureSheet() {
    view.backgroundColor = .systemBackground
    preferredContentSize = CGSize(
      width: UIScreen.main.bounds.width,
      height: min(UIScreen.main.bounds.height * 0.82, 690)
    )
  }

  private func configureHeader() {
    headerView.translatesAutoresizingMaskIntoConstraints = false

    closeButton.translatesAutoresizingMaskIntoConstraints = false
    closeButton.setTitle("关闭", for: .normal)
    closeButton.setTitleColor(.label, for: .normal)
    closeButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    closeButton.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.88)
    closeButton.layer.cornerRadius = 18
    closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
    closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = "Ling"
    titleLabel.font = .preferredFont(forTextStyle: .headline)
    titleLabel.textColor = .label
    titleLabel.textAlignment = .center

    view.addSubview(headerView)
    headerView.addSubview(closeButton)
    headerView.addSubview(titleLabel)

    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 72),

      closeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
      closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

      titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
    ])
  }

  private func configurePreview() {
    previewContainer.translatesAutoresizingMaskIntoConstraints = false
    previewContainer.backgroundColor = .systemBackground
    previewContainer.clipsToBounds = true

    thumbnailScrollView.translatesAutoresizingMaskIntoConstraints = false
    thumbnailScrollView.alwaysBounceHorizontal = true
    thumbnailScrollView.showsHorizontalScrollIndicator = false
    thumbnailScrollView.contentInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
    thumbnailScrollView.isHidden = true

    thumbnailStackView.translatesAutoresizingMaskIntoConstraints = false
    thumbnailStackView.axis = .horizontal
    thumbnailStackView.alignment = .center
    thumbnailStackView.distribution = .fill
    thumbnailStackView.spacing = 12

    previewTextView.translatesAutoresizingMaskIntoConstraints = false
    previewTextView.isEditable = false
    previewTextView.isScrollEnabled = true
    previewTextView.backgroundColor = .clear
    previewTextView.textColor = .label
    previewTextView.font = .preferredFont(forTextStyle: .body)
    previewTextView.textContainerInset = UIEdgeInsets(top: 28, left: 24, bottom: 28, right: 24)
    previewTextView.isHidden = true

    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    activityIndicator.hidesWhenStopped = true

    view.addSubview(previewContainer)
    previewContainer.addSubview(thumbnailScrollView)
    thumbnailScrollView.addSubview(thumbnailStackView)
    previewContainer.addSubview(previewTextView)
    previewContainer.addSubview(activityIndicator)

    NSLayoutConstraint.activate([
      previewContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      thumbnailScrollView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
      thumbnailScrollView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
      thumbnailScrollView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 24),
      thumbnailScrollView.heightAnchor.constraint(equalToConstant: 152),

      thumbnailStackView.leadingAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.leadingAnchor),
      thumbnailStackView.trailingAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.trailingAnchor),
      thumbnailStackView.topAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.topAnchor),
      thumbnailStackView.bottomAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.bottomAnchor),
      thumbnailStackView.heightAnchor.constraint(equalTo: thumbnailScrollView.frameLayoutGuide.heightAnchor),

      previewTextView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
      previewTextView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
      previewTextView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
      previewTextView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),

      activityIndicator.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor)
    ])
  }

  private func configureMessageInput() {
    messageInputContainer.translatesAutoresizingMaskIntoConstraints = false
    messageInputContainer.backgroundColor = .systemBackground

    messageTextView.translatesAutoresizingMaskIntoConstraints = false
    messageTextView.delegate = self
    messageTextView.backgroundColor = .secondarySystemBackground
    messageTextView.textColor = .label
    messageTextView.tintColor = .systemGreen
    messageTextView.font = .preferredFont(forTextStyle: .body)
    messageTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    messageTextView.layer.cornerRadius = 18
    messageTextView.layer.borderWidth = 0.5
    messageTextView.layer.borderColor = UIColor.separator
      .resolvedColor(with: traitCollection)
      .cgColor
    messageTextView.isScrollEnabled = true
    messageTextView.returnKeyType = .done

    messagePlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
    messagePlaceholderLabel.text = "说点什么"
    messagePlaceholderLabel.font = .preferredFont(forTextStyle: .body)
    messagePlaceholderLabel.textColor = .placeholderText

    view.addSubview(messageInputContainer)
    messageInputContainer.addSubview(messageTextView)
    messageTextView.addSubview(messagePlaceholderLabel)

    NSLayoutConstraint.activate([
      messageInputContainer.topAnchor.constraint(equalTo: previewContainer.bottomAnchor),
      messageInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      messageInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      messageInputContainer.heightAnchor.constraint(equalToConstant: 78),

      messageTextView.topAnchor.constraint(equalTo: messageInputContainer.topAnchor, constant: 10),
      messageTextView.leadingAnchor.constraint(equalTo: messageInputContainer.leadingAnchor, constant: 24),
      messageTextView.trailingAnchor.constraint(equalTo: messageInputContainer.trailingAnchor, constant: -24),
      messageTextView.bottomAnchor.constraint(equalTo: messageInputContainer.bottomAnchor, constant: -10),

      messagePlaceholderLabel.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: 17),
      messagePlaceholderLabel.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: 12),
      messagePlaceholderLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: messageTextView.trailingAnchor,
        constant: -17
      )
    ])
  }

  private func configureKeyboardDismissGesture() {
    let gesture = UITapGestureRecognizer(
      target: self,
      action: #selector(dismissKeyboard)
    )
    gesture.cancelsTouchesInView = false
    view.addGestureRecognizer(gesture)
  }

  private func configureSendAction() {
    actionSeparator.translatesAutoresizingMaskIntoConstraints = false
    actionSeparator.backgroundColor = .separator

    sendAction.translatesAutoresizingMaskIntoConstraints = false
    sendAction.backgroundColor = .systemBackground
    sendAction.addTarget(self, action: #selector(sendToLingTapped), for: .touchUpInside)

    sendIconView.translatesAutoresizingMaskIntoConstraints = false
    sendIconView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
    sendIconView.layer.cornerRadius = 20

    sendIconLabel.translatesAutoresizingMaskIntoConstraints = false
    sendIconLabel.text = "L"
    sendIconLabel.textColor = .systemGreen
    sendIconLabel.font = .systemFont(ofSize: 20, weight: .semibold)
    sendIconLabel.textAlignment = .center

    sendTitleLabel.translatesAutoresizingMaskIntoConstraints = false
    sendTitleLabel.text = "发送给 Ling"
    sendTitleLabel.font = .preferredFont(forTextStyle: .title3)
    sendTitleLabel.textColor = .label

    chevronImageView.translatesAutoresizingMaskIntoConstraints = false
    chevronImageView.image = UIImage(systemName: "chevron.right")
    chevronImageView.tintColor = .tertiaryLabel
    chevronImageView.contentMode = .scaleAspectFit

    view.addSubview(actionSeparator)
    view.addSubview(sendAction)
    sendAction.addSubview(sendIconView)
    sendIconView.addSubview(sendIconLabel)
    sendAction.addSubview(sendTitleLabel)
    sendAction.addSubview(chevronImageView)

    let sendActionBottomConstraint = sendAction.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor
    )
    self.sendActionBottomConstraint = sendActionBottomConstraint

    NSLayoutConstraint.activate([
      actionSeparator.topAnchor.constraint(equalTo: messageInputContainer.bottomAnchor),
      actionSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      actionSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      actionSeparator.heightAnchor.constraint(equalToConstant: 0.5),

      sendAction.topAnchor.constraint(equalTo: actionSeparator.bottomAnchor),
      sendAction.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      sendAction.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      sendActionBottomConstraint,
      sendAction.heightAnchor.constraint(equalToConstant: 84),

      sendIconView.leadingAnchor.constraint(equalTo: sendAction.leadingAnchor, constant: 28),
      sendIconView.centerYAnchor.constraint(equalTo: sendAction.centerYAnchor),
      sendIconView.widthAnchor.constraint(equalToConstant: 40),
      sendIconView.heightAnchor.constraint(equalToConstant: 40),

      sendIconLabel.centerXAnchor.constraint(equalTo: sendIconView.centerXAnchor),
      sendIconLabel.centerYAnchor.constraint(equalTo: sendIconView.centerYAnchor),

      sendTitleLabel.leadingAnchor.constraint(equalTo: sendIconView.trailingAnchor, constant: 18),
      sendTitleLabel.centerYAnchor.constraint(equalTo: sendAction.centerYAnchor),
      sendTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -16),

      chevronImageView.trailingAnchor.constraint(equalTo: sendAction.trailingAnchor, constant: -28),
      chevronImageView.centerYAnchor.constraint(equalTo: sendAction.centerYAnchor),
      chevronImageView.widthAnchor.constraint(equalToConstant: 14),
      chevronImageView.heightAnchor.constraint(equalToConstant: 20)
    ])
  }

  private func configureKeyboardAvoidance() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardFrameWillChange(_:)),
      name: UIResponder.keyboardWillChangeFrameNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardFrameWillChange(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  private func configureStatus() {
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.font = .preferredFont(forTextStyle: .headline)
    statusLabel.textColor = .secondaryLabel
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    statusLabel.isHidden = true

    view.addSubview(statusLabel)

    NSLayoutConstraint.activate([
      statusLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 24),
      statusLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -24),
      statusLabel.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor)
    ])
  }

  private func showLoading() {
    thumbnailScrollView.isHidden = true
    previewTextView.isHidden = true
    statusLabel.isHidden = true
    sendAction.isEnabled = false
    sendAction.alpha = 0.45
    activityIndicator.startAnimating()
  }

  private func showPreview() {
    activityIndicator.stopAnimating()
    let hasContent = !sharedFiles.isEmpty || !pasteboardValues.isEmpty
    sendAction.isEnabled = hasContent
    sendAction.alpha = hasContent ? 1 : 0.45

    guard hasContent else {
      thumbnailScrollView.isHidden = true
      previewTextView.isHidden = true
      statusLabel.text = "无法添加到 Ling"
      statusLabel.isHidden = false
      return
    }

    let images = sharedFiles.compactMap { UIImage(data: $0.data) }
    if !images.isEmpty {
      configureImageThumbnails(images)
      thumbnailScrollView.isHidden = false
      previewTextView.isHidden = true
      statusLabel.isHidden = true
      return
    }

    if pasteboardValues.isEmpty {
      thumbnailScrollView.isHidden = true
      previewTextView.isHidden = true
      statusLabel.text = "无法预览图片"
      statusLabel.isHidden = false
      return
    }

    previewTextView.text = pasteboardValues.joined(separator: "\n")
    previewTextView.isHidden = false
    thumbnailScrollView.isHidden = true
    statusLabel.isHidden = true
  }

  private func configureImageThumbnails(_ images: [UIImage]) {
    for subview in thumbnailStackView.arrangedSubviews {
      thumbnailStackView.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }
    for image in images {
      thumbnailStackView.addArrangedSubview(makeThumbnailView(image: image))
    }
    updateThumbnailBorderColors()
  }

  private func makeThumbnailView(image: UIImage) -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.backgroundColor = .secondarySystemBackground
    container.layer.cornerRadius = 14
    container.layer.borderWidth = 0.5
    container.layer.borderColor = UIColor.separator
      .resolvedColor(with: traitCollection)
      .cgColor
    container.clipsToBounds = true

    let imageView = UIImageView(image: image)
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true

    container.addSubview(imageView)

    NSLayoutConstraint.activate([
      container.widthAnchor.constraint(equalToConstant: 118),
      container.heightAnchor.constraint(equalToConstant: 142),
      imageView.topAnchor.constraint(equalTo: container.topAnchor),
      imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    return container
  }

  private func updateThumbnailBorderColors() {
    let borderColor = UIColor.separator
      .resolvedColor(with: traitCollection)
      .cgColor
    for subview in thumbnailStackView.arrangedSubviews {
      subview.layer.borderColor = borderColor
    }
  }

  private func updateMessageInputBorderColor() {
    messageTextView.layer.borderColor = UIColor.separator
      .resolvedColor(with: traitCollection)
      .cgColor
  }

  func textViewDidChange(_ textView: UITextView) {
    guard textView === messageTextView else {
      return
    }
    messagePlaceholderLabel.isHidden = !messageInputText.isEmpty
  }

  func textView(
    _ textView: UITextView,
    shouldChangeTextIn range: NSRange,
    replacementText text: String
  ) -> Bool {
    guard textView === messageTextView else {
      return true
    }
    if text == "\n" {
      dismissKeyboard()
      return false
    }
    return true
  }

  @objc private func keyboardFrameWillChange(_ notification: Notification) {
    guard let sendActionBottomConstraint else {
      return
    }

    let keyboardFrame = (
      notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
    )?.cgRectValue ?? .zero
    let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
    let keyboardOverlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
    let safeAreaCompensatedOverlap = max(0, keyboardOverlap - view.safeAreaInsets.bottom)
    sendActionBottomConstraint.constant = -safeAreaCompensatedOverlap

    let duration = (
      notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber
    )?.doubleValue ?? 0.25
    let curveRawValue = (
      notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
    )?.uintValue ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
    let options = UIView.AnimationOptions(rawValue: curveRawValue << 16)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: options,
      animations: { [weak self] in
        self?.view.layoutIfNeeded()
      }
    )
  }

  @objc private func dismissKeyboard() {
    view.endEditing(true)
  }

  @objc private func sendToLingTapped() {
    let textPayload = combinedTextPayload()
    guard !sharedFiles.isEmpty || !textPayload.isEmpty else {
      return
    }
    sendAction.isEnabled = false
    sendAction.alpha = 0.55
    statusLabel.text = "正在打开 Ling"
    statusLabel.isHidden = false

    sender.send(
      request: ShareExtensionSendRequest(files: sharedFiles, textPayload: textPayload),
      extensionContext: extensionContext
    ) { [weak self] outcome in
      guard let self else {
        return
      }
      switch outcome {
      case .openedInExtension:
        self.complete()
      case .completedWithApplicationFallback:
        self.didComplete = true
      case .failed:
        self.showFailure()
      }
    }
  }

  private var messageInputText: String {
    messageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func combinedTextPayload() -> String {
    var values: [String] = []
    let input = messageInputText
    if !input.isEmpty {
      values.append(input)
    }
    values.append(
      contentsOf: pasteboardValues
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    )
    return values.joined(separator: "\n\n")
  }

  private func showFailure() {
    activityIndicator.stopAnimating()
    statusLabel.text = "无法打开 Ling"
    statusLabel.isHidden = false
    sendAction.isEnabled = true
    sendAction.alpha = 1
  }

  @objc private func closeButtonTapped() {
    guard !didComplete else {
      return
    }
    didComplete = true
    let error = NSError(
      domain: "LingShareExtension",
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: "User cancelled sharing."]
    )
    extensionContext?.cancelRequest(withError: error)
  }

  private func complete() {
    guard !didComplete else {
      return
    }
    didComplete = true
    extensionContext?.completeRequest(returningItems: nil)
  }
}
