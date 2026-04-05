//
//  ImagePreprocessor.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 4/5/26.
//

import SwiftUI
import Vision

/*
 * detectBody
 *
 * detects human body in provided image and provides bounding box for cropping
 *
 * input: CGImage _image_
 * output: CGRect _boundingBox_
 */
private func detectBody(in image: CGImage) throws -> CGRect {
    let bodyDetectionRequest = VNDetectHumanRectanglesRequest()
    bodyDetectionRequest.upperBodyOnly = false
    let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
        try requestHandler.perform([bodyDetectionRequest])
    } catch {
        throw AnalysisError.bodyDetectionRequest
    }
    guard let observation = bodyDetectionRequest.results, !observation.isEmpty else {
        throw AnalysisError.noHumanFound
    }
    if observation.count > 1 {
        throw AnalysisError.multipleHumansFound
    }
    return observation[0].boundingBox
}

/*
 * cropBody
 *
 * crops cgImage to provided bounding box
 *
 * input: CGImage _image_, CGRect _rectangle_
 * output: CGImage _cgImage_ (cropped image)
 */
private func cropBody(in image: CGImage, to rectangle: CGRect) throws -> CGImage {
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let convertedRect = CGRect(
        x: width * rectangle.origin.x,
        y: height * (1 - rectangle.origin.y - rectangle.height),
        width: width * rectangle.width,
        height: height * rectangle.height
    )
    guard let croppedImage = image.cropping(to: convertedRect) else {
        throw AnalysisError.failedCrop
    }
    return croppedImage
}

/*
 * detectFace
 *
 * detects face in image and provides bounding box (used to crop image above the shoulder)
 *
 * input: CGImage _image_
 * output: CGRect optional
 */
private func detectFace(in image: CGImage) throws -> CGRect? {
    let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
        try requestHandler.perform([faceDetectionRequest])
    } catch {
        throw AnalysisError.faceDetectionRequest
    }
    guard let observation = faceDetectionRequest.results, !observation.isEmpty else {
        return nil
    }
    return observation[0].boundingBox
}

/*
 * cropFace
 *
 * crops image horizontally using the detected face bounding box, keeping only the region below
 *
 * input: CGRect _rectangle_ (bounding box of face), CGImage _image_ (full body image)
 * output: CGImage _cgImage_ (cropped image with face removed)
 */
private func cropFace(_ rectangle: CGRect, outOf image: CGImage) throws -> CGImage {
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let convertedRect = CGRect(
        x: 0,
        y: height * (1 - rectangle.origin.y),
        width: width,
        height: height - (height * rectangle.height)
    )
    guard let croppedImage = image.cropping(to: convertedRect) else {
        throw AnalysisError.failedCrop
    }
    return croppedImage
}

/*
 * getPixelData
 *
 * extracts raw RGBA pixel data from CGImage and returns flat byte array
 *
 * input: CGImage _image_
 * output: [UInt8] _pixelData_ (flattened RGBA values or nil on failure)
 */
private func getPixelData(from image: CGImage) throws -> [UInt8] {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let totalBytes = height * bytesPerRow

    var pixelData = [UInt8](repeating: 0, count: totalBytes)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw AnalysisError.imageConversionFailed
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixelData
}



func preprocess(_ image: UIImage, _ isWorn: Bool) throws -> [UInt8] {
    var croppedFaceImage: CGImage?
    
    let orientedImage = image.normalized()
    guard let cgImage = orientedImage.cgImage else {
        throw AnalysisError.imageConversionFailed
    }

    if isWorn {
        
        let bodyBox = try detectBody(in: cgImage)
        
        let croppedBodyImage = try cropBody(in: cgImage, to: bodyBox)

        if let faceBox = try detectFace(in: croppedBodyImage) {
            croppedFaceImage = try cropFace(faceBox, outOf: croppedBodyImage)
        }

        
        if let cropped = croppedFaceImage {
            return try getPixelData(from: cropped)
        } else {
            return try getPixelData(from: croppedBodyImage)
        }
    }
    else {
        return try getPixelData(from: cgImage)
    }
}
