import Foundation

enum JSONPath {
    static func pick(_ root: Any, _ path: String) -> Any? {
        let options = path.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        let choices = options.isEmpty ? [path] : options
        for option in choices where !option.isEmpty {
            if let value = walk(root, option), !(value is NSNull) {
                return value
            }
        }
        return nil
    }

    static func walk(_ root: Any, _ path: String) -> Any? {
        if path.isEmpty { return root }
        var current: Any = root
        for part in path.split(separator: ".") {
            let key = String(part)
            if let dict = current as? [String: Any] {
                guard let next = dict[key] else { return nil }
                current = next
            } else if let array = current as? [Any], let index = Int(key), array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        return current
    }

    static func string(_ root: Any, _ path: String) -> String? {
        guard let value = pick(root, path) else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func items(_ root: Any, path: String) -> [[String: Any]] {
        let node: Any
        if path.trimmingCharacters(in: .whitespaces).isEmpty {
            node = root
        } else {
            node = pick(root, path) ?? []
        }
        if let array = node as? [[String: Any]] { return array }
        if let array = node as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        return []
    }
}