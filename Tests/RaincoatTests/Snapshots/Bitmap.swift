#if os(iOS)
    import CoreGraphics
    import Foundation
    import ImageIO

    /// An image as 8-bit sRGB pixels from the top left, each red, green, blue, and alpha, with the
    /// alpha premultiplied. The snapshots compare drawings in this form and save them as PNG.
    struct Bitmap: Sendable {
        let width: Int
        let height: Int
        let pixels: [UInt8]

        init(width: Int, height: Int, pixels: [UInt8]) {
            precondition(pixels.count == width * height * 4)
            self.width = width
            self.height = height
            self.pixels = pixels
        }

        /// Redraws an image in this form.
        init(_ image: CGImage) throws {
            let width = image.width
            let height = image.height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = buffer.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) -> Bool in
                guard
                    let context = CGContext(
                        data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: Self.sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    )
                else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard drawn else { throw BitmapError("could not redraw a \(width)×\(height) image") }
            self.init(width: width, height: height, pixels: buffer)
        }

        /// The pixel at a point, with the origin at the top left: red, green, blue, alpha.
        func pixel(_ x: Int, _ y: Int) -> [Int] {
            let start = (y * width + x) * 4
            return pixels[start..<start + 4].map(Int.init)
        }

        /// Reads a PNG file, or returns nil when there is none.
        static func read(_ url: URL) throws -> Bitmap? {
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
            guard
                let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { throw BitmapError("\(url.lastPathComponent) is not an image") }
            return try Bitmap(image)
        }

        /// Writes the image as a PNG file, and the folders it goes in.
        func write(to url: URL) throws {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            guard
                let provider = CGDataProvider(data: Data(pixels) as CFData),
                let image = CGImage(
                    width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: width * 4, space: Self.sRGB,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
                ),
                let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
            else { throw BitmapError("could not write \(url.lastPathComponent)") }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw BitmapError("could not write \(url.lastPathComponent)")
            }
        }

        /// The pixels of this image that differ from a baseline: those where a channel differs by
        /// more than the tolerance, and, when the two are not the same size, every pixel outside
        /// either. The image shows them in red, over a faded copy of the baseline.
        func differences(from baseline: Bitmap, tolerance: Int) -> (count: Int, image: Bitmap) {
            let columns = max(width, baseline.width)
            let rows = max(height, baseline.height)
            var marked = [UInt8](repeating: 255, count: columns * rows * 4)
            var count = 0
            pixels.withUnsafeBufferPointer { drawn in
                baseline.pixels.withUnsafeBufferPointer { expected in
                    marked.withUnsafeMutableBufferPointer { image in
                        for y in 0..<rows {
                            for x in 0..<columns {
                                let at = (y * columns + x) * 4
                                if x < width, y < height, x < baseline.width, y < baseline.height {
                                    let mine = (y * width + x) * 4
                                    let theirs = (y * baseline.width + x) * 4
                                    var same = true
                                    for channel in 0..<4
                                    where abs(Int(drawn[mine + channel]) - Int(expected[theirs + channel])) > tolerance {
                                        same = false
                                    }
                                    if same {
                                        let luma =
                                            0.299 * Double(expected[theirs]) + 0.587 * Double(expected[theirs + 1])
                                            + 0.114 * Double(expected[theirs + 2])
                                        let faded = UInt8((255 - (255 - luma) * 0.1).rounded())
                                        image[at] = faded
                                        image[at + 1] = faded
                                        image[at + 2] = faded
                                        continue
                                    }
                                }
                                count += 1
                                image[at] = 255
                                image[at + 1] = 0
                                image[at + 2] = 0
                            }
                        }
                    }
                }
            }
            return (count, Bitmap(width: columns, height: rows, pixels: marked))
        }

        private static var sRGB: CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }
    }

    struct BitmapError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
#endif
