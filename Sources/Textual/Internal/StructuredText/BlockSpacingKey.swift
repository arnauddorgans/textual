import SwiftUI

extension StructuredText {
  struct BlockSpacingKey: PreferenceKey, LayoutValueKey {
    static let defaultValue = BlockSpacing()

    static func reduce(value: inout BlockSpacing, nextValue: () -> BlockSpacing) {
      value = value.union(nextValue())
    }
  }
}

extension ContainerValues {
  /// The block's spacing, read by `BlockVStack` as it lays its blocks out: unlike the preference, a container value
  /// reaches the container in the same pass, so the first layout has the final spacing.
  @Entry var textualBlockSpacing = StructuredText.BlockSpacing()
}

extension EnvironmentValues {
  /// What a block without spacing of its own is laid out with on its first layout, before the union of its nested
  /// blocks' spacing arrives: a style sets it to what that union comes to.
  @Entry var textualDefaultBlockSpacing = StructuredText.BlockSpacing()
}
