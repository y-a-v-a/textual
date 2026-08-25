#if canImport(CoreGraphics)
  import CoreGraphics

  extension CGImage {
    /// The number of distinct hues drawn in this image.
    ///
    /// Grays and near-grays are ignored, so text drawn in the default foreground color does not
    /// count. Hues are bucketed and buckets with only a handful of pixels are dropped, so
    /// antialiased edges around a glyph do not register as extra colors.
    ///
    /// Use this to assert that syntax highlighting reached the drawn output: unhighlighted code
    /// has no hues, while highlighted code has one per token color.
    func distinctHueCount(
      minimumSaturation: Double = 0.35,
      minimumPixelsPerHue: Int = 16,
      hueBucketCount: Int = 12
    ) -> Int {
      var pixels = [UInt8](repeating: 0, count: width * height * 4)

      guard
        let context = CGContext(
          data: &pixels,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      else {
        return 0
      }

      context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

      var counts = [Int](repeating: 0, count: hueBucketCount)

      for offset in stride(from: 0, to: pixels.count, by: 4) {
        guard pixels[offset + 3] > 200 else { continue }

        let red = Double(pixels[offset]) / 255
        let green = Double(pixels[offset + 1]) / 255
        let blue = Double(pixels[offset + 2]) / 255

        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum

        guard maximum > 0, delta / maximum >= minimumSaturation else { continue }

        let hue =
          switch maximum {
          case red: (green - blue) / delta
          case green: 2 + (blue - red) / delta
          default: 4 + (red - green) / delta
          }
        let degrees = (hue * 60).truncatingRemainder(dividingBy: 360) + 360

        counts[Int(degrees / 360 * Double(hueBucketCount)) % hueBucketCount] += 1
      }

      return counts.count { $0 >= minimumPixelsPerHue }
    }
  }
#endif
