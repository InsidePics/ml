import CoreGraphics
import XCTest
@testable import ExpoMlKit

/// Android's `GeometryTests` for `outermost`, case for case.
final class FaceBoxesTests: XCTestCase {
  func testAFaceFoundAgainInsideItselfIsDropped() {
    // The bespectacled fixture at 1536×2048: the face, and its lower half.
    let face = CGRect(x: 380, y: 357, width: 699, height: 907)
    let lowerHalf = CGRect(x: 346, y: 529, width: 455, height: 470)
    XCTAssertEqual(FaceBoxes.outermost([face, lowerHalf]), [0])
    XCTAssertEqual(FaceBoxes.outermost([lowerHalf, face]), [1])
  }

  func testNeighbouringFacesAreAllKept() {
    let adult = CGRect(x: 0, y: 0, width: 100, height: 100)
    let childInFront = CGRect(x: 70, y: 60, width: 60, height: 60)
    let apart = CGRect(x: 300, y: 0, width: 100, height: 100)
    XCTAssertEqual(FaceBoxes.outermost([adult, childInFront, apart, apart]), [0, 1, 2, 3])
  }

  func testAnEmptyBoxInsideAFaceIsDropped() {
    let face = CGRect(x: 0, y: 0, width: 10, height: 10)
    XCTAssertEqual(FaceBoxes.outermost([face, CGRect(x: 5, y: 5, width: 0, height: 0)]), [0])
  }
}
