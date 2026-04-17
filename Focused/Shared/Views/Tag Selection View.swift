import SwiftUI
import SwiftData

// Presentation · Shared — выбор и создание тегов для мемо и фильтров.

// MARK: - Tags Selection View MEMO BEST
struct MemoTagsSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTags: [String]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query private var allGoals: [Goal]
    @Query private var allHabits: [Habit]
    @Query private var allTasks: [SuperTask]
    @Query private var allMemoItems: [MemoItem]

    @State private var newTagText = ""
    @State private var showAddTag = false
    @State private var showDeleteTagConfirmation: Bool = false
    @State private var tagPendingDeletion: String? = nil
    
    private func normalizeTagName(_ raw: String) -> String {
        TagNameNormalizer.storageName(from: raw)
    }
    
    private func tagKey(_ raw: String) -> String {
        TagNameNormalizer.key(from: raw)
    }
    
    private func canonicalTagName(forNormalized normalized: String) -> String {
        let key = tagKey(normalized)
        guard !key.isEmpty else { return normalized }
        
        if let existing = allTags.first(where: { tagKey($0.name) == key }) {
            let n = normalizeTagName(existing.name)
            return n.isEmpty ? normalized : n
        }
        
        // Memo uses string tags; use them as a fallback source of casing.
        for memo in allMemoItems {
            if let raw = memo.tags.first(where: { tagKey($0) == key }) {
                let n = normalizeTagName(raw)
                if !n.isEmpty { return n }
            }
        }
        
        return normalized
    }
    
    private var dedupedSelectedTags: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for t in selectedTags {
            let normalized = normalizeTagName(t)
            guard !normalized.isEmpty else { continue }
            let key = tagKey(normalized)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(normalized)
        }
        return out
    }
    
    private var availableTagNames: [String] {
        // Deduplicate tags (SwiftData `Tag` + memo string tags) and exclude currently selected (case-insensitive).
        let selectedKeys = Set(dedupedSelectedTags.map(tagKey))
        var seen = Set<String>()
        var out: [String] = []
        
        // 1) SwiftData tags
        for tag in allTags {
            let normalized = normalizeTagName(tag.name)
            guard !normalized.isEmpty else { continue }
            let key = tagKey(normalized)
            guard !selectedKeys.contains(key) else { continue }
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(normalized)
        }
        
        // 2) Memo string tags (in case Tag table doesn't contain them yet)
        for memo in allMemoItems {
            for raw in memo.tags {
                let normalized = normalizeTagName(raw)
                guard !normalized.isEmpty else { continue }
                let key = tagKey(normalized)
                guard !selectedKeys.contains(key) else { continue }
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(canonicalTagName(forNormalized: normalized))
            }
        }
        
        return out.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private func ensureTagExists(named rawName: String) {
        let normalized = canonicalTagName(forNormalized: normalizeTagName(rawName))
        let key = tagKey(normalized)
        guard !key.isEmpty else { return }
        
        // Avoid duplicates (case-insensitive).
        if allTags.contains(where: { tagKey($0.name) == key }) { return }
        
        modelContext.insert(Tag(name: normalized))
        try? modelContext.save()
    }
    
    private func pruneTagIfUnused(named rawName: String) {
        let normalized = normalizeTagName(rawName)
        let key = tagKey(normalized)
        guard !key.isEmpty else { return }
        
        // If it's still selected in current editor, it's used.
        if selectedTags.contains(where: { tagKey($0) == key }) { return }
        
        // If referenced anywhere else in the app, keep it.
        let usedByGoals = allGoals.contains { $0.tags.contains(where: { tagKey($0.name) == key }) }
        if usedByGoals { return }
        let usedByHabits = allHabits.contains { $0.tags.contains(where: { tagKey($0.name) == key }) }
        if usedByHabits { return }
        let usedByTasks = allTasks.contains { $0.tags.contains(where: { tagKey($0.name) == key }) }
        if usedByTasks { return }
        let usedByMemos = allMemoItems.contains { $0.tags.contains(where: { tagKey($0) == key }) }
        if usedByMemos { return }
        
        // Otherwise remove Tag records.
        for tag in allTags where tagKey(tag.name) == key {
            modelContext.delete(tag)
        }
        try? modelContext.save()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected Tags Section
            if !dedupedSelectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected tags")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dedupedSelectedTags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Text("#\(tag)")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            let removeKey = tagKey(tag)
                                            selectedTags.removeAll { tagKey($0) == removeKey }
                                        }
                                        pruneTagIfUnused(named: tag)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary.opacity(0.7))
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.accentColor)
                                .transition(.scale.combined(with: .opacity))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        tagPendingDeletion = tag
                                        showDeleteTagConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            // Available Tags Section
            if !allTags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available tags")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if !availableTagNames.isEmpty {
                            Text("\(availableTagNames.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, ListDetailChipMetrics.horizontalPadding)
                                .padding(.vertical, ListDetailChipMetrics.verticalPadding)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 90), spacing: 8),
                            GridItem(.adaptive(minimum: 90), spacing: 8),
                            GridItem(.adaptive(minimum: 90), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(availableTagNames, id: \.self) { name in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    let key = tagKey(name)
                                    if !selectedTags.contains(where: { tagKey($0) == key }) {
                                        selectedTags.append(name)
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.7))
                                    Text("#\(name)")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .contextMenu {
                                Button(role: .destructive) {
                                    tagPendingDeletion = name
                                    showDeleteTagConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            // Add New Tag Section
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showAddTag.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showAddTag ? "minus.circle.fill" : "plus.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                            .symbolRenderingMode(.hierarchical)
                        Text(showAddTag ? "Hide" : "Add new tag")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        if showAddTag {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showAddTag {
                    VStack(spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            HStack {
                                Image(systemName: "tag")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                TextField("tag name", text: $newTagText)
                                    .font(.system(size: 15, design: .rounded))
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                    )
                            )

                            Button(action: {
                                let raw = normalizeTagName(newTagText)
                                let tagName = canonicalTagName(forNormalized: raw)
                                let key = tagKey(tagName)
                                if !tagName.isEmpty && !selectedTags.contains(where: { tagKey($0) == key }) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        ensureTagExists(named: tagName)
                                        selectedTags.append(tagName)
                                        newTagText = ""
                                        showAddTag = false
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Add")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                    Color.gray.opacity(0.3) :
                                    Color.accentColor
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTags)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showAddTag)
        .onAppear {
            // Keep selection list clean if it already contains duplicates.
            let cleaned = dedupedSelectedTags
            if cleaned != selectedTags {
                selectedTags = cleaned
            }
        }
        .confirmationDialog(
            "Delete tag?",
            isPresented: $showDeleteTagConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let raw = tagPendingDeletion else { return }
                deleteTagEverywhere(named: raw)
                tagPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                tagPendingDeletion = nil
            }
        } message: {
            Text("This tag will be deleted from the app and detached from all objects.")
        }
    }
    
    private func deleteTagEverywhere(named rawName: String) {
        let normalized = normalizeTagName(rawName)
        let key = tagKey(normalized)
        guard !key.isEmpty else { return }
        
        // 1) Remove from current editor selection.
        selectedTags.removeAll { tagKey($0) == key }
        
        // 2) Detach from all objects that reference Tag models.
        for g in allGoals {
            g.tags.removeAll { tagKey($0.name) == key }
        }
        for h in allHabits {
            h.tags.removeAll { tagKey($0.name) == key }
        }
        for t in allTasks {
            t.tags.removeAll { tagKey($0.name) == key }
        }
        
        // 3) Remove from memos (string tags).
        for memo in allMemoItems {
            if memo.tags.contains(where: { tagKey($0) == key }) {
                memo.tags.removeAll { tagKey($0) == key }
            }
        }
        
        // 4) Delete Tag objects from SwiftData.
        for tag in allTags where tagKey(tag.name) == key {
            modelContext.delete(tag)
        }
        
        try? modelContext.save()
    }
}




// MARK: - Tag Filter View
struct TagFilterView: View {
    @Binding var selectedTag: String?
    let allTags: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        selectedTag = nil
                        dismiss()
                    }) {
                HStack {
                            Text("All tags")
                    Spacer()
                            if selectedTag == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section("Select tag") {
                    ForEach(allTags, id: \.self) { tag in
                        Button(action: {
                            selectedTag = tag
                            dismiss()
                        }) {
                HStack {
                                Text(tag)
                    Spacer()
                                if selectedTag == tag {
                                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
