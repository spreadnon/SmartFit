import SwiftUI

struct ExerciseImageView: View {
    let imagePath: String
    
    @State private var uiImage: UIImage? = nil
    @State private var didRequestImage = false

    private static let imageCache = NSCache<NSString, UIImage>()
    
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
            loadImage(force: false)
        }
        .onChange(of: imagePath) { _ in
            loadImage(force: true)
        }
    }
    
    private func loadImage(force: Bool) {
        guard !imagePath.isEmpty else {
            uiImage = nil
            didRequestImage = false
            return
        }
        guard force || !didRequestImage else { return }

        let effectiveImagePath = imagePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".jpg", with: "")
        let cacheKey = NSString(string: effectiveImagePath)

        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            uiImage = cachedImage
            didRequestImage = true
            return
        }

        didRequestImage = true
        if force {
            uiImage = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let image = Self.resolveImage(named: effectiveImagePath)

            if let image {
                Self.imageCache.setObject(image, forKey: cacheKey)
            }

            DispatchQueue.main.async {
                // Ignore stale responses if the path changed while loading.
                guard self.imagePath
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: ".jpg", with: "") == effectiveImagePath else {
                    return
                }
                uiImage = image
            }
        }
    }

    private static func resolveImage(named effectiveImagePath: String) -> UIImage? {
        // 1. Try UIImage(named:) first - most robust for Assets and regular Groups
        if let img = UIImage(named: effectiveImagePath) {
            return img
        }
        
        // 2. Try direct asset/resource lookup in bundle root (flattened)
        if let path = Bundle.main.path(forResource: effectiveImagePath, ofType: "jpg") {
            if let img = UIImage(contentsOfFile: path) {
                return img
            }
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
                if let img = UIImage(contentsOfFile: path) {
                    return img
                }
            }
        }
        
        // 5. Final broad fallbacks for named images with prefixes
        if let img = UIImage(named: "exercises/\(effectiveImagePath)") {
            return img
        }

        return nil
    }
}
