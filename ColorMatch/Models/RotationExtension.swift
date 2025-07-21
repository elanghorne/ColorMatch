//
//  RotationExtension.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/21/25.
//

import Foundation
import UIKit

extension UIImage {
    func normalized() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = self.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: self.size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}


/* original normalization
 
 if imageOrientation == .up {
     return self
 }
 guard let cgImage = self.cgImage else { return self }
 
 var transform = CGAffineTransform.identity
 
 switch imageOrientation {
 case .right:
     transform = transform
         .translatedBy(x: size.width, y: 0)
         .rotated(by: -.pi / 2)
 case .left:
     transform = transform
         .translatedBy(x: 0, y: size.height)
         .rotated(by: .pi / 2)
 case .down:
     transform = transform
         .translatedBy(x: size.width, y: size.height)
         .rotated(by: .pi)
 default:
     break
 }
 
 let contextSize: CGSize = imageOrientation == .left || imageOrientation == .right ? CGSize(width: size.height, height: size.width) : size
 
 guard let context = CGContext(
     data: nil,
     width: Int(contextSize.width),
     height: Int(contextSize.height),
     bitsPerComponent: 8,
     bytesPerRow: 0,
     space: CGColorSpaceCreateDeviceRGB(),
     bitmapInfo: cgImage.bitmapInfo.rawValue
 ) else {
     return self
 }
 
 context.concatenate(transform)
 let drawRect = CGRect(origin: .zero, size: contextSize)
 context.setFillColor(UIColor.magenta.cgColor)
 context.fill(CGRect(origin: .zero, size: contextSize))

 context.draw(cgImage, in: drawRect)
 guard let normalizedImage = context.makeImage() else {
     return self
 }
 
 return UIImage(cgImage: normalizedImage)
 
 */
