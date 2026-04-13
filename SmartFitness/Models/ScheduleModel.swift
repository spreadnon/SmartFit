import Foundation
import UIKit

struct Schedule: Codable, Equatable {
    var title: String
    var start_time: String
    var end_time: String
    var location: String
    var remark: String
}

struct ScheduleHistoryRecord: Codable, Identifiable {
    let id: UUID
    var schedule: Schedule
    var imageName: String?
    let createdAt: Date
    
    var dateString: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: createdAt)
    }
}
