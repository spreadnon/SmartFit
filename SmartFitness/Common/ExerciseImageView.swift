import SwiftUI

struct ExerciseImageView: View {
    let imagePath: String
    
    @State private var uiImage: UIImage? = nil
    
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
        
        // JSON imagePath is like "3_4_Sit-Up_0"
        // Actual files are in "exercises/3_4_Sit-Up/3_4_Sit-Up_0.jpg"
        
        // Try exact name as resource everywhere first
        if let path = Bundle.main.path(forResource: imagePath, ofType: "jpg") {
            self.uiImage = UIImage(contentsOfFile: path)
            if self.uiImage != nil { return }
        }
        
        // Try extracting folder from name (FOLDER_INDEX -> FOLDER)
        let parts = imagePath.components(separatedBy: "_")
        if parts.count > 1 {
            let folder = parts.dropLast().joined(separator: "_")
            let fileName = imagePath
            
            // Try: exercises/folder/fileName.jpg
            if let path = Bundle.main.path(forResource: fileName, ofType: "jpg", inDirectory: "exercises/\(folder)") {
                self.uiImage = UIImage(contentsOfFile: path)
                if self.uiImage != nil { return }
            }
            
            // Try: exercises/fileName.jpg (if not in subfolder)
            if let path = Bundle.main.path(forResource: fileName, ofType: "jpg", inDirectory: "exercises") {
                self.uiImage = UIImage(contentsOfFile: path)
                if self.uiImage != nil { return }
            }
        }
        
        // Final broad fallbacks for named images/assets
        if let img = UIImage(named: imagePath) {
            self.uiImage = img
        } else if let img = UIImage(named: "exercises/\(imagePath)") {
            self.uiImage = img
        }
    }
}
