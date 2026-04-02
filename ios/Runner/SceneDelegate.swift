import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let window,
      let flutterViewController = window.rootViewController as? FlutterViewController,
      !(window.rootViewController is NativeBackNavigationController)
    else {
      return
    }

    let navigationController = NativeBackNavigationController(
      flutterViewController: flutterViewController
    )
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
  }
}

final class NativeBackNavigationController: UINavigationController {
  private let rootFlutterViewController: FlutterViewController
  private let glassDockView = NativeGlassDockView()
  private lazy var backBridge = NativeBackButtonChannelBridge(
    messenger: flutterBinaryMessenger,
    onVisibilityChanged: { [weak self] visible in
      self?.setBackButtonVisible(visible)
    }
  )
  private lazy var dockBridge = NativeDockChannelBridge(
    messenger: flutterBinaryMessenger,
    onStateChanged: { [weak self] state in
      self?.glassDockView.apply(state: state)
    }
  )

  private var flutterBinaryMessenger: FlutterBinaryMessenger {
    rootFlutterViewController.binaryMessenger
  }

  init(flutterViewController: FlutterViewController) {
    self.rootFlutterViewController = flutterViewController
    super.init(rootViewController: flutterViewController)
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    _ = backBridge
    _ = dockBridge
    navigationBar.prefersLargeTitles = false
    navigationBar.tintColor = .label
    topViewController?.navigationItem.leftBarButtonItem = makeBackBarButtonItem()
    setNavigationBarHidden(true, animated: false)
    configureDockView()
  }

  private func setBackButtonVisible(_ visible: Bool) {
    UIView.performWithoutAnimation {
      topViewController?.navigationItem.leftBarButtonItem = visible
        ? makeBackBarButtonItem()
        : nil
      setNavigationBarHidden(!visible, animated: false)
      navigationBar.layoutIfNeeded()
    }
  }

  private func makeBackBarButtonItem() -> UIBarButtonItem {
    let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    let image = UIImage(systemName: "chevron.backward", withConfiguration: configuration)
    return UIBarButtonItem(
      image: image,
      style: .plain,
      target: self,
      action: #selector(handleBackButtonTap)
    )
  }

  @objc
  private func handleBackButtonTap() {
    backBridge.sendBackPressed()
  }

  private func configureDockView() {
    glassDockView.translatesAutoresizingMaskIntoConstraints = false
    glassDockView.onTap = { [weak self] id in
      self?.dockBridge.sendTap(id: id)
    }
    glassDockView.onLongPress = { [weak self] id in
      self?.dockBridge.sendLongPress(id: id)
    }
    view.addSubview(glassDockView)
    NSLayoutConstraint.activate([
      glassDockView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      glassDockView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 14),
      glassDockView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14),
      glassDockView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
    ])
  }
}

private final class NativeBackButtonChannelBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let onVisibilityChanged: (Bool) -> Void

  init(
    messenger: FlutterBinaryMessenger,
    onVisibilityChanged: @escaping (Bool) -> Void
  ) {
    self.channel = FlutterMethodChannel(
      name: "accord/native_back_button",
      binaryMessenger: messenger
    )
    self.onVisibilityChanged = onVisibilityChanged
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
    channel.invokeMethod("nativeBackButtonReady", arguments: nil)
  }

  func sendBackPressed() {
    channel.invokeMethod("nativeBackPressed", arguments: nil)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setBackButtonVisible":
      let visible = (call.arguments as? Bool) ?? false
      DispatchQueue.main.async {
        self.onVisibilityChanged(visible)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private final class NativeDockChannelBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let onStateChanged: (NativeDockState) -> Void

  init(
    messenger: FlutterBinaryMessenger,
    onStateChanged: @escaping (NativeDockState) -> Void
  ) {
    self.channel = FlutterMethodChannel(
      name: "accord/native_dock",
      binaryMessenger: messenger
    )
    self.onStateChanged = onStateChanged
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
    channel.invokeMethod("nativeDockReady", arguments: nil)
  }

  func sendTap(id: String) {
    channel.invokeMethod("nativeDockTap", arguments: id)
  }

  func sendLongPress(id: String) {
    channel.invokeMethod("nativeDockLongPress", arguments: id)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setDockState":
      let state = NativeDockState(arguments: call.arguments as? [String: Any] ?? [:])
      DispatchQueue.main.async {
        self.onStateChanged(state)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private struct NativeDockState {
  let visible: Bool
  let compact: Bool
  let tightToEdges: Bool
  let items: [NativeDockItem]

  init(arguments: [String: Any]) {
    visible = arguments["visible"] as? Bool ?? false
    compact = arguments["compact"] as? Bool ?? true
    tightToEdges = arguments["tightToEdges"] as? Bool ?? true
    let rawItems = arguments["items"] as? [[String: Any]] ?? []
    items = rawItems.map(NativeDockItem.init)
  }
}

private struct NativeDockItem {
  let id: String
  let symbol: String
  let selectedSymbol: String?
  let active: Bool
  let primary: Bool
  let showBadge: Bool
  let supportsLongPress: Bool

  init(arguments: [String: Any]) {
    id = arguments["id"] as? String ?? UUID().uuidString
    symbol = arguments["symbol"] as? String ?? "circle"
    selectedSymbol = arguments["selectedSymbol"] as? String
    active = arguments["active"] as? Bool ?? false
    primary = arguments["primary"] as? Bool ?? false
    showBadge = arguments["showBadge"] as? Bool ?? false
    supportsLongPress = arguments["supportsLongPress"] as? Bool ?? false
  }
}

private final class NativeGlassDockView: UIView {
  var onTap: ((String) -> Void)?
  var onLongPress: ((String) -> Void)?

  private let effectView = UIVisualEffectView()
  private let stackView = UIStackView()
  private var widthConstraint: NSLayoutConstraint?
  private var heightConstraint: NSLayoutConstraint?
  private var buttonConfigs: [UIButton: NativeDockItem] = [:]

  override init(frame: CGRect) {
    super.init(frame: frame)
    isHidden = true
    translatesAutoresizingMaskIntoConstraints = false
    setupEffectView()
    setupStackView()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func apply(state: NativeDockState) {
    isHidden = !state.visible
    guard state.visible else {
      return
    }

    widthConstraint?.constant = estimatedWidth(for: state)
    heightConstraint?.constant = state.compact ? 68 : 74
    updateEffect(for: state)
    rebuildButtons(items: state.items, compact: state.compact)
    layoutIfNeeded()
  }

  private func setupEffectView() {
    effectView.translatesAutoresizingMaskIntoConstraints = false
    effectView.clipsToBounds = true
    effectView.layer.cornerRadius = 30
    effectView.layer.cornerCurve = .continuous
    addSubview(effectView)

    NSLayoutConstraint.activate([
      effectView.topAnchor.constraint(equalTo: topAnchor),
      effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    widthConstraint = widthAnchor.constraint(equalToConstant: 320)
    widthConstraint?.isActive = true
    heightConstraint = heightAnchor.constraint(equalToConstant: 68)
    heightConstraint?.isActive = true
  }

  private func setupStackView() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.distribution = .equalCentering
    stackView.spacing = 10
    effectView.contentView.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 8),
      stackView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 12),
      stackView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -12),
      stackView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -8),
    ])
  }

  private func updateEffect(for state: NativeDockState) {
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      glass.tintColor = UIColor.white.withAlphaComponent(state.tightToEdges ? 0.06 : 0.08)
      effectView.effect = glass
    } else {
      effectView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
    }
  }

  private func rebuildButtons(items: [NativeDockItem], compact: Bool) {
    buttonConfigs.removeAll()
    stackView.arrangedSubviews.forEach { subview in
      stackView.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }

    for item in items {
      let button = makeButton(for: item, compact: compact)
      buttonConfigs[button] = item
      stackView.addArrangedSubview(button)
    }
  }

  private func makeButton(for item: NativeDockItem, compact: Bool) -> UIButton {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.accessibilityIdentifier = item.id
    button.tintColor = item.primary ? .white : .label
    button.addTarget(self, action: #selector(handleTap(_:)), for: .primaryActionTriggered)

    let pointSize: CGFloat = item.primary ? (compact ? 21 : 23) : 20
    let weight: UIImage.SymbolWeight = item.primary ? .bold : .semibold
    let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    let symbolName = item.active ? (item.selectedSymbol ?? item.symbol) : item.symbol

    if #available(iOS 15.0, *) {
      var buttonConfiguration: UIButton.Configuration
      if #available(iOS 26.0, *) {
        if item.primary {
          buttonConfiguration = .prominentGlass()
        } else if item.active {
          buttonConfiguration = .glass()
        } else {
          buttonConfiguration = .clearGlass()
        }
      } else {
        buttonConfiguration = item.primary
          ? .borderedProminent()
          : .plain()
      }

      buttonConfiguration.cornerStyle = .capsule
      buttonConfiguration.baseForegroundColor = item.primary ? .white : .label
      buttonConfiguration.image = UIImage(systemName: symbolName, withConfiguration: configuration)
      buttonConfiguration.preferredSymbolConfigurationForImage = configuration
      buttonConfiguration.contentInsets = item.primary
        ? NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        : NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
      button.configuration = buttonConfiguration
    } else {
      button.setImage(UIImage(systemName: symbolName, withConfiguration: configuration), for: .normal)
      button.contentEdgeInsets = item.primary
        ? UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        : UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
      if item.primary {
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 20
        button.layer.cornerCurve = .continuous
      }
    }

    if item.supportsLongPress {
      let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      recognizer.minimumPressDuration = 1.0
      button.addGestureRecognizer(recognizer)
    }

    if item.showBadge {
      let badge = UIView()
      badge.translatesAutoresizingMaskIntoConstraints = false
      badge.backgroundColor = .systemRed
      badge.layer.cornerRadius = 5
      badge.layer.cornerCurve = .continuous
      button.addSubview(badge)
      NSLayoutConstraint.activate([
        badge.widthAnchor.constraint(equalToConstant: 10),
        badge.heightAnchor.constraint(equalToConstant: 10),
        badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 5),
        badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
      ])
    }

    return button
  }

  private func estimatedWidth(for state: NativeDockState) -> CGFloat {
    let baseButtonWidth: CGFloat = state.compact ? 52 : 58
    let primaryButtonWidth: CGFloat = state.compact ? 58 : 64
    let buttonWidth = state.items.reduce(CGFloat(24)) { partial, item in
      partial + (item.primary ? primaryButtonWidth : baseButtonWidth)
    }
    let spacing = CGFloat(max(state.items.count - 1, 0)) * 10
    return min(UIScreen.main.bounds.width - 28, buttonWidth + spacing)
  }

  @objc
  private func handleTap(_ sender: UIButton) {
    guard let id = sender.accessibilityIdentifier else {
      return
    }
    onTap?(id)
  }

  @objc
  private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
    guard
      recognizer.state == .began,
      let id = recognizer.view?.accessibilityIdentifier
    else {
      return
    }
    onLongPress?(id)
  }
}
