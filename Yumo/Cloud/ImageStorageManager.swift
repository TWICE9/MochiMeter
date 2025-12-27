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

    // MARK: - Private Helpers

    /// Generates a random suffix to make storage paths unpredictable
    private func generateRandomSuffix(length: Int = 8) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }

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
            #if DEBUG
            print("Failed to compress image")
            #endif
            return nil
        }

        // Add random suffix to prevent enumeration attacks
        let randomSuffix = generateRandomSuffix()
        let storagePath = "\(userId)/\(logId)_\(randomSuffix).jpg"

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

            #if DEBUG
            print("Image uploaded successfully")
            #endif
            return storagePath
        } catch {
            #if DEBUG
            print("Failed to upload image: \(error.localizedDescription)")
            #endif
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

            #if DEBUG
            print("Image downloaded successfully")
            #endif
            return data
        } catch {
            #if DEBUG
            print("Failed to download image: \(error.localizedDescription)")
            #endif
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

            #if DEBUG
            print("Image deleted successfully")
            #endif
        } catch {
            #if DEBUG
            print("Failed to delete image: \(error.localizedDescription)")
            #endif
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
