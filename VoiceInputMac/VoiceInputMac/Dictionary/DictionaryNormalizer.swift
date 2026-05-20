import Foundation

struct DictionaryNormalizer {
    func normalize(_ text: String, entries: [DictionaryEntry]) -> String {
        var result = text
        let sorted = entries.sorted {
            if $0.priority == $1.priority {
                return $0.spoken.count > $1.spoken.count
            }
            return $0.priority > $1.priority
        }

        for entry in sorted {
            let forms = [entry.spoken] + entry.aliases
            for form in forms where !form.isEmpty {
                if form.contains(".") {
                    continue
                }
                result = replacingDictionaryForm(form, with: entry.written, in: result)
            }
        }

        result = replacing("Whisper 点 cpp", with: "whisper.cpp", in: result)
        result = replacing("whisper 点 cpp", with: "whisper.cpp", in: result)
        result = replacing("swift you eye", with: "SwiftUI", in: result)
        result = replacing("swift u i", with: "SwiftUI", in: result)
        result = replacing("swift ui", with: "SwiftUI", in: result)
        result = replacing("维斯破 cpp", with: "whisper.cpp", in: result)
        result = replacing("威斯破 cpp", with: "whisper.cpp", in: result)
        result = replacing("维斯珀 cpp", with: "whisper.cpp", in: result)
        result = replacing("whisper cpp", with: "whisper.cpp", in: result)
        result = replacing("cursor", with: "Cursor", in: result)
        result = replacing("点 cpp", with: ".cpp", in: result)
        result = replacing("点 C P P", with: ".cpp", in: result)
        result = replacing("差路", with: "插入", in: result)
        result = replacing("叉入", with: "插入", in: result)
        result = replacing("插路", with: "插入", in: result)
        result = replacing("去进行一个整理", with: "整理", in: result)
        result = replacing("去进行整理", with: "整理", in: result)
        result = replacing("进行一个整理", with: "整理", in: result)
        result = replacing("没有办法去", with: "无法", in: result)
        return result
    }

    private func replacing(_ needle: String, with replacement: String, in text: String) -> String {
        let pattern = NSRegularExpression.escapedPattern(for: needle)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.replacingOccurrences(of: needle, with: replacement)
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private func replacingDictionaryForm(_ needle: String, with replacement: String, in text: String) -> String {
        let pattern = NSRegularExpression.escapedPattern(for: needle)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.replacingOccurrences(of: needle, with: replacement)
        }

        var result = ""
        var cursor = text.startIndex
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }
            result += String(text[cursor..<matchRange.lowerBound])
            if isAlreadyWrittenForm(needleRange: matchRange, replacement: replacement, in: text) {
                result += String(text[matchRange])
            } else {
                result += replacement
            }
            cursor = matchRange.upperBound
        }
        result += String(text[cursor...])
        return result
    }

    private func isAlreadyWrittenForm(needleRange: Range<String.Index>, replacement: String, in text: String) -> Bool {
        let matched = String(text[needleRange])
        guard replacement.lowercased().hasPrefix(matched.lowercased()) else {
            return false
        }
        let suffix = String(replacement.dropFirst(matched.count))
        guard !suffix.isEmpty else {
            return false
        }
        let suffixEnd = text.index(needleRange.upperBound, offsetBy: suffix.count, limitedBy: text.endIndex) ?? text.endIndex
        guard suffixEnd <= text.endIndex else {
            return false
        }
        let following = String(text[needleRange.upperBound..<suffixEnd])
        return following.caseInsensitiveCompare(suffix) == .orderedSame
    }
}
