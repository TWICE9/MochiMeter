// Helpers/AnimatedGIFImage.swift

import SwiftUI
import UIKit
import ImageIO

struct AnimatedGIFImage: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        if let gifImage = UIImage.gifImageWithName(name) {
            imageView.image = gifImage
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // No updates needed
    }
}

extension UIImage {
    static func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif") else {
            print("GIF not found in bundle")
            return nil
        }

        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("Cannot turn image into data")
            return nil
        }

        return gifImageWithData(imageData)
    }

    static func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("Source for image does not exist")
            return nil
        }

        return animatedImageWithSource(source)
    }

    static func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [UIImage]()
        var duration: Double = 0

        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)

                let frameDuration = getFrameDuration(from: source, at: i)
                duration += frameDuration
            }
        }

        let animation = UIImage.animatedImage(with: images, duration: duration)
        return animation
    }

    static func getFrameDuration(from source: CGImageSource, at index: Int) -> Double {
        var frameDuration: Double = 0.1

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return frameDuration
        }

        if let unclampedDelay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double {
            frameDuration = unclampedDelay
        } else if let delay = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
            frameDuration = delay
        }

        // Minimum duration
        if frameDuration < 0.011 {
            frameDuration = 0.1
        }

        return frameDuration
    }
}
