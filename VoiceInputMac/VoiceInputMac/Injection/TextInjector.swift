import Foundation

protocol TextInjector {
    func insertText(_ text: String) async throws
    func replaceSelectedText(_ text: String) async throws
}

