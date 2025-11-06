# Swift/iOS Guide for Python Developers

This guide helps you understand the PulseTempo iOS frontend code if you're coming from a Python/FastAPI background.

## 📁 File Structure Overview

```
PulseTempo/
├── PulseTempoApp.swift          # App entry point (like if __name__ == "__main__")
├── ContentView.swift             # Main UI screen (like a Jinja2 template or React component)
├── Models.swift                  # Data models (like Pydantic models or dataclasses)
├── RunSessionViewModel.swift     # Business logic (like a FastAPI service class)
└── Services/
    ├── HealthKitManager.swift    # HealthKit setup (like a database connection manager)
    └── HeartRateService.swift    # Heart rate monitoring (like a WebSocket service)
```

## 🔑 Key Swift Concepts for Python Developers

### 1. **Optionals (`?` and `!`)**
Swift's way of handling `None`/`null`:

```swift
// Swift
var name: String?  // Can be nil (like Optional[str] in Python)
let value = name ?? "default"  // Nil coalescing (like: name if name else "default")

// Python equivalent
name: Optional[str] = None
value = name if name is not None else "default"
```

### 2. **Property Wrappers (`@State`, `@Published`, etc.)**
Special attributes that add behavior:

```swift
// Swift
@State private var count = 0  // Auto-updates UI when changed

// Python analogy (not exact, but similar concept)
from observable import observable

@observable
class MyClass:
    count: int = 0  # Observers notified on change
```

### 3. **Closures `{ }` (Like Lambda Functions)**
Anonymous functions:

```swift
// Swift
let numbers = [1, 2, 3]
let doubled = numbers.map { $0 * 2 }  // $0 is first parameter

// Python
numbers = [1, 2, 3]
doubled = list(map(lambda x: x * 2, numbers))
# or: doubled = [x * 2 for x in numbers]
```

### 4. **Guard Statements (Early Returns)**
Opposite of `if` - exits if condition is false:

```swift
// Swift
guard user != nil else { return }
// Continue with user...

// Python equivalent
if user is None:
    return
# Continue with user...
```

### 5. **Protocols (Like Python's Protocols/ABCs)**
Define interfaces that types must conform to:

```swift
// Swift
protocol Drawable {
    func draw()
}

// Python
from typing import Protocol

class Drawable(Protocol):
    def draw(self) -> None: ...
```

## 🎨 SwiftUI Layout Concepts

### Stack Views (Like CSS Flexbox)

```swift
VStack { }      // Vertical stack   (flex-direction: column)
HStack { }      // Horizontal stack (flex-direction: row)
ZStack { }      // Layered stack    (position: absolute with z-index)
Spacer()        // Flexible space   (flex-grow: 1)
```

### Modifiers (Method Chaining)

```swift
Text("Hello")
    .font(.title)           // Set font
    .foregroundColor(.red)  // Set color
    .padding(20)            // Add padding

// Like method chaining in pandas:
# df.filter(...).groupby(...).agg(...)
```

## 🔄 State Management

### `@State` - Local View State
For simple values owned by the view:

```swift
@State private var isPlaying = false

// Python/React analogy
const [isPlaying, setIsPlaying] = useState(false)
```

### `@StateObject` - Create & Own an Object
For complex objects the view creates:

```swift
@StateObject private var viewModel = MyViewModel()

// Python analogy
class MyView:
    def __init__(self):
        self.view_model = MyViewModel()  # View owns this
```

### `@Published` - Observable Properties
Properties that notify observers when changed:

```swift
class ViewModel: ObservableObject {
    @Published var count = 0  // UI auto-updates when this changes
}

// Python/FastAPI analogy (conceptual)
class ViewModel:
    def __init__(self):
        self._count = 0
        self.observers = []
    
    @property
    def count(self):
        return self._count
    
    @count.setter
    def count(self, value):
        self._count = value
        self._notify_observers()  # Trigger UI update
```

## 🔧 Common Patterns

### 1. **Completion Handlers (Callbacks)**

```swift
// Swift
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    // Async operation...
    completion(.success(data))
}

// Python/FastAPI
from typing import Callable, Union

def fetch_data(completion: Callable[[Union[Data, Exception]], None]):
    # Async operation...
    completion(data)
```

### 2. **Weak Self (Prevent Memory Leaks)**

```swift
// Swift
someAsyncCall { [weak self] result in
    self?.doSomething()  // ? safely unwraps weak reference
}

// Python analogy (Python has garbage collection, so less critical)
import weakref

def callback():
    weak_self = weakref.ref(self)
    if weak_self():
        weak_self().do_something()
```

### 3. **Error Handling**

```swift
// Swift
do {
    try riskyOperation()
} catch {
    print("Error: \(error)")
}

// Python
try:
    risky_operation()
except Exception as error:
    print(f"Error: {error}")
```

## 📊 Data Flow in PulseTempo

```
┌─────────────────────────────────────────────────────────────┐
│                     ContentView (UI)                        │
│  - Displays heart rate, song info, controls                │
│  - @State for local UI state (bpm, timer)                  │
│  - @StateObject for ViewModel                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              RunSessionViewModel (Logic)                    │
│  - Manages current track, playlist                         │
│  - @Published properties notify UI of changes              │
│  - Business logic for track selection                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              HeartRateService (Data)                        │
│  - Monitors heart rate from HealthKit                      │
│  - @Published currentHeartRate                             │
│  - Manages workout session                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              HealthKitManager (API)                         │
│  - Singleton for HealthKit access                          │
│  - Handles authorization                                   │
│  - Provides HKHealthStore                                  │
└─────────────────────────────────────────────────────────────┘
```

## 🆚 Swift vs Python Quick Reference

| Concept | Swift | Python |
|---------|-------|--------|
| Variable (mutable) | `var x = 5` | `x = 5` |
| Constant (immutable) | `let x = 5` | `X = 5` (convention) |
| Optional/None | `var x: Int?` | `x: Optional[int]` |
| String interpolation | `"Value: \(x)"` | `f"Value: {x}"` |
| Array | `[1, 2, 3]` | `[1, 2, 3]` |
| Dictionary | `["key": "value"]` | `{"key": "value"}` |
| Function | `func add(a: Int, b: Int) -> Int` | `def add(a: int, b: int) -> int:` |
| Class | `class MyClass { }` | `class MyClass:` |
| Struct (value type) | `struct Point { }` | `@dataclass class Point:` |
| Enum | `enum Color { case red }` | `class Color(Enum): RED = "red"` |
| For loop | `for item in items { }` | `for item in items:` |
| If statement | `if x > 0 { }` | `if x > 0:` |
| Nil check | `if let x = optional { }` | `if x is not None:` |
| Comments | `// Single` or `/* Multi */` | `# Single` or `""" Multi """` |

## 💡 Tips for Learning Swift from Python

1. **Braces `{}` instead of indentation** - Swift uses curly braces to define blocks
2. **Type annotations are more strict** - Swift requires types in many places
3. **No `self` required** - Access properties directly (unless there's ambiguity)
4. **Semicolons optional** - Like Python, you don't need them at line ends
5. **Declarative UI** - SwiftUI describes WHAT to show, not HOW to update it
6. **Value vs Reference types** - `struct` is copied, `class` is referenced
7. **No `None` keyword** - Use `nil` instead
8. **Method naming** - Swift uses camelCase (not snake_case)

## 🚀 Next Steps

1. **Read the commented files** in this order:
   - `Models.swift` - Simplest, just data structures
   - `PulseTempoApp.swift` - Entry point
   - `RunSessionViewModel.swift` - Business logic
   - `ContentView.swift` - UI layout (most complex)
   - `HealthKitManager.swift` - Service layer
   - `HeartRateService.swift` - Advanced service

2. **Experiment** - Try changing values and see what happens:
   - Change colors in `ContentView.swift`
   - Modify the fake playlist in `RunSessionViewModel.swift`
   - Adjust the heart rate simulation range

3. **Use Xcode's Preview** - See UI changes in real-time without running the app

4. **Read Apple's Docs**:
   - [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
   - [Swift Language Guide](https://docs.swift.org/swift-book/)

## 📚 Resources

- **Official Swift Book**: https://docs.swift.org/swift-book/
- **SwiftUI by Example**: https://www.hackingwithswift.com/quick-start/swiftui
- **100 Days of SwiftUI**: https://www.hackingwithswift.com/100/swiftui

---

**Remember**: Every Swift file now has detailed comments with Python analogies. Don't hesitate to read through them - they're designed specifically for Python developers like you!
