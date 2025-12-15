//
//  SpecComplianceTests.swift
//  jsonlogic
//
//  Official JSONLogic specification compliance tests from https://jsonlogic.com/tests.json
//  These tests ensure cross-platform compatibility with JS and Java implementations.
//

import XCTest
import JSON
@testable import jsonlogic

final class SpecComplianceTests: XCTestCase {

    private var specTests: [[Any]] = []

    override func setUp() {
        super.setUp()
        loadSpecTests()
    }

    private func loadSpecTests() {
        guard let url = Bundle.module.url(forResource: "tests", withExtension: "json") else {
            XCTFail("Could not find tests.json resource")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] else {
                XCTFail("Could not parse tests.json as array")
                return
            }
            specTests = json.compactMap { item -> [Any]? in
                // Skip comment strings (like "# Single operator tests")
                guard let testCase = item as? [Any], testCase.count == 3 else {
                    return nil
                }
                return testCase
            }
        } catch {
            XCTFail("Failed to load tests.json: \(error)")
        }
    }

    func testSpecCompliance() throws {
        var failures: [(rule: String, data: String, expected: String, actual: String, error: String?)] = []
        var passCount = 0

        for testCase in specTests {
            guard testCase.count == 3 else { continue }

            let rule = testCase[0]
            let data = testCase[1]
            let expected = testCase[2]

            let ruleJSON: String
            let dataJSON: String?

            do {
                let ruleData = try JSONSerialization.data(withJSONObject: rule, options: [.fragmentsAllowed])
                ruleJSON = String(data: ruleData, encoding: .utf8) ?? ""

                if data is NSNull {
                    dataJSON = nil
                } else {
                    let dataData = try JSONSerialization.data(withJSONObject: data, options: [.fragmentsAllowed])
                    dataJSON = String(data: dataData, encoding: .utf8) ?? "{}"
                }
            } catch {
                failures.append((
                    rule: "\(rule)",
                    data: "\(data)",
                    expected: "\(expected)",
                    actual: "N/A",
                    error: "Failed to serialize test case: \(error)"
                ))
                continue
            }

            do {
                let result: Any? = try applyRuleReturningAny(ruleJSON, to: dataJSON)

                let isEqual = areEqual(result, expected)
                if !isEqual {
                    failures.append((
                        rule: ruleJSON,
                        data: dataJSON ?? "null",
                        expected: describeValue(expected),
                        actual: describeValue(result),
                        error: nil
                    ))
                } else {
                    passCount += 1
                }
            } catch {
                failures.append((
                    rule: ruleJSON,
                    data: dataJSON ?? "null",
                    expected: describeValue(expected),
                    actual: "N/A",
                    error: "Exception: \(error)"
                ))
            }
        }

        // Report results
        print("\n========== SPEC COMPLIANCE RESULTS ==========")
        print("Passed: \(passCount)/\(specTests.count)")
        print("Failed: \(failures.count)")

        if !failures.isEmpty {
            print("\n---------- FAILURES ----------")
            for (index, failure) in failures.enumerated() {
                print("\n[\(index + 1)] Rule: \(failure.rule)")
                print("    Data: \(failure.data)")
                print("    Expected: \(failure.expected)")
                print("    Actual: \(failure.actual)")
                if let error = failure.error {
                    print("    Error: \(error)")
                }
            }
        }

        XCTAssertEqual(failures.count, 0, "Spec compliance failures: \(failures.count) out of \(specTests.count) tests")
    }

    // MARK: - Helper Methods

    private func applyRuleReturningAny(_ rule: String, to data: String?) throws -> Any? {
        let logic = try JsonLogic(rule)

        // Try different return types to get the actual result
        if let result: Bool = try? logic.applyRule(to: data) {
            return result
        }
        if let result: Int = try? logic.applyRule(to: data) {
            return result
        }
        if let result: Double = try? logic.applyRule(to: data) {
            return result
        }
        if let result: String = try? logic.applyRule(to: data) {
            return result
        }
        if let result: [Any?] = try? logic.applyRule(to: data) {
            return result
        }
        if let result: [String: Any?] = try? logic.applyRule(to: data) {
            return result
        }

        // Try to get Any? directly
        let result: Any? = try logic.applyRule(to: data)
        return result
    }

    private func areEqual(_ a: Any?, _ b: Any?) -> Bool {
        // Normalize both values first
        let normA = normalize(a)
        let normB = normalize(b)

        // Handle nil/null cases
        if normA == nil && normB == nil {
            return true
        }
        guard let valA = normA, let valB = normB else {
            return false
        }

        // Check if values are booleans (important: must check before numbers due to NSNumber bridging)
        let aIsBool = isBoolValue(valA)
        let bIsBool = isBoolValue(valB)

        if aIsBool && bIsBool {
            return getBool(valA) == getBool(valB)
        }

        // If one is bool and other is not, they're not equal
        if aIsBool != bIsBool {
            return false
        }

        // Compare numbers
        if let numA = getNumber(valA), let numB = getNumber(valB) {
            // Check if both are integers
            if numA.truncatingRemainder(dividingBy: 1) == 0 && numB.truncatingRemainder(dividingBy: 1) == 0 {
                return Int(numA) == Int(numB)
            }
            return abs(numA - numB) < 0.0001
        }

        // Compare strings
        if let strA = valA as? String, let strB = valB as? String {
            return strA == strB
        }

        // Compare arrays
        if let arrA = getArray(valA), let arrB = getArray(valB) {
            guard arrA.count == arrB.count else { return false }
            for (itemA, itemB) in zip(arrA, arrB) {
                if !areEqual(itemA, itemB) {
                    return false
                }
            }
            return true
        }

        // Compare dictionaries
        if let dictA = valA as? [String: Any], let dictB = valB as? [String: Any] {
            guard dictA.count == dictB.count else { return false }
            for (key, valueA) in dictA {
                guard let valueB = dictB[key] else { return false }
                if !areEqual(valueA, valueB) {
                    return false
                }
            }
            return true
        }

        return false
    }

    private func normalize(_ value: Any?) -> Any? {
        guard let value = value else { return nil }

        // Handle NSNull
        if value is NSNull { return nil }

        // Try to extract from Optional<Any> using Mirror
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return normalize(child.value)
            }
            return nil
        }

        return value
    }

    private func isBoolValue(_ value: Any) -> Bool {
        // NSNumber boolean detection - must check before Swift Bool because NSNumber bridges to Bool
        if let num = value as? NSNumber {
            // Only CFBoolean instances are true booleans
            return num === kCFBooleanTrue || num === kCFBooleanFalse
        }

        // Swift Bool type (for non-NSNumber bools)
        if value is Bool { return true }

        return false
    }

    private func getBool(_ value: Any) -> Bool? {
        if let b = value as? Bool { return b }
        if let num = value as? NSNumber, CFGetTypeID(num) == CFBooleanGetTypeID() {
            return num.boolValue
        }
        return nil
    }

    private func getNumber(_ value: Any) -> Double? {
        if let i = value as? Int { return Double(i) }
        if let d = value as? Double { return d }
        if let f = value as? Float { return Double(f) }
        if let num = value as? NSNumber {
            // Check if it's actually a boolean - CFBoolean has a specific type
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return nil
            }
            return num.doubleValue
        }
        return nil
    }

    private func getArray(_ value: Any) -> [Any]? {
        if let arr = value as? [Any] { return arr }
        if let arr = value as? [Any?] { return arr.map { $0 as Any } }
        return nil
    }

    private func isBooleanNSNumber(_ value: Any) -> Bool {
        // Swift Bool will match this
        if value is Bool {
            return true
        }
        // NSNumber from JSON that represents boolean
        if let num = value as? NSNumber {
            return CFGetTypeID(num) == CFBooleanGetTypeID()
        }
        return false
    }

    private func unwrap(_ value: Any?) -> Any? {
        guard let value = value else { return nil }

        // Try to deeply unwrap Optional<Any> types
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return unwrap(child.value)
            }
            return nil
        }

        // Handle the case where value is Optional<Any> but mirror doesn't show it
        // This happens when the value is boxed in Any
        if let opt = value as? Any?, let inner = opt {
            // Recursively unwrap if it's still wrapped
            let innerMirror = Mirror(reflecting: inner)
            if innerMirror.displayStyle == .optional {
                return unwrap(inner)
            }
            return inner
        }

        return value
    }

    private func isNumber(_ value: Any) -> Bool {
        return value is Int || value is Double || value is Float || value is Int64 || value is Int32
    }

    private func asInt(_ value: Any) -> Int? {
        // Check for NSNumber first (covers most JSON-parsed numbers)
        if let n = value as? NSNumber {
            // Don't convert booleans to int
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return nil
            }
            if n.doubleValue == floor(n.doubleValue) {
                return n.intValue
            }
            return nil
        }
        if let i = value as? Int { return i }
        if let i = value as? Int64 { return Int(i) }
        if let i = value as? Int32 { return Int(i) }
        if let d = value as? Double, d == floor(d) { return Int(d) }
        return nil
    }

    private func asDouble(_ value: Any) -> Double? {
        if let d = value as? Double { return d }
        if let f = value as? Float { return Double(f) }
        if let i = value as? Int { return Double(i) }
        if let i = value as? Int64 { return Double(i) }
        if let n = value as? NSNumber {
            // Don't convert booleans to double
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return nil
            }
            return n.doubleValue
        }
        return nil
    }

    private func describeValue(_ value: Any?) -> String {
        guard let value = value else { return "nil" }

        let unwrapped = unwrap(value)
        guard let val = unwrapped else { return "nil" }

        if val is NSNull { return "null" }

        // Check for NSNumber and distinguish booleans from integers
        if let num = val as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return num.boolValue ? "true" : "false"
            }
            // Check if it's an integer or double
            if num.doubleValue == floor(num.doubleValue) {
                return "\(num.intValue)"
            }
            return "\(num.doubleValue)"
        }

        if let s = val as? String { return "\"\(s)\"" }
        if let arr = val as? [Any] {
            let items = arr.map { describeValue($0) }.joined(separator: ", ")
            return "[\(items)]"
        }
        if let arr = val as? [Any?] {
            let items = arr.map { describeValue($0) }.joined(separator: ", ")
            return "[\(items)]"
        }
        if let dict = val as? [String: Any] {
            return "\(dict)"
        }

        return "\(val) (\(type(of: val)))"
    }
}
