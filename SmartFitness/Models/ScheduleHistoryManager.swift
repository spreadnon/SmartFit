import Foundation
import UIKit

class ScheduleHistoryManager: ObservableObject {
    static let shared = ScheduleHistoryManager()
    
    @Published var records: [ScheduleHistoryRecord] = []
    
    private let recordsKey = "schedule_history_records"
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var imagesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("ScheduleImages")
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    private init() {
        loadRecords()
    }
    
    func saveRecord(schedule: Schedule, image: UIImage?) {
        var imageName: String?
        if let image = image {
            let name = "\(UUID().uuidString).jpg"
            let fileURL = imagesDirectory.appendingPathComponent(name)
            if let data = image.jpegData(compressionQuality: 0.7) {
                try? data.write(to: fileURL)
                imageName = name
            }
        }
        
        let record = ScheduleHistoryRecord(
            id: UUID(),
            schedule: schedule,
            imageName: imageName,
            createdAt: Date()
        )
        
        records.insert(record, at: 0)
        saveToUserDefaults()
    }
    
    func deleteRecord(_ record: ScheduleHistoryRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            deleteRecord(at: IndexSet(integer: index))
        }
    }
    
    func deleteRecord(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let record = records[index]
            if let imageName = record.imageName {
                let fileURL = imagesDirectory.appendingPathComponent(imageName)
                try? fileManager.removeItem(at: fileURL)
            }
        }
        records.remove(atOffsets: indexSet)
        saveToUserDefaults()
    }
    
    func loadImage(named name: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(name)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([ScheduleHistoryRecord].self, from: data) {
            self.records = decoded
        }
    }
}
