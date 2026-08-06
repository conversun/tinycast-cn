import Foundation

extension String {
    var localizedUI: String {
        Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }
}
