import RichTextPrimitive
import SwiftUI

public struct PageInlineBlockContext {
    public let page: ComputedPage
    public let block: Block
    public let placement: BlockFragmentPlacement
    public let placementCountForBlock: Int
    public let isActivePage: Bool

    public init(
        page: ComputedPage,
        block: Block,
        placement: BlockFragmentPlacement,
        placementCountForBlock: Int,
        isActivePage: Bool
    ) {
        self.page = page
        self.block = block
        self.placement = placement
        self.placementCountForBlock = placementCountForBlock
        self.isActivePage = isActivePage
    }
}

public struct PageInlineBlockRenderer: @unchecked Sendable {
    private let render: @MainActor (PageInlineBlockContext) -> AnyView?

    public init(_ render: @escaping @MainActor (PageInlineBlockContext) -> AnyView?) {
        self.render = render
    }

    @MainActor
    public func callAsFunction(_ context: PageInlineBlockContext) -> AnyView? {
        render(context)
    }
}

private struct PageInlineBlockRendererKey: EnvironmentKey {
    static let defaultValue: PageInlineBlockRenderer? = nil
}

public extension EnvironmentValues {
    var pageInlineBlockRenderer: PageInlineBlockRenderer? {
        get { self[PageInlineBlockRendererKey.self] }
        set { self[PageInlineBlockRendererKey.self] = newValue }
    }
}

public extension View {
    func pageInlineBlockRenderer(_ renderer: PageInlineBlockRenderer?) -> some View {
        environment(\.pageInlineBlockRenderer, renderer)
    }

    func pageInlineBlockRenderer(
        _ renderer: @escaping @MainActor (PageInlineBlockContext) -> AnyView?
    ) -> some View {
        environment(\.pageInlineBlockRenderer, PageInlineBlockRenderer(renderer))
    }
}
