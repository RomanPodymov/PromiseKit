#if !canImport(ObjectiveC)
import XCTest

#if os(Android)
extension XCTestExpectation {
    func fulfill() {
        fulfill(#file, line: #line)
    }
}
#endif

extension Test212 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test212 = [
        ("test", test),
    ]
}

extension Test213 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test213 = [
        ("test", test),
    ]
}

extension Test222 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test222 = [
        ("test", test),
    ]
}

extension Test223 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test223 = [
        ("test", test),
    ]
}

extension Test224 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test224 = [
        ("test", test),
    ]
}

extension Test226 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test226 = [
        ("test", test),
    ]
}

extension Test227 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test227 = [
        ("test", test),
    ]
}

extension Test231 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test231 = [
        ("test", test),
    ]
}

extension Test232 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test232 = [
        ("test", test),
    ]
}

extension Test234 {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__Test234 = [
        ("test", test),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(Test212.__allTests__Test212),
        testCase(Test213.__allTests__Test213),
        testCase(Test222.__allTests__Test222),
        testCase(Test223.__allTests__Test223),
        testCase(Test224.__allTests__Test224),
        testCase(Test226.__allTests__Test226),
        testCase(Test227.__allTests__Test227),
        testCase(Test231.__allTests__Test231),
        testCase(Test232.__allTests__Test232),
        testCase(Test234.__allTests__Test234),
    ]
}
#endif
