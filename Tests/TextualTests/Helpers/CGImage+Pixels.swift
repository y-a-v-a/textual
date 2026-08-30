#if canImport(CoreGraphics)
  import CoreGraphics

  extension CGImage {
    /// A single opaque-enough pixel of a rendered image, in device RGB.
    struct Pixel {
      let red: Double
      let green: Double
      let blue: Double

      /// How far this pixel is from gray, from `0` (gray) to `1` (fully saturated).
      var saturation: Double {
        let maximum = max(red, green, blue)
        guard maximum > 0 else { return 0 }
        return (maximum - min(red, green, blue)) / maximum
      }

      /// The pixel's hue in degrees, from `0` to `360`.
      var hue: Double {
        let maximum = max(red, green, blue)
        let delta = maximum - min(red, green, blue)
        guard delta > 0 else { return 0 }

        let hue =
          switch maximum {
          case red: (green - blue) / delta
          case green: 2 + (blue - red) / delta
          default: 4 + (red - green) / delta
          }

        return (hue * 60).truncatingRemainder(dividingBy: 360) + 360
      }
    }

    /// The number of drawn pixels that satisfy `predicate`.
    ///
    /// Transparent pixels are skipped, so an untouched background never counts.
    func countPixels(where predicate: (Pixel) -> Bool) -> Int {
      var count = 0
      forEachPixel { if predicate($0) { count += 1 } }
      return count
    }

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
      var counts = [Int](repeating: 0, count: hueBucketCount)

      forEachPixel { pixel in
        guard pixel.saturation >= minimumSaturation else { return }
        let bucket = Int(pixel.hue / 360 * Double(hueBucketCount)) % hueBucketCount
        counts[bucket] += 1
      }

      return counts.count { $0 >= minimumPixelsPerHue }
    }

    private func forEachPixel(_ body: (Pixel) -> Void) {
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
        return
      }

      context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

      for offset in stride(from: 0, to: pixels.count, by: 4) {
        guard pixels[offset + 3] > 200 else { continue }

        body(
          Pixel(
            red: Double(pixels[offset]) / 255,
            green: Double(pixels[offset + 1]) / 255,
            blue: Double(pixels[offset + 2]) / 255
          )
        )
      }
    }
  }
#endif
