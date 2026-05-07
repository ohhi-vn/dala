# ADR 001: JSON-Based Render Pipeline

## Status
Accepted

## Context
Dala needs to transfer UI tree data from Elixir (BEAM) running on-device to native platforms (iOS/Android) for rendering. The UI is defined as Elixir structs in `Dala.Screen` modules and must be rendered using native UI frameworks (SwiftUI/Jetpack Compose).

Key requirements:
- Cross-platform (iOS and Android)
- Debuggable for developers
- Fast enough for interactive UIs (not 60fps games, but responsive to user input)
- Inspectable by testing tools (`Dala.Test`)
- Able to handle dynamic updates (state changes, navigation)

## Decision
Use a **JSON-based pipeline** to transfer UI trees from Elixir to native code:

```
Elixir structs → Prepare/Resolve → JSON encode → Rust NIF → ObjC/Java → Native UI objects → SwiftUI/Compose
```

### Implementation Details
1. **Elixir side**: `Dala.Renderer.prepare/4` transforms `%Dala.Screen.Node{}` structs, resolves theme tokens, registers tap handlers
2. **Encoding**: `:json.encode/1` converts prepared tree to JSON string
3. **Transport**: Rust NIF (`dala_nif`) receives JSON string via `set_root(json)`
4. **Platform bridge**: Rust calls ObjC (iOS) or JNI (Android) to pass JSON
5. **Parsing**: `DalaNode.fromDictionary` (iOS) or equivalent parses JSON into native UI node tree
6. **Rendering**: `DalaViewModel` (iOS) updates `@Published` property, SwiftUI reacts

### Optimizations
- `render_fast/4`: Batches tap registrations to reduce NIF calls
- Throttling in `DalaViewModel`: Skips updates < 16ms apart
- Skip unchanged renders: `Dala.Screen.do_render/3` checks `socket.__dala__.changed`
- View identity: Uses `navVersion` (not `root`) to avoid unnecessary view teardowns

## Consequences

### Positive
- **Simplicity**: Easy to understand, debug, and modify
- **Inspectability**: `Dala.Test.inspect(node)` returns readable tree; can log JSON before sending
- **Cross-platform**: JSON is language-agnostic, works with any native platform
- **Flexibility**: Add new props by adding to JSON, no NIF recompilation needed
- **Testing**: Can write tests against JSON structure; `Dala.Test` module provides rich inspection

### Negative
- **Performance overhead**: 
  - Encoding: Elixir → JSON (CPU + allocation)
  - Decoding: JSON → Native objects (CPU + allocation)
  - No incremental updates: entire tree re-sent on every render
- **Type safety loss**: JSON is weakly typed; native side must validate and convert
- **NIF call overhead**: Context switches (Elixir → Rust → ObjC → Main thread)

### Mitigations
- UI trees are typically small (< 100 nodes)
- Updates are user-driven, not continuous 60fps
- SwiftUI's diffing minimizes actual view updates
- Throttling prevents overwhelming UI thread
- Skip-render logic avoids unnecessary JSON encoding

## Alternatives Considered

### Binary Protocol (e.g., Protocol Buffers)
- **Pros**: Faster, smaller payload, type-safe
- **Cons**: More complex, requires code generation, less inspectable, harder to debug

### Shared Memory
- **Pros**: Zero-copy between BEAM and native
- **Cons**: Extremely complex, platform-specific, safety issues, hard to debug

### Incremental Patches (like React Fiber)
- **Pros**: Only send changes, not full tree
- **Cons**: Complex diffing logic, need to track previous tree state, more failure modes

## Decision Date
2024 (initial implementation), documented 2025

## Notes
- The `render_fast/4` optimization reduces NIF calls from N+2 to 3 for tap registration
- Future optimization could include binary protocol if performance becomes a bottleneck
- The current approach prioritizes developer experience and debuggability over raw performance
