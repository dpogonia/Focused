import SwiftUI // 28
import SwiftData

// MARK: - Memo Header View
struct MemoHeaderView: View {
    let item: MemoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(item.itemType.gradient)
                        .frame(width: 50, height: 50)

                    Image(systemName: item.itemType.iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        Label {
                            Text(item.creationDate, style: .date)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)

                        if !item.tags.isEmpty {
                            Label {
                                Text("\(item.tags.count) тег\(item.tags.count == 1 ? "" : "а")")
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "tag")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }

                Spacer()
            }

            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        if item.tags.count > 5 {
                            Text("+\(item.tags.count - 5)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Empty Memo View
struct EmptyMemoView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Пустое мемо")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Данные отсутствуют")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
