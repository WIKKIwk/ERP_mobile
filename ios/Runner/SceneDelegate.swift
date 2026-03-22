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

private final class AccordLiquidDockPlaceholderController: UIViewController {
  override func loadView() {
    view = UIView()
    view.backgroundColor = .clear
  }
}

private final class AccordLiquidDockHostController: UITabBarController, UITabBarControllerDelegate {
  private let contentController: FlutterViewController
  private let channel: FlutterMethodChannel
  private var items: [AccordLiquidDockItem] = []
  private var suppressSelectionCallback = false

  init(
    contentController: FlutterViewController,
    messenger: FlutterBinaryMessenger
  ) {
    self.contentController = contentController
    channel = FlutterMethodChannel(
      name: "accord_liquid_dock_runtime",
      binaryMessenger: messenger
    )
    super.init(nibName: nil, bundle: nil)
    delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear

    let seedController = AccordLiquidDockPlaceholderController()
    setViewControllers([seedController], animated: false)

    addChild(contentController)
    view.addSubview(contentController.view)
    contentController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      contentController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      contentController.view.topAnchor.constraint(equalTo: view.topAnchor),
      contentController.view.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
    ])
    contentController.didMove(toParent: self)

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
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view.bringSubviewToFront(tabBar)
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    guard call.method == "updateDock" else {
      result(FlutterMethodNotImplemented)
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]
    let visible = args["visible"] as? Bool ?? false
    NSLog("accord_dock updateDock visible=%@ items=%lu", visible ? "true" : "false", ((args["items"] as? [[String: Any]]) ?? []).count)
    tabBar.isHidden = !visible
    tabBar.isUserInteractionEnabled = visible
    if !visible {
      items = []
      setViewControllers([], animated: false)
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

    let controllers = items.enumerated().map { index, item in
      let controller = AccordLiquidDockPlaceholderController()
      let tabBarItem = UITabBarItem(
        title: nil,
        image: UIImage(systemName: iconName(for: item, selected: false)),
        selectedImage: UIImage(systemName: iconName(for: item, selected: true))
      )
      tabBarItem.tag = index
      tabBarItem.badgeValue = item.showBadge ? " " : nil
      tabBarItem.badgeColor = UIColor(
        red: 1.0,
        green: 0.25,
        blue: 0.28,
        alpha: 1.0
      )
      tabBarItem.imageInsets = UIEdgeInsets(top: 10, left: 0, bottom: -10, right: 0)
      tabBarItem.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 1000)
      controller.tabBarItem = tabBarItem
      return controller
    }

    suppressSelectionCallback = true
    setViewControllers(controllers, animated: false)
    selectedIndex = items.firstIndex(where: { $0.active }) ?? 0
    suppressSelectionCallback = false

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

  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelect viewController: UIViewController
  ) {
    if suppressSelectionCallback {
      return
    }
    guard items.indices.contains(selectedIndex) else {
      return
    }
    let item = items[selectedIndex]
    NSLog("accord_dock tap id=%@", item.id)
    channel.invokeMethod("tap", arguments: ["id": item.id])
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if tabBar.gestureRecognizers?.contains(where: { $0 is UILongPressGestureRecognizer }) != true {
      let longPress = UILongPressGestureRecognizer(
        target: self,
        action: #selector(handleTabBarLongPress(_:))
      )
      longPress.minimumPressDuration = 0.65
      tabBar.addGestureRecognizer(longPress)
    }
  }

  @objc private func handleTabBarLongPress(
    _ recognizer: UILongPressGestureRecognizer
  ) {
    guard recognizer.state == .began else {
      return
    }
    let location = recognizer.location(in: tabBar)
    let buttons = tabBar.subviews
      .compactMap { $0 as? UIControl }
      .sorted { $0.frame.minX < $1.frame.minX }

    for (index, button) in buttons.enumerated() where button.frame.contains(location) {
      guard items.indices.contains(index) else {
        continue
      }
      let item = items[index]
      guard item.allowLongPress else {
        return
      }
      NSLog("accord_dock longPress id=%@", item.id)
      channel.invokeMethod("longPress", arguments: ["id": item.id])
      return
    }
  }
}
