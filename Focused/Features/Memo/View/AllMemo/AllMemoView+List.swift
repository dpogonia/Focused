import SwiftUI
import SwiftData

extension AllMemoView {
    // MARK: Панель фильтров (тип, тег, поиск)
    var filterPanel: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Type Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Filter by type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(MemoItemType.allCases) { type in
                        Button {
                            withAnimation(.spring()) {
                                if selectedTypeFilter == type {
                                    selectedTypeFilter = nil
                                } else {
                                    selectedTypeFilter = type
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.iconName)
                                    .font(.title3)
                                    .foregroundColor(selectedTypeFilter == type ? .white : type.color)
                                Text(type.displayName)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTypeFilter == type ? type.color : Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTypeFilter == type ? type.color : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Clear Filters Button
            if selectedTypeFilter != nil || selectedTagFilter != nil {
                Button("Clear filter") {
                    withAnimation(.spring()) {
                        selectedTypeFilter = nil
                        selectedTagFilter = nil
                        searchText = ""
                    }
                }
                .foregroundColor(.red)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color(UIColor.systemBackground))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: Список карточек мемо (после фильтрации)
    var memoList: some View {
        List {
                ForEach(filteredAndSortedItems) { item in
                    MemoCardView(
                        memoItem: item,
                        design: memoDesign,
                        streakReferenceDate: calendarManager.selectedDate,
                        onDoubleTap: {
                            selectedMemoItem = item
                        }
                    )
                    .id(item.id)
                    .mainTabMemoListRowChrome()
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if item.status == .archived {
                                Button {
                                    hapticManager.selectionChanged()
                                    withAnimation(.smooth(duration: 0.35)) {
                                        archiveMemo(item, applyNegativeImpact: false)
                                    }
                                } label: {
                                    Image(systemName: "tray.and.arrow.up")
                                }
                                .tint(.orange)
                            } else {
                                // Edit
                                Button {
                                    memoToEdit = item
                                    newMemoType = item.itemType
                                    currentSheetId = UUID()
                                    showAddEditSheet = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .tint(.yellow)
                                
                                // Archive (with confirmation)
                                Button {
                                    memoPendingArchive = item
                                    showArchiveMemoConfirmation = true
                                } label: {
                                    Image(systemName: "archivebox")
                                }
                                .tint(Color(UIColor.systemGray))
                                
                                // Delete
                                Button(role: .destructive) {
                                    memoPendingDeletion = item
                                    showDeleteMemoConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            leadingSwipeButton(for: item)
                        }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                .onMove(perform: moveMemos)
                .onDelete(perform: deleteMemo)
            }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .padding(.horizontal, 10)
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(0)
        .background(Color(UIColor.systemGroupedBackground))
        .animation(.smooth(duration: 0.4), value: filteredAndSortedItems.map { "\($0.id)-\($0.status.rawValue)-\($0.orderIndex)" })
        .animation(.smooth(duration: 0.4), value: memosOrderKey)
        .refreshable {
            // Simulate refresh
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        .onAppear {
            // Sync calendar visibility with global settings
            calendarManager.isVisible = globalCalendarVisibility
        }
            .onReceive(NotificationCenter.default.publisher(for: .appCalendarVisibilityDidChange)) { _ in
                calendarManager.isVisible = globalCalendarVisibility
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoStatusDidChange)) { _ in
                // Обновляем ключ для триггера анимации перемещения карточек
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    memosOrderKey = UUID()
                }
            }
    }

}

