import UIKit

extension UIViewController {
    func topMostViewController() -> UIViewController? {
        self.topViewController(controller: self)
    }
    
    func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return self.topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return self.topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return self.topViewController(controller: presented)
        }
        return controller
    }
}

extension UIWindow {
    func viewControllerInStack<T: UIViewController>(of type: T.Type? = nil) -> T? {
        if let vc = rootViewController as? T {
            return vc
        } else if let vc = rootViewController?.presentedViewController as? T {
            return vc
        } else if let vc = rootViewController?.children {
            return vc.lazy.compactMap { $0 as? T }.first
        }
        
        return nil
    }
}
