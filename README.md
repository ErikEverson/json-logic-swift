# jsonlogic-swift

A native Swift JsonLogic implementation. This parser accepts [JsonLogic](http://jsonlogic.com)
rules and executes them.

JsonLogic is a way to write rules that involve computations in JSON format. These can be applied on JSON data with consistent results, allowing you to share rules between server and clients in a common format.

This fork has been updated for **Swift 6** and **iOS 18+** with full spec compliance.

## Features

- Full [JSONLogic specification](http://jsonlogic.com/operations.html) compliance (278 official tests pass)
- Swift 6 language mode with strict concurrency safety
- `Sendable` conformance for all public types
- iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ support
- Custom operator support

## Installation

### Using Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/json-logic-swift", from: "2.0.0")
]
```

And add `jsonlogic` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["jsonlogic"]
)
```

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS      | 18.0            |
| macOS    | 15.0            |
| tvOS     | 18.0            |
| watchOS  | 11.0            |
| visionOS | 2.0             |
| Swift    | 6.0             |

## Usage

Import the module and call the `applyRule` function:

```swift
import jsonlogic

let rule = """
{ "var" : "name" }
"""
let data = """
{ "name" : "Jon" }
"""

let result: String = try applyRule(rule, to: data)
print(result) // "Jon"
```

### Reusing Parsed Rules

If you need to apply the same rule to multiple data objects, parse once and reuse:

```swift
let jsonlogic = try JsonLogic(rule)

let result1: Bool = try jsonlogic.applyRule(to: data1)
let result2: Bool = try jsonlogic.applyRule(to: data2)
```

## Examples

### Simple Comparison

```swift
let rule = """
{ "==" : [1, 1] }
"""

let result: Bool = try applyRule(rule)
// true
```

### Compound Logic

```swift
let rule = """
{"and" : [
  { ">" : [3,1] },
  { "<" : [1,3] }
]}
"""
let result: Bool = try applyRule(rule)
// true
```

### Data-Driven Rules

Access data using the `var` operator:

```swift
let rule = """
{ "var" : "a" }
"""
let data = """
{ "a" : 1, "b" : 2 }
"""
let result: Int = try applyRule(rule, to: data)
// 1
```

Access nested properties with dot notation:

```swift
let rule = """
{ "var" : "user.profile.name" }
"""
let data = """
{ "user" : { "profile" : { "name" : "Alice" } } }
"""
let result: String = try applyRule(rule, to: data)
// "Alice"
```

Access array elements by index:

```swift
let rule = """
{ "var" : 1 }
"""
let data = """
["apple", "banana", "carrot"]
"""
let result: String = try applyRule(rule, to: data)
// "banana"
```

### Complex Example

```swift
let rule = """
{ "and" : [
  {"<" : [ { "var" : "temp" }, 110 ]},
  {"==" : [ { "var" : "pie.filling" }, "apple" ] }
]}
"""
let data = """
{ "temp" : 100, "pie" : { "filling" : "apple" } }
"""

let result: Bool = try applyRule(rule, to: data)
// true
```

### Custom Operators

Register custom operators:

```swift
import jsonlogic
import JSON

let customRules: [String: (JSON?) -> JSON] = [
    "numberOfElementsInArray": { json in
        switch json {
        case let .Array(array):
            return JSON(array.count)
        default:
            return JSON(0)
        }
    }
]

let rule = """
{ "numberOfElementsInArray" : [1, 2, 3] }
"""

let value: Int = try JsonLogic(rule, customOperators: customRules).applyRule()
// 3
```

## Supported Operators

All [standard JSONLogic operators](http://jsonlogic.com/operations.html) are supported:

- **Logic**: `if`/`?:`, `==`, `===`, `!=`, `!==`, `!`, `!!`, `or`, `and`
- **Numeric**: `>`, `>=`, `<`, `<=`, `max`, `min`, `+`, `-`, `*`, `/`, `%`
- **Array**: `map`, `reduce`, `filter`, `all`, `some`, `none`, `merge`, `in`
- **String**: `cat`, `substr`, `in`
- **Data Access**: `var`, `missing`, `missing_some`
- **Utility**: `log`

## Thread Safety

All public types conform to `Sendable` and are safe for use across actor boundaries:

```swift
actor RuleEngine {
    private let rule: JsonLogic

    init(rule: String) throws {
        self.rule = try JsonLogic(rule)
    }

    func evaluate(data: String) throws -> Bool {
        try rule.applyRule(to: data)
    }
}
```

## Error Handling

```swift
public enum JSONLogicError: Error {
    case canNotParseJSONData(String)
    case canNotParseJSONRule(String)
    case canNotConvertResultToType(Any.Type)
}
```

## Contributing

Contributions are welcome! Please ensure all tests pass before submitting PRs:

```bash
swift test
```

The test suite includes 278 official JSONLogic specification tests plus additional unit tests.

## License

JsonLogic for Swift is available under the MIT license. See the LICENSE file for more info.
