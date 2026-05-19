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
                result = replacing(form, with: entry.written, in: result)
            }
        }

        result = replacing("Whisper 点 cpp", with: "whisper.cpp", in: result)
        result = replacing("whisper 点 cpp", with: "whisper.cpp", in: result)
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
}
