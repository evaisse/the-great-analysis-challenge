# Bug Injection Patterns for Static Analysis Testing

This document defines the bug patterns used to test static analysis performance across different language implementations.

## Goal

Introduce consistent, language-appropriate bugs that:
1. Are detectable by each language's static analysis tools
2. Don't break the build completely (analysis should be able to run)
3. Are fair comparisons across languages
4. Demonstrate the value of static analysis tooling

## Bug Pattern by Language

### TypeScript
**File**: `src/board.ts`
**Bug**: Unused variable
```typescript
// Add after imports
const unusedDebugVariable: string = "This should be detected by TSLint";
```

### Rust
**File**: `src/board.rs`
**Bug**: Unused variable
```rust
// Add at start of impl Board block
#[allow(dead_code)]
fn inject_bug() {
    let unused_debug_variable = "This should be detected by clippy";
}
```

### Python
**File**: `lib/board.py`
**Bug**: Unused import and variable
```python
# Add after imports
import os  # unused import
UNUSED_DEBUG_VARIABLE = "This should be detected by pylint"
```

### Go
**File**: `board.go`
**Bug**: Unused variable
```go
// Add in init or at package level
var unusedDebugVariable = "This should be detected by go vet"
```

### Ruby
**File**: `lib/board.rb` or `chess.rb`
**Bug**: Unused variable
```ruby
# Add at class level
UNUSED_DEBUG_VARIABLE = "This should be detected by rubocop"
```

### Crystal
**File**: `board.cr`
**Bug**: Unused variable
```crystal
# Add at module/class level
UNUSED_DEBUG_VARIABLE = "This should be detected by ameba"
```

### Julia
**File**: `board.jl`
**Bug**: Type instability or unused variable
```julia
# Add after module declaration
const UNUSED_DEBUG_VARIABLE = "This should be detected by analysis"
```

### Kotlin
**File**: `src/main/kotlin/Board.kt`
**Bug**: Unused variable
```kotlin
// Add at class level
private val unusedDebugVariable = "This should be detected by ktlint"
```

### Haskell
**File**: `Board.hs`
**Bug**: Unused binding
```haskell
-- Add at module level
unusedDebugVariable :: String
unusedDebugVariable = "This should be detected by hlint"
```

### Gleam
**File**: `src/board.gleam`
**Bug**: Unused variable
```gleam
// Add at module level
const unused_debug_variable = "This should be detected by gleam check"
```

### Dart
**File**: `lib/board.dart`
**Bug**: Unused variable
```dart
// Add at class level
final String _unusedDebugVariable = "This should be detected by dart analyze";
```

### Elm
**File**: `src/Board.elm`
**Bug**: Unused import or value
```elm
-- Add after module declaration
unusedDebugVariable : String
unusedDebugVariable = "This should be detected by elm-analyse"
```

### ReScript
**File**: `src/Board.res`
**Bug**: Unused binding
```rescript
// Add at module level
let unusedDebugVariable = "This should be detected by rescript"
```

### Mojo
**File**: `board.mojo`
**Bug**: Unused variable
```mojo
# Add at module level
let unused_debug_variable = "This should be detected by mojo check"
```

### Nim
**File**: `board.nim`
**Bug**: Unused variable
```nim
# Add at module level
const unusedDebugVariable = "This should be detected by nim check"
```

### Swift
**File**: `Sources/Board.swift`
**Bug**: Unused variable
```swift
// Add at class level
private let unusedDebugVariable = "This should be detected by swiftlint"
```

### Zig
**File**: `src/board.zig`
**Bug**: Unused variable
```zig
// Add at module level
const unused_debug_variable = "This should be detected by zig fmt"
```

## Implementation Strategy

Each implementation's Makefile will have:

1. **`bugit` target**: 
   - Backs up the target file to `.bugit/`
   - Applies the language-specific bug pattern
   - Marks as "bugged" with a flag file

2. **`fix` target**:
   - Restores the original file from `.bugit/`
   - Removes the flag file

3. **`analyze-with-bug` target**:
   - Ensures bug is injected
   - Runs static analysis tools
   - Captures timing and output
   - Saves results to `.bugit/analysis_results.txt`

4. **`analyze` target** (enhanced):
   - Reports timing with and without bugs
   - Shows comparison
