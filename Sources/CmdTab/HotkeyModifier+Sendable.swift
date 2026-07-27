// HotkeyModifier is a two-case value enum defined in the proven Phase 1
// hotkey implementation. The conformance is retroactive only because the
// five-feature suite is isolated on its own branch; there is no shared mutable
// state in the value itself.
extension HotkeyModifier: @unchecked Sendable {}
