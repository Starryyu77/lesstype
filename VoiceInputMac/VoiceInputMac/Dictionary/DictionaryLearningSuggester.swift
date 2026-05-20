import Foundation

struct DictionaryLearningSuggestion: Equatable {
    let spoken: String
    let written: String
}

struct DictionaryLearningSuggester {
    func suggestion(originalText: String, editedText: String) -> DictionaryLearningSuggestion? {
        let original = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let edited = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, !edited.isEmpty, original != edited else {
            return nil
        }

        let prefix = commonPrefixIndex(original, edited)
        let suffix = commonSuffixIndices(original, edited, after: prefix)
        var originalStart = prefix.original
        var editedStart = prefix.edited
        let originalEnd = suffix.original
        let editedEnd = suffix.edited

        if shouldExpandLeft(original: original, edited: edited, originalStart: originalStart, editedStart: editedStart) {
            originalStart = startOfPreviousToken(in: original, before: originalStart)
            editedStart = startOfPreviousToken(in: edited, before: editedStart)
        }

        let spoken = trimmedTerm(String(original[originalStart..<originalEnd]))
        let written = trimmedTerm(String(edited[editedStart..<editedEnd]))

        guard isPlausible(spoken: spoken, written: written) else {
            return nil
        }
        return DictionaryLearningSuggestion(spoken: spoken, written: written)
    }

    private func commonPrefixIndex(_ original: String, _ edited: String) -> (original: String.Index, edited: String.Index) {
        var originalIndex = original.startIndex
        var editedIndex = edited.startIndex
        while originalIndex < original.endIndex,
              editedIndex < edited.endIndex,
              original[originalIndex] == edited[editedIndex] {
            original.formIndex(after: &originalIndex)
            edited.formIndex(after: &editedIndex)
        }
        return (originalIndex, editedIndex)
    }

    private func commonSuffixIndices(
        _ original: String,
        _ edited: String,
        after prefix: (original: String.Index, edited: String.Index)
    ) -> (original: String.Index, edited: String.Index) {
        var originalIndex = original.endIndex
        var editedIndex = edited.endIndex
        while originalIndex > prefix.original,
              editedIndex > prefix.edited {
            let previousOriginal = original.index(before: originalIndex)
            let previousEdited = edited.index(before: editedIndex)
            guard original[previousOriginal] == edited[previousEdited] else {
                break
            }
            originalIndex = previousOriginal
            editedIndex = previousEdited
        }
        return (originalIndex, editedIndex)
    }

    private func shouldExpandLeft(
        original: String,
        edited: String,
        originalStart: String.Index,
        editedStart: String.Index
    ) -> Bool {
        guard originalStart > original.startIndex, editedStart > edited.startIndex else {
            return false
        }
        let originalPrevious = original[original.index(before: originalStart)]
        let editedPrevious = edited[edited.index(before: editedStart)]
        return isASCIIWord(originalPrevious) && isASCIIWord(editedPrevious)
    }

    private func startOfPreviousToken(in text: String, before index: String.Index) -> String.Index {
        var current = index
        while current > text.startIndex {
            let previous = text.index(before: current)
            let character = text[previous]
            guard isASCIIWord(character) || character == "-" || character == "." else {
                break
            }
            current = previous
        }
        return current
    }

    private func trimmedTerm(_ text: String) -> String {
        let trimSet = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .subtracting(CharacterSet(charactersIn: ".-+#"))
        return text.trimmingCharacters(in: trimSet)
    }

    private func isPlausible(spoken: String, written: String) -> Bool {
        guard !spoken.isEmpty, !written.isEmpty, spoken != written else {
            return false
        }
        guard spoken.count <= 60, written.count <= 60 else {
            return false
        }
        guard written.count <= spoken.count + 12 || containsASCIIWord(spoken) || containsASCIIWord(written) else {
            return false
        }
        if !containsASCIIWord(spoken) && !containsASCIIWord(written) {
            return spoken.count <= 8 && written.count <= 12
        }
        return true
    }

    private func containsASCIIWord(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (65...90).contains(Int(scalar.value)) ||
                (97...122).contains(Int(scalar.value)) ||
                (48...57).contains(Int(scalar.value))
        }
    }

    private func isASCIIWord(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            (65...90).contains(Int(scalar.value)) ||
                (97...122).contains(Int(scalar.value)) ||
                (48...57).contains(Int(scalar.value))
        }
    }
}
