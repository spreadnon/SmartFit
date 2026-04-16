import SwiftUI

struct ExerciseImageView: View {
    let imagePath: String
    
    @State private var uiImage: UIImage? = nil
    
    init(imagePath: String) {
        self.imagePath = imagePath
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(StitchTheme.surfaceContainerHighest)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 20))
                            Text("NO IMAGE")
                                .font(StitchTypography.labelSmall)
                        }
                        .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.4))
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        if imagePath.isEmpty { return }
        
        // Normalize imagePath: replace "/" with "_" and remove ".jpg" extension
        let effectiveImagePath = imagePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".jpg", with: "")
        
        // 1. Try UIImage(named:) first - most robust for Assets and regular Groups
        if let img = UIImage(named: effectiveImagePath) {
            self.uiImage = img
            return
        }
        
        // 2. Try direct asset/resource lookup in bundle root (flattened)
        if let path = Bundle.main.path(forResource: effectiveImagePath, ofType: "jpg") {
            self.uiImage = UIImage(contentsOfFile: path)
            if self.uiImage != nil { return }
        }
        
        // 3. Resolve folder structure using underscores (e.g., "Folder_Name_0" -> folder "Folder_Name")
        let parts = effectiveImagePath.components(separatedBy: "_")
        let folder: String
        if parts.count > 1 {
            folder = parts.dropLast().joined(separator: "_")
        } else {
            folder = ""
        }
        
        // 4. Try looking inside the "exercises" subdirectories (structured Folder References)
        if !folder.isEmpty {
            // Try: exercises/folder/effectiveImagePath.jpg
            if let path = Bundle.main.path(forResource: effectiveImagePath, ofType: "jpg", inDirectory: "exercises/\(folder)") {
                self.uiImage = UIImage(contentsOfFile: path)
                if self.uiImage != nil { return }
            }
        }
        
        // 5. Final broad fallbacks for named images with prefixes
        if let img = UIImage(named: "exercises/\(effectiveImagePath)") {
            self.uiImage = img
        }
    }
}
