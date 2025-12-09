import SwiftUI
import SwiftData


// MARK: - Tags Selection View MEMO BEST
struct MemoTagsSelectionView: View {
    @Binding var selectedTags: [String]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var newTagText = ""
    @State private var showAddTag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected Tags Section
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Выбранные теги")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedTags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Text("#\(tag)")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            selectedTags.removeAll { $0 == tag }
                                        }
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
                        Text("Доступные теги")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if !allTags.filter({ !selectedTags.contains($0.name) }).isEmpty {
                            Text("\(allTags.filter { !selectedTags.contains($0.name) }.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
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
                        ForEach(allTags.filter { !selectedTags.contains($0.name) }, id: \.id) { tag in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    if !selectedTags.contains(tag.name) {
                                        selectedTags.append(tag.name)
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.7))
                                    Text("#\(tag.name)")
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
                        Text(showAddTag ? "Скрыть" : "Добавить новый тег")
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
                                TextField("Название тега", text: $newTagText)
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
                                let tagName = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !tagName.isEmpty && !selectedTags.contains(tagName) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        selectedTags.append(tagName)
                                        newTagText = ""
                                        showAddTag = false
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Добавить")
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
                            Text("Все теги")
                    Spacer()
                            if selectedTag == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section("Выберите тег") {
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
            .navigationTitle("Фильтр по тегу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}
