/// One-slot memo. The key must name every dependency, since nothing else invalidates the slot.
struct Memo<Key: Equatable, Value> {
    private var slot: (key: Key, value: Value)?

    mutating func value(for key: Key, build: () -> Value) -> Value {
        if let slot, slot.key == key { return slot.value }
        let built = build()
        slot = (key, built)
        return built
    }
}
