import CoreGraphics
import Foundation
import Testing

@testable import Textual

struct ImageHashingTests {
  @Test func equalImagesHashEqually() {
    let cgImage = makeCGImage()
    let first = Image(
      frames: [.init(cgImage: cgImage, delayTime: 0.1), .init(cgImage: cgImage, delayTime: 0.2)],
      loopCount: 3,
      size: CGSize(width: 1, height: 1)
    )
    let second = first

    #expect(first == second)
    #expect(first.hashValue == second.hashValue)
  }

  @Test func differentFirstFramesHashDifferently() {
    let first = makeImage()
    let second = makeImage()

    #expect(first != second)
    #expect(first.hashValue != second.hashValue)
  }

  // MARK: - Helpers

  private func makeImage() -> Image {
    Image(
      frames: [.init(cgImage: makeCGImage(), delayTime: 0)],
      loopCount: 0,
      size: CGSize(width: 1, height: 1)
    )
  }

  private func makeCGImage() -> CGImage {
    let context = CGContext(
      data: nil,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
  }
}
