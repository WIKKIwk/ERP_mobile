import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var dockHostController: AccordLiquidDockHostController?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let window else {
      return
    }
    if let hostController = window.rootViewController as? AccordLiquidDockHostController {
      dockHostController = hostController
      return
    }
    guard let flutterViewController = window.rootViewController as? FlutterViewController else {
      return
    }
    let hostController = AccordLiquidDockHostController(
      contentController: flutterViewController,
      messenger: flutterViewController.binaryMessenger
    )
    window.rootViewController = hostController
    window.makeKeyAndVisible()
    dockHostController = hostController
  }
}

private struct AccordLiquidDockItem: Hashable {
  let id: String
  let active: Bool
  let primary: Bool
  let showBadge: Bool
  let allowLongPress: Bool
}

private final class AccordLiquidDockHostController: UIViewController {
  private let contentController: FlutterViewController
  private let dockView: AccordLiquidDockOverlayView

  init(
    contentController: FlutterViewController,
    messenger: FlutterBinaryMessenger
  ) {
    self.contentController = contentController
    dockView = AccordLiquidDockOverlayView(messenger: messenger)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear

    addChild(contentController)
    view.addSubview(contentController.view)
    contentController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      contentController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      contentController.view.topAnchor.constraint(equalTo: view.topAnchor),
      contentController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    contentController.didMove(toParent: self)

    view.addSubview(dockView)
    NSLayoutConstraint.activate([
      dockView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dockView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      dockView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      dockView.heightAnchor.constraint(equalToConstant: 120),
    ])
    view.bringSubviewToFront(dockView)
  }
}

private final class AccordLiquidDockOverlayView: UIView, UITabBarDelegate {
  private let channel: FlutterMethodChannel
  private let tabBar = UITabBar()
  private let buttonStack = UIStackView()
  private var items: [AccordLiquidDockItem] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "accord_liquid_dock_runtime", binaryMessenger: messenger)
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = .clear
    isUserInteractionEnabled = true
    isHidden = true
    setup()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    addSubview(tabBar)
    addSubview(buttonStack)
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    tabBar.isUserInteractionEnabled = false
    tabBar.clipsToBounds = false
    tabBar.delegate = self
    tabBar.tintColor = UIColor.white.withAlphaComponent(0.98)
    tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.72)
    if #available(iOS 26.0, *) {
      tabBar.itemPositioning = .automatic
    } else {
      tabBar.itemPositioning = .centered
      tabBar.itemWidth = 64
      tabBar.itemSpacing = 8
    }

    if #available(iOS 26.0, *) {
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      appearance.shadowColor = .clear
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
    } else if #available(iOS 15.0, *) {
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
      appearance.backgroundColor = UIColor.white.withAlphaComponent(0.04)
      appearance.shadowColor = .clear
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
    } else {
      tabBar.barStyle = .black
      tabBar.isTranslucent = true
    }

    NSLayoutConstraint.activate([
      tabBar.centerXAnchor.constraint(equalTo: centerXAnchor),
      tabBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      tabBar.heightAnchor.constraint(equalToConstant: 64),
      tabBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
      tabBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
    ])

    buttonStack.translatesAutoresizingMaskIntoConstraints = false
    buttonStack.axis = .horizontal
    buttonStack.alignment = .fill
    buttonStack.distribution = .fillEqually
    buttonStack.spacing = 0
    buttonStack.isUserInteractionEnabled = true
    NSLayoutConstraint.activate([
      buttonStack.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
      buttonStack.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
      buttonStack.topAnchor.constraint(equalTo: tabBar.topAnchor),
      buttonStack.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
    ])

    layer.zPosition = 999
    tabBar.layer.zPosition = 1000
    buttonStack.layer.zPosition = 1001
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    guard !isHidden else { return false }
    let tabPoint = convert(point, to: tabBar)
    let hitBounds = tabBar.bounds.insetBy(dx: -18, dy: -14)
    return hitBounds.contains(tabPoint)
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard !isHidden, point(inside: point, with: event) else {
      return nil
    }

    for button in buttonStack.arrangedSubviews.reversed() {
      let localPoint = convert(point, to: button)
      if let hit = button.hitTest(localPoint, with: event) {
        return hit
      }
    }

    let tabPoint = convert(point, to: tabBar)
    return tabBar.hitTest(tabPoint, with: event)
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    guard call.method == "updateDock" else {
      result(FlutterMethodNotImplemented)
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]
    let visible = args["visible"] as? Bool ?? false
    NSLog("accord_dock updateDock visible=%@ items=%lu", visible ? "true" : "false", ((args["items"] as? [[String: Any]]) ?? []).count)
    isHidden = !visible
    buttonStack.isUserInteractionEnabled = visible
    if !visible {
      items = []
      tabBar.items = []
      rebuildButtons()
      result(nil)
      return
    }

    let rawItems = args["items"] as? [[String: Any]] ?? []
    items = rawItems.compactMap { item in
      guard let id = item["id"] as? String else { return nil }
      return AccordLiquidDockItem(
        id: id,
        active: item["active"] as? Bool ?? false,
        primary: item["primary"] as? Bool ?? false,
        showBadge: item["showBadge"] as? Bool ?? false,
        allowLongPress: item["allowLongPress"] as? Bool ?? false
      )
    }

    let tabItems = items.enumerated().map { index, item in
      let tabBarItem = UITabBarItem(
        title: nil,
        image: UIImage(systemName: iconName(for: item, selected: false)),
        selectedImage: UIImage(systemName: iconName(for: item, selected: true))
      )
      tabBarItem.tag = index
      tabBarItem.badgeValue = item.showBadge ? " " : nil
      tabBarItem.badgeColor = UIColor(red: 1.0, green: 0.25, blue: 0.28, alpha: 1.0)
      tabBarItem.imageInsets = UIEdgeInsets(top: 10, left: 0, bottom: -10, right: 0)
      tabBarItem.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 1000)
      return tabBarItem
    }

    tabBar.setItems(tabItems, animated: false)
    rebuildButtons()
    if let activeIndex = items.firstIndex(where: { $0.active }),
       let activeItem = tabBar.items?[activeIndex] {
      tabBar.selectedItem = activeItem
    } else {
      tabBar.selectedItem = nil
    }

    result(nil)
  }

  private func iconName(for item: AccordLiquidDockItem, selected: Bool) -> String {
    switch item.id {
      case "home":
        return selected ? "house.fill" : "house"
      case "notifications":
        return selected ? "bell.fill" : "bell"
      case "profile":
        return selected ? "person.crop.circle.fill" : "person.crop.circle"
      case "recent":
        return selected ? "clock.fill" : "clock"
      case "suppliers":
        return selected ? "person.2.fill" : "person.2"
      case "activity":
        return selected ? "waveform.path.ecg.rectangle.fill" : "waveform.path.ecg.rectangle"
      case "create":
        return item.primary ? "plus.circle.fill" : "plus"
      default:
        return selected ? "circle.fill" : "circle"
    }
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    guard items.indices.contains(item.tag) else { return }
    channel.invokeMethod("tap", arguments: ["id": items[item.tag].id])
  }

  private func rebuildButtons() {
    for view in buttonStack.arrangedSubviews {
      buttonStack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }

    for (index, item) in items.enumerated() {
      let button = UIButton(type: .custom)
      button.backgroundColor = .clear
      button.tag = index
      button.accessibilityIdentifier = "accord-dock-\(item.id)"
      button.addTarget(self, action: #selector(handleOverlayButtonTap(_:)), for: .touchUpInside)
      if item.allowLongPress {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleOverlayButtonLongPress(_:)))
        longPress.minimumPressDuration = 0.65
        button.addGestureRecognizer(longPress)
      }
      buttonStack.addArrangedSubview(button)
    }
  }

  @objc private func handleOverlayButtonTap(_ sender: UIButton) {
    guard items.indices.contains(sender.tag) else { return }
    NSLog("accord_dock tap id=%@", items[sender.tag].id)
    channel.invokeMethod("tap", arguments: ["id": items[sender.tag].id])
  }

  @objc private func handleOverlayButtonLongPress(_ recognizer: UILongPressGestureRecognizer) {
    guard recognizer.state == .began,
          let button = recognizer.view as? UIButton,
          items.indices.contains(button.tag) else {
      return
    }
    let item = items[button.tag]
    if item.allowLongPress {
      NSLog("accord_dock longPress id=%@", item.id)
      channel.invokeMethod("longPress", arguments: ["id": item.id])
    }
  }
}
