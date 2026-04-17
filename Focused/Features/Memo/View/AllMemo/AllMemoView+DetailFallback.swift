import SwiftUI
import SwiftData

extension AllMemoView {
    @ViewBuilder
    func memoDetailFallback(_ item: MemoItem) -> some View {
    Text("Unknown memo type")
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectedMemoItem = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
        }

    }
}
