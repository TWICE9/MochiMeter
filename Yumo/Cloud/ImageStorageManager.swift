//
//  ImageStorageManager.swift
//  Yumo
//
//  Handles uploading and downloading food images to/from Supabase Storage
//

import Foundation
import UIKit
import Supabase

actor ImageStorageManager {
    static let shared = ImageStorageManager()

    private let bucketName = "food-images"
    private let maxImageSize: CGFloat = 1024  // Max dimension for compression
    private let compressionQuality: CGFloat = 0.7

    private init() {}

    // MARK: - Upload Image

    /// Uploads an image to Supabase Storage and returns the storage path
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - userId: The user's ID for organizing images
    ///   - logId: The food log ID for unique naming
    /// - Returns: The storage path if successful, nil otherwise
    func uploadImage(imageData: Data, userId: String, logId: String) async -> String? {
        // Compress the image first
        guard let compressedData = compressImage(data: imageData) else {
            print("❌ Failed to compress image")
            return nil
        }

        let storagePath = "\(userId)/\(logId).jpg"

        do {
            try await supabase.storage
                .from(bucketName)
                .upload(
                    path: storagePath,
                    file: compressedData,
                    options: FileOptions(
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            print("✅ Image uploaded: \(storagePath) (\(compressedData.count / 1024)KB)")
            return storagePath
        } catch {
            print("❌ Failed to upload image: \(error)")
            return nil
        }
    }

    // MARK: - Download Image

    /// Downloads an image from Supabase Storage
    /// - Parameter path: The storage path of the image
    /// - Returns: The image data if successful, nil otherwise
    func downloadImage(path: String) async -> Data? {
        do {
            let data = try await supabase.storage
                .from(bucketName)
                .download(path: path)

            print("✅ Image downloaded: \(path) (\(data.count / 1024)KB)")
            return data
        } catch {
            print("❌ Failed to download image: \(error)")
            return nil
        }
    }

    // MARK: - Delete Image

    /// Deletes an image from Supabase Storage
    /// - Parameter path: The storage path of the image
    func deleteImage(path: String) async {
        do {
            _ = try await supabase.storage
                .from(bucketName)
                .remove(paths: [path])

            print("✅ Image deleted: \(path)")
        } catch {
            print("❌ Failed to delete image: \(error)")
        }
    }

    // MARK: - Get Public URL

    /// Gets a public URL for an image (if bucket is public)
    /// - Parameter path: The storage path of the image
    /// - Returns: The public URL if available
    func getPublicURL(path: String) -> URL? {
        try? supabase.storage
            .from(bucketName)
            .getPublicURL(path: path)
    }

    // MARK: - Compression

    /// Compresses an image to reduce storage size
    private func compressImage(data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        // Resize if too large
        let resizedImage: UIImage
        if image.size.width > maxImageSize || image.size.height > maxImageSize {
            let scale = min(maxImageSize / image.size.width, maxImageSize / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }

        // Compress as JPEG
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
