    /*
     * convertRGBtoHSV
     *
     * converts RGB color values (0–255) into HSV representation
     *
     * input: UInt8 _r_, _g_, _b_ (red, green, and blue values)
     * output: (h: Int, s: Int, v: Int) tuple representing hue (0–360), saturation (0–100), and value (0–100)
     */
    private func convertRGBtoHSV(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> (h: Int, s: Int, v: Int) {
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