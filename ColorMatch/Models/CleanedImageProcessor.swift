//
//  CleanedImageProcessor.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 4/5/26.
//

import Foundation

func calculateStdDevAndMean(of values: [UInt16]) -> (Double, Int) {
    let N = Double(values.count)
    let mean = values.map { Double($0) }.reduce(0, +) / N
    let stdDev = sqrt(values.map { pow(Double($0) - mean, 2) }.reduce(0, +) / N)

    return (stdDev, Int(mean.rounded()))
}

/*
 * convertRGBtoHSV
 *
 * converts RGB color values (0–255) into HSV representation
 *
 * input: UInt8 _r_, _g_, _b_ (red, green, and blue values)
 * output: (h: Int, s: Int, v: Int) tuple representing hue (0–360), saturation (0–100), and value (0–100)
 */
private func convertPixelToHSV(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> (h: Int, s: Int, v: Int) {
    let r = Double(r) / 255.0
    let g = Double(g) / 255.0
    let b = Double(b) / 255.0

    let cMax = max(r, g, b)
    let cMin = min(r, g, b)
    let delta = cMax - cMin

    var hue: Double = 0
    var saturation: Double = 0
    let value: Double = cMax

    if delta == 0 {
        hue = 0
    } else if cMax == r {
        hue = (g - b) / delta
    } else if cMax == g {
        hue = 2.0 + (b - r) / delta
    } else if cMax == b {
        hue = 4.0 + (r - g) / delta
    }

    if cMax == 0 {
        saturation = 0
    } else {
        saturation = delta / cMax
    }

    hue *= 60
    if hue < 0 { hue += 360 }

    return (h: Int(hue), s: Int(saturation * 100), v: Int(value * 100))
}

private func getBucketLabel(from h: Int, and s: Int, and v: Int) -> (Int, String) {
    if (s <= 5) || (s <= 15 && v <= 20) || (h >= 0 && h <= 45 && s <= 15) {
        return (0, "Neutral")
    } else if h >= 0 && h <= 45 && s > 10 && s <= 70 && v >= 20 && v <= 90 {
        return (0, "Neutral")
    } else {
        switch h {
        case 0..<30:   return (1,  "Red")
        case 30..<60:  return (2,  "Orange")
        case 60..<90:  return (3,  "Yellow")
        case 90..<120: return (4,  "Yellow-green")
        case 120..<150:return (5,  "Green")
        case 150..<180:return (6,  "Cyan-green")
        case 180..<210:return (7,  "Cyan")
        case 210..<240:return (8,  "Blue")
        case 240..<270:return (9,  "Indigo")
        case 270..<300:return (10, "Violet")
        case 300..<330:return (11, "Magenta")
        default:       return (12, "Red-magenta")
        }
    }
}

private func getShadeLevel(from v: Int) -> ShadeLevel {
    switch v {
    case 20..<40:  return .dark
    case 40..<55:  return .medium
    case 55..<101: return .light
    default:       return .neutral
    }
}

private func assignToBucket(pixel: (h: Int, s: Int, v: Int), buckets: inout [ColorBucket]) {
    let label = getBucketLabel(from: pixel.h, and: pixel.s, and: pixel.v)
    let shade = getShadeLevel(from: pixel.v)

    if label == (0, "Neutral") || shade == .neutral {
        if let i = buckets.firstIndex(where: { $0.label == (0, "Neutral") || $0.shade == .neutral }) {
            buckets[i].count += 1
            buckets[i].pixels.append((pixel.h, pixel.s, pixel.v))
        } else {
            buckets.append(ColorBucket(label: (0, "Neutral"), shade: .neutral, count: 1, pixels: [(pixel.h, pixel.s, pixel.v)]))
        }
        return
    }

    if let i = buckets.firstIndex(where: { $0.label == label && $0.shade == shade }) {
        buckets[i].count += 1
        buckets[i].pixels.append((pixel.h, pixel.s, pixel.v))
    } else {
        buckets.append(ColorBucket(label: label, shade: shade, count: 1, pixels: [(pixel.h, pixel.s, pixel.v)]))
    }
}

private func isAdjacentHue(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
    return abs((bucket1.label.0 % 12) - (bucket2.label.0 % 12)) == 1
}

private func isAdjacentShade(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
    return abs(bucket1.shade.value - bucket2.shade.value) == 1 && bucket1.label.0 == bucket2.label.0
}

private func combineAdjacentBuckets(in buckets: inout [ColorBucket]) {
    var potentialAdjacentHues = true
    while potentialAdjacentHues {
        for i in 0..<buckets.count {
            if isAdjacentHue(buckets[i], buckets[(i + 1) % buckets.count]) {
                if buckets[i].hueStdDev < 5.0 && buckets[(i + 1) % buckets.count].hueStdDev < 5.0 {
                    buckets[i].count += buckets[(i + 1) % buckets.count].count
                    buckets[i].meanHue = (buckets[i].meanHue + buckets[(i + 1) % buckets.count].meanHue) / 2
                    buckets.remove(at: (i + 1) % buckets.count)
                    break
                }
            } else {
                potentialAdjacentHues = false
            }
        }
    }
    var potentialAdjacentShades = true
    while potentialAdjacentShades {
        for i in 0..<buckets.count {
            if isAdjacentShade(buckets[i], buckets[(i + 1) % buckets.count]) {
                if abs(buckets[i].meanValue - buckets[(i + 1) % buckets.count].meanValue) < 10 {
                    buckets[i].count += buckets[(i + 1) % buckets.count].count
                    buckets[i].meanHue = (buckets[i].meanHue + buckets[(i + 1) % buckets.count].meanHue) / 2
                    buckets.remove(at: (i + 1) % buckets.count)
                    break
                }
            } else {
                potentialAdjacentShades = false
            }
        }
    }
}

private func getBucketStats(_ buckets: inout [ColorBucket], _ totalPixels: Int) {
    
    for i in buckets.indices {
        buckets[i].percentage = Double(buckets[i].count) / Double(totalPixels) * 100.0
    }

    buckets.sort(by: { $0.count < $1.count })
    var hueArray: [UInt16] = []
    var valueArray: [UInt16] = []
    for i in 0..<buckets.count {
        for pixel in buckets[i].pixels {
            hueArray.append(UInt16(pixel.0))
            valueArray.append(UInt16(pixel.2))
        }
        let (hueStdDev, meanHue) = calculateStdDevAndMean(of: hueArray)
        buckets[i].hueStdDev = hueStdDev
        buckets[i].meanHue = meanHue
        let (valueStdDev, meanValue) = calculateStdDevAndMean(of: valueArray)
        buckets[i].valueStdDev = valueStdDev
        buckets[i].meanValue = meanValue
    }
}

func processCleanedBuffer(_ buffer: [UInt8], _ buckets: inout [ColorBucket]) {
    for i in stride(from: 0, to: buffer.count, by: 4) {
        let r = buffer[i]
        let g = buffer[i+1]
        let b = buffer[i+2]

        let hsv = convertPixelToHSV(r, g, b)
        assignToBucket(pixel: hsv, buckets: &buckets)
        getBucketStats(&buckets, buffer.count / 4)
        combineAdjacentBuckets(in: &buckets)
    }
}
