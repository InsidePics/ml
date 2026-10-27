import CoreGraphics

/// Android's `Geometry.outermost`, line for line: the indexes of `boxes` that
/// are not the same face found twice. ML Kit's accurate detector, with small
/// faces allowed, can return a second, smaller box mostly inside a face (the
/// lower half of a bespectacled face at 1536×2048). A box covered at least
/// `nested` by a larger one is dropped; two people's faces overlap far less,
/// even in a crowd.
enum FaceBoxes {
  static let nested = 0.8

  static func outermost(_ boxes: [CGRect]) -> [Int] {
    boxes.indices.filter { i in
      let box = boxes[i]
      return !boxes.contains { other in
        area(other) > area(box) && covered(box, by: other) >= nested
      }
    }
  }

  private static func area(_ r: CGRect) -> Double {
    Double(max(0, r.width)) * Double(max(0, r.height))
  }

  private static func covered(_ box: CGRect, by other: CGRect) -> Double {
    if area(box) == 0 { return 1 }
    let overlap = box.intersection(other)
    if overlap.isNull || overlap.width <= 0 || overlap.height <= 0 { return 0 }
    return area(overlap) / area(box)
  }
}
