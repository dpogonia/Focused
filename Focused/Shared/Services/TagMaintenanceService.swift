import Foundation
import SwiftData

/// Keeps `Tag` table consistent with actual usage across the app.
enum TagMaintenanceService {
    @MainActor
    static func pruneUnusedTags(modelContext: ModelContext) {
        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        guard !tags.isEmpty else { return }
        
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        let habits = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
        let tasks = (try? modelContext.fetch(FetchDescriptor<SuperTask>())) ?? []
        let memos = (try? modelContext.fetch(FetchDescriptor<MemoItem>())) ?? []
        
        func normalizeTagName(_ raw: String) -> String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
            let parts = withoutHash.split(whereSeparator: { $0.isWhitespace })
            return parts.joined(separator: " ")
        }
        
        func tagKey(_ raw: String) -> String {
            normalizeTagName(raw).lowercased()
        }
        
        var usedNameKeys = Set<String>()
        
        for g in goals {
            for t in g.tags {
                let key = tagKey(t.name)
                if !key.isEmpty { usedNameKeys.insert(key) }
            }
        }
        for h in habits {
            for t in h.tags {
                let key = tagKey(t.name)
                if !key.isEmpty { usedNameKeys.insert(key) }
            }
        }
        for s in tasks {
            for t in s.tags {
                let key = tagKey(t.name)
                if !key.isEmpty { usedNameKeys.insert(key) }
            }
        }
        for m in memos {
            for raw in m.tags {
                let key = tagKey(raw)
                if !key.isEmpty { usedNameKeys.insert(key) }
            }
        }
        
        var didDelete = false
        for tag in tags {
            let key = tagKey(tag.name)
            let isUsed = (!key.isEmpty && usedNameKeys.contains(key))
            if !isUsed {
                modelContext.delete(tag)
                didDelete = true
            }
        }
        
        if didDelete {
            try? modelContext.save()
        }
    }
}

