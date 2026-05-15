#if os(iOS)

import ObjectiveC
import WebKit

extension WKWebView {

    @MainActor
    func disableInputAccessoryView() {
        guard let contentView = scrollView.subviews.first(where: { String(describing: type(of: $0)).contains("WKContent") })
            ?? findContentView()
        else {
            return
        }

        let originalClass: AnyClass = object_getClass(contentView) ?? type(of: contentView)
        let subclassName = "\(NSStringFromClass(originalClass))_NoInputAccessory"

        if let existing = NSClassFromString(subclassName) {
            object_setClass(contentView, existing)
            return
        }

        guard let subclass = objc_allocateClassPair(originalClass, subclassName, 0) else {
            return
        }

        let selector = #selector(getter: UIResponder.inputAccessoryView)
        let block: @convention(block) (Any) -> UIView? = { _ in nil }
        let imp = imp_implementationWithBlock(block)
        let types = "@@:"
        class_addMethod(subclass, selector, imp, types)
        objc_registerClassPair(subclass)
        object_setClass(contentView, subclass)
    }

    private func findContentView() -> UIView? {
        var stack: [UIView] = subviews
        while let view = stack.popLast() {
            if String(describing: type(of: view)).contains("WKContent") {
                return view
            }
            stack.append(contentsOf: view.subviews)
        }
        return nil
    }
}

#endif
