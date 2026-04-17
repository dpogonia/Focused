import Foundation
import SwiftData

struct MemoImpactInfo: Equatable {
    let sphereID: UUID?
    let negativeImpact: Double
}

extension MemoItem {
    func impactInfo() -> MemoImpactInfo {
        guard let data = contentData else { return MemoImpactInfo(sphereID: nil, negativeImpact: 0.0) }
        
        switch itemType {
        case .counter:
            if let content = try? JSONDecoder().decode(MemoCounterContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .list:
            if let content = try? JSONDecoder().decode(MemoListContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .streak:
            if let content = try? JSONDecoder().decode(MemoStreakContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .mood:
            if let content = try? JSONDecoder().decode(MemoMoodContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .skill:
            if let content = try? JSONDecoder().decode(MemoSkillContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .time:
            if let content = try? JSONDecoder().decode(MemoTimeContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .health:
            if let content = try? JSONDecoder().decode(MemoHealthContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .budget:
            if let content = try? JSONDecoder().decode(MemoBudgetContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .calendar:
            if let content = try? JSONDecoder().decode(MemoCalendarContent.self, from: data) { return MemoImpactInfo(sphereID: content.sphereID, negativeImpact: content.negativeImpact) }
        case .noteAlbum:
            break
        }
        
        return MemoImpactInfo(sphereID: nil, negativeImpact: 0.0)
    }
}

enum MemoImpactApplier {
    static func applyNegativeImpactIfNeeded(modelContext: ModelContext, sphereID: UUID?, negativeImpact: Double, apply: Bool) {
        guard apply, let sphereID, negativeImpact > 0 else { return }
        let fetchDescriptor = FetchDescriptor<Sphere>(predicate: #Predicate<Sphere> { $0.id == sphereID })
        if let sphere = try? modelContext.fetch(fetchDescriptor).first {
            let clamped = max(0.0, min(100.0, negativeImpact))
            sphere.satisfaction = max(0.0, min(100.0, sphere.satisfaction - clamped))
            try? modelContext.save()
        }
        NotificationCenter.default.postAppEvent(.sphereSatisfactionDidChange)
    }
}

