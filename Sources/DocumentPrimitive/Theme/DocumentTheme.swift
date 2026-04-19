import SwiftUI

/// A comprehensive theme for all DocumentPrimitive views.
///
/// Provides semantic tokens for colors, typography, spacing, metrics, and opacity
/// used across the document editor, page view, toolbar, print preview, review
/// navigator, search popover, and badge views. Every property has a sensible
/// default that follows Apple HIG conventions, so consumers get a polished look
/// with zero configuration.
///
/// The theme is injected via the SwiftUI environment and read by every view
/// through `@Environment(\.documentTheme)`.
// @unchecked because Animation is not formally Sendable in Swift 6
public struct DocumentTheme: @unchecked Sendable {

    // MARK: - Colors

    /// Semantic color tokens used throughout the document editor.
    public struct Colors: Sendable {
        /// The primary accent color used for focused/selected states.
        public var accent: Color
        /// The secondary color used for muted text and backgrounds.
        public var secondary: Color
        /// The primary content background (page surface, editor cards).
        public var background: Color
        /// The canvas/chrome background behind pages.
        public var canvasBackground: Color
        /// Tint for comment-related review elements.
        public var commentTint: Color
        /// Tint for insertion tracked changes.
        public var insertionTint: Color
        /// Tint for deletion tracked changes.
        public var deletionTint: Color
        /// Tint for format tracked changes.
        public var formatChangeTint: Color
        /// Color for link text.
        public var linkColor: Color
        /// Color for the blockquote accent bar.
        public var blockquoteBar: Color
        /// Color for the code block background.
        public var codeBlockBackground: Color
        /// Color for table cell borders.
        public var tableBorder: Color
        /// Color for the image placeholder gradient start.
        public var placeholderGradientStart: Color
        /// Color for the image placeholder gradient end.
        public var placeholderGradientEnd: Color
        /// Color for embed block backgrounds.
        public var embedBackground: Color

        public init(
            accent: Color = .accentColor,
            secondary: Color = .secondary,
            background: Color = .white,
            canvasBackground: Color = Color.secondary.opacity(0.08),
            commentTint: Color = .orange,
            insertionTint: Color = .green,
            deletionTint: Color = .red,
            formatChangeTint: Color = .teal,
            linkColor: Color = .blue,
            blockquoteBar: Color = Color.secondary.opacity(0.35),
            codeBlockBackground: Color = Color.secondary.opacity(0.08),
            tableBorder: Color = Color.secondary.opacity(0.18),
            placeholderGradientStart: Color = Color.secondary.opacity(0.14),
            placeholderGradientEnd: Color = Color.secondary.opacity(0.05),
            embedBackground: Color = Color.secondary.opacity(0.06)
        ) {
            self.accent = accent
            self.secondary = secondary
            self.background = background
            self.canvasBackground = canvasBackground
            self.commentTint = commentTint
            self.insertionTint = insertionTint
            self.deletionTint = deletionTint
            self.formatChangeTint = formatChangeTint
            self.linkColor = linkColor
            self.blockquoteBar = blockquoteBar
            self.codeBlockBackground = codeBlockBackground
            self.tableBorder = tableBorder
            self.placeholderGradientStart = placeholderGradientStart
            self.placeholderGradientEnd = placeholderGradientEnd
            self.embedBackground = embedBackground
        }
    }

    // MARK: - Typography

    /// Font tokens used across document views.
    public struct Typography: Sendable {
        /// Font for page number labels and metadata captions.
        public var caption: Font
        /// Font for small badges and ruler tick labels.
        public var caption2: Font
        /// Font for footnotes, header/footer text, and change summaries.
        public var footnote: Font
        /// Font for the toolbar page label and change count.
        public var toolbarLabel: Font
        /// Font for section titles in the review navigator.
        public var headline: Font
        /// Font for row titles in navigator and search results.
        public var rowTitle: Font
        /// Font for image placeholder icon.
        public var placeholderIcon: Font
        /// Font for attachment preview titles.
        public var attachmentTitle: Font

        public init(
            caption: Font = .caption,
            caption2: Font = .caption2,
            footnote: Font = .footnote,
            toolbarLabel: Font = .caption,
            headline: Font = .headline,
            rowTitle: Font = .subheadline.weight(.medium),
            placeholderIcon: Font = .system(size: 28),
            attachmentTitle: Font = .headline
        ) {
            self.caption = caption
            self.caption2 = caption2
            self.footnote = footnote
            self.toolbarLabel = toolbarLabel
            self.headline = headline
            self.rowTitle = rowTitle
            self.placeholderIcon = placeholderIcon
            self.attachmentTitle = attachmentTitle
        }
    }

    // MARK: - Spacing

    /// Spacing tokens controlling padding, gaps, and insets.
    public struct Spacing: Sendable {
        /// Outer padding for page/continuous mode containers (print preview, continuous editor).
        public var containerPadding: CGFloat
        /// Vertical gap between pages in print preview / grid preview.
        public var pageGap: CGFloat
        /// Vertical gap between section cards in continuous mode.
        public var sectionGap: CGFloat
        /// Gap between toolbar items.
        public var toolbarItemSpacing: CGFloat
        /// Horizontal padding on the toolbar.
        public var toolbarHorizontalPadding: CGFloat
        /// Vertical padding on the toolbar.
        public var toolbarVerticalPadding: CGFloat
        /// Spacing between change-navigation / page-navigation controls.
        public var toolbarGroupSpacing: CGFloat
        /// Horizontal padding inside the page content area.
        public var pageContentHorizontalPadding: CGFloat
        /// Vertical padding inside the page content area.
        public var pageContentVerticalPadding: CGFloat
        /// Gap between header/footer columns.
        public var headerFooterColumnSpacing: CGFloat
        /// Vertical gap between block placements in a column.
        public var columnPlacementSpacing: CGFloat
        /// Footnote area vertical spacing.
        public var footnoteSpacing: CGFloat
        /// Gap between footnote marker and content.
        public var footnoteMarkerContentGap: CGFloat
        /// Padding above/below the footnote divider.
        public var footnoteDividerPadding: CGFloat
        /// Code block inner padding.
        public var codeBlockPadding: CGFloat
        /// Gap between list bullet and content.
        public var listBulletContentGap: CGFloat
        /// Per-indent-level leading inset for nested lists.
        public var listIndentStep: CGFloat
        /// Image element spacing (image to caption).
        public var imageSpacing: CGFloat
        /// Embed block inner padding.
        public var embedPadding: CGFloat
        /// Padding inside annotation overlay.
        public var annotationPadding: CGFloat
        /// Gap between annotation badges.
        public var annotationBadgeGap: CGFloat
        /// Review deck item spacing.
        public var reviewDeckSpacing: CGFloat
        /// Review deck top padding.
        public var reviewDeckTopPadding: CGFloat
        /// Review deck bottom padding.
        public var reviewDeckBottomPadding: CGFloat
        /// Review card inner padding.
        public var reviewCardPadding: CGFloat
        /// Review badge horizontal padding from trailing edge.
        public var reviewBadgeTrailingPadding: CGFloat
        /// Review badge vertical padding from top edge.
        public var reviewBadgeTopPadding: CGFloat
        /// Gap between review count badges.
        public var reviewBadgeGap: CGFloat
        /// Continuation chip horizontal padding.
        public var continuationChipHorizontalPadding: CGFloat
        /// Continuation chip vertical padding.
        public var continuationChipVerticalPadding: CGFloat
        /// Review highlight negative horizontal inset.
        public var reviewHighlightHorizontalInset: CGFloat
        /// Review highlight negative vertical inset.
        public var reviewHighlightVerticalInset: CGFloat
        /// Popover content padding.
        public var popoverPadding: CGFloat
        /// Popover content vertical spacing.
        public var popoverContentSpacing: CGFloat
        /// Navigator/search row padding.
        public var navigatorRowPadding: CGFloat
        /// Navigator/search row vertical list spacing.
        public var navigatorRowSpacing: CGFloat
        /// Navigator row icon/content gap.
        public var navigatorRowIconGap: CGFloat
        /// Scope chip horizontal padding.
        public var scopeChipHorizontalPadding: CGFloat
        /// Scope chip vertical padding.
        public var scopeChipVerticalPadding: CGFloat
        /// Gap between scope chips.
        public var scopeChipGap: CGFloat
        /// Section reorder handle horizontal padding.
        public var reorderHandleHorizontalPadding: CGFloat
        /// Section reorder handle vertical padding.
        public var reorderHandleVerticalPadding: CGFloat
        /// Gap between section reorder handle and editor.
        public var reorderHandleGap: CGFloat
        /// Grid table editor inner padding.
        public var gridTableEditorPadding: CGFloat
        /// Attachment preview spacing between preview and title.
        public var attachmentPreviewSpacing: CGFloat
        /// Attachment title-to-caption spacing.
        public var attachmentTitleCaptionSpacing: CGFloat

        public init(
            containerPadding: CGFloat = 24,
            pageGap: CGFloat = 28,
            sectionGap: CGFloat = 20,
            toolbarItemSpacing: CGFloat = 12,
            toolbarHorizontalPadding: CGFloat = 16,
            toolbarVerticalPadding: CGFloat = 8,
            toolbarGroupSpacing: CGFloat = 8,
            pageContentHorizontalPadding: CGFloat = 18,
            pageContentVerticalPadding: CGFloat = 8,
            headerFooterColumnSpacing: CGFloat = 12,
            columnPlacementSpacing: CGFloat = 10,
            footnoteSpacing: CGFloat = 4,
            footnoteMarkerContentGap: CGFloat = 6,
            footnoteDividerPadding: CGFloat = 6,
            codeBlockPadding: CGFloat = 12,
            listBulletContentGap: CGFloat = 8,
            listIndentStep: CGFloat = 18,
            imageSpacing: CGFloat = 8,
            embedPadding: CGFloat = 12,
            annotationPadding: CGFloat = 12,
            annotationBadgeGap: CGFloat = 6,
            reviewDeckSpacing: CGFloat = 10,
            reviewDeckTopPadding: CGFloat = 8,
            reviewDeckBottomPadding: CGFloat = 6,
            reviewCardPadding: CGFloat = 12,
            reviewBadgeTrailingPadding: CGFloat = 4,
            reviewBadgeTopPadding: CGFloat = 6,
            reviewBadgeGap: CGFloat = 6,
            continuationChipHorizontalPadding: CGFloat = 6,
            continuationChipVerticalPadding: CGFloat = 3,
            reviewHighlightHorizontalInset: CGFloat = 6,
            reviewHighlightVerticalInset: CGFloat = 4,
            popoverPadding: CGFloat = 16,
            popoverContentSpacing: CGFloat = 14,
            navigatorRowPadding: CGFloat = 12,
            navigatorRowSpacing: CGFloat = 8,
            navigatorRowIconGap: CGFloat = 12,
            scopeChipHorizontalPadding: CGFloat = 10,
            scopeChipVerticalPadding: CGFloat = 6,
            scopeChipGap: CGFloat = 8,
            reorderHandleHorizontalPadding: CGFloat = 10,
            reorderHandleVerticalPadding: CGFloat = 12,
            reorderHandleGap: CGFloat = 12,
            gridTableEditorPadding: CGFloat = 14,
            attachmentPreviewSpacing: CGFloat = 12,
            attachmentTitleCaptionSpacing: CGFloat = 4
        ) {
            self.containerPadding = containerPadding
            self.pageGap = pageGap
            self.sectionGap = sectionGap
            self.toolbarItemSpacing = toolbarItemSpacing
            self.toolbarHorizontalPadding = toolbarHorizontalPadding
            self.toolbarVerticalPadding = toolbarVerticalPadding
            self.toolbarGroupSpacing = toolbarGroupSpacing
            self.pageContentHorizontalPadding = pageContentHorizontalPadding
            self.pageContentVerticalPadding = pageContentVerticalPadding
            self.headerFooterColumnSpacing = headerFooterColumnSpacing
            self.columnPlacementSpacing = columnPlacementSpacing
            self.footnoteSpacing = footnoteSpacing
            self.footnoteMarkerContentGap = footnoteMarkerContentGap
            self.footnoteDividerPadding = footnoteDividerPadding
            self.codeBlockPadding = codeBlockPadding
            self.listBulletContentGap = listBulletContentGap
            self.listIndentStep = listIndentStep
            self.imageSpacing = imageSpacing
            self.embedPadding = embedPadding
            self.annotationPadding = annotationPadding
            self.annotationBadgeGap = annotationBadgeGap
            self.reviewDeckSpacing = reviewDeckSpacing
            self.reviewDeckTopPadding = reviewDeckTopPadding
            self.reviewDeckBottomPadding = reviewDeckBottomPadding
            self.reviewCardPadding = reviewCardPadding
            self.reviewBadgeTrailingPadding = reviewBadgeTrailingPadding
            self.reviewBadgeTopPadding = reviewBadgeTopPadding
            self.reviewBadgeGap = reviewBadgeGap
            self.continuationChipHorizontalPadding = continuationChipHorizontalPadding
            self.continuationChipVerticalPadding = continuationChipVerticalPadding
            self.reviewHighlightHorizontalInset = reviewHighlightHorizontalInset
            self.reviewHighlightVerticalInset = reviewHighlightVerticalInset
            self.popoverPadding = popoverPadding
            self.popoverContentSpacing = popoverContentSpacing
            self.navigatorRowPadding = navigatorRowPadding
            self.navigatorRowSpacing = navigatorRowSpacing
            self.navigatorRowIconGap = navigatorRowIconGap
            self.scopeChipHorizontalPadding = scopeChipHorizontalPadding
            self.scopeChipVerticalPadding = scopeChipVerticalPadding
            self.scopeChipGap = scopeChipGap
            self.reorderHandleHorizontalPadding = reorderHandleHorizontalPadding
            self.reorderHandleVerticalPadding = reorderHandleVerticalPadding
            self.reorderHandleGap = reorderHandleGap
            self.gridTableEditorPadding = gridTableEditorPadding
            self.attachmentPreviewSpacing = attachmentPreviewSpacing
            self.attachmentTitleCaptionSpacing = attachmentTitleCaptionSpacing
        }
    }

    // MARK: - Metrics

    /// Size, corner radius, and dimensional tokens.
    public struct Metrics: Sendable {
        /// Corner radius for page cards.
        public var pageCornerRadius: CGFloat
        /// Corner radius for section editor cards in continuous mode.
        public var sectionCardCornerRadius: CGFloat
        /// Corner radius for review highlights, review cards, navigator rows, and comment controls.
        public var cardCornerRadius: CGFloat
        /// Corner radius for code blocks and embed blocks.
        public var codeBlockCornerRadius: CGFloat
        /// Corner radius for table clips.
        public var tableCornerRadius: CGFloat
        /// Corner radius for image previews.
        public var imageCornerRadius: CGFloat
        /// Corner radius for the section reorder handle.
        public var reorderHandleCornerRadius: CGFloat
        /// Corner radius for grid table editor backgrounds.
        public var gridTableEditorCornerRadius: CGFloat
        /// Width of the blockquote accent bar.
        public var blockquoteBarWidth: CGFloat
        /// Corner radius for the blockquote accent bar.
        public var blockquoteBarCornerRadius: CGFloat
        /// Minimum height for the section editor in continuous mode.
        public var sectionMinHeight: CGFloat
        /// Ruler bar height.
        public var rulerHeight: CGFloat
        /// Navigator icon frame width.
        public var navigatorIconWidth: CGFloat
        /// Minimum width for the change count label.
        public var changeCountMinWidth: CGFloat
        /// Minimum width for the change summary label.
        public var changeSummaryMinWidth: CGFloat
        /// Maximum width for the change summary label.
        public var changeSummaryMaxWidth: CGFloat
        /// Maximum width for annotation badges.
        public var annotationBadgeMaxWidth: CGFloat
        /// Popover width (review navigator, search).
        public var popoverWidth: CGFloat
        /// Popover height (review navigator, search).
        public var popoverHeight: CGFloat
        /// Minimum height for file attachment preview.
        public var attachmentPreviewMinHeight: CGFloat
        /// Footnote marker minimum width.
        public var footnoteMarkerMinWidth: CGFloat
        /// List bullet frame width.
        public var listBulletWidth: CGFloat
        /// Scope chip count badge minimum width (unused for now but keeps parity).
        public var scopeChipCountMinWidth: CGFloat

        public init(
            pageCornerRadius: CGFloat = 18,
            sectionCardCornerRadius: CGFloat = 16,
            cardCornerRadius: CGFloat = 12,
            codeBlockCornerRadius: CGFloat = 10,
            tableCornerRadius: CGFloat = 8,
            imageCornerRadius: CGFloat = 14,
            reorderHandleCornerRadius: CGFloat = 12,
            gridTableEditorCornerRadius: CGFloat = 16,
            blockquoteBarWidth: CGFloat = 4,
            blockquoteBarCornerRadius: CGFloat = 2,
            sectionMinHeight: CGFloat = 220,
            rulerHeight: CGFloat = 34,
            navigatorIconWidth: CGFloat = 18,
            changeCountMinWidth: CGFloat = 72,
            changeSummaryMinWidth: CGFloat = 110,
            changeSummaryMaxWidth: CGFloat = 180,
            annotationBadgeMaxWidth: CGFloat = 180,
            popoverWidth: CGFloat = 430,
            popoverHeight: CGFloat = 520,
            attachmentPreviewMinHeight: CGFloat = 240,
            footnoteMarkerMinWidth: CGFloat = 24,
            listBulletWidth: CGFloat = 20,
            scopeChipCountMinWidth: CGFloat = 0
        ) {
            self.pageCornerRadius = pageCornerRadius
            self.sectionCardCornerRadius = sectionCardCornerRadius
            self.cardCornerRadius = cardCornerRadius
            self.codeBlockCornerRadius = codeBlockCornerRadius
            self.tableCornerRadius = tableCornerRadius
            self.imageCornerRadius = imageCornerRadius
            self.reorderHandleCornerRadius = reorderHandleCornerRadius
            self.gridTableEditorCornerRadius = gridTableEditorCornerRadius
            self.blockquoteBarWidth = blockquoteBarWidth
            self.blockquoteBarCornerRadius = blockquoteBarCornerRadius
            self.sectionMinHeight = sectionMinHeight
            self.rulerHeight = rulerHeight
            self.navigatorIconWidth = navigatorIconWidth
            self.changeCountMinWidth = changeCountMinWidth
            self.changeSummaryMinWidth = changeSummaryMinWidth
            self.changeSummaryMaxWidth = changeSummaryMaxWidth
            self.annotationBadgeMaxWidth = annotationBadgeMaxWidth
            self.popoverWidth = popoverWidth
            self.popoverHeight = popoverHeight
            self.attachmentPreviewMinHeight = attachmentPreviewMinHeight
            self.footnoteMarkerMinWidth = footnoteMarkerMinWidth
            self.listBulletWidth = listBulletWidth
            self.scopeChipCountMinWidth = scopeChipCountMinWidth
        }
    }

    // MARK: - Opacity

    /// Opacity tokens for backgrounds, highlights, and borders.
    public struct Opacity: Sendable {
        /// Fill opacity for the continuous mode background.
        public var canvasFill: Double
        /// Fill opacity for muted backgrounds (reorder handle, ruler, code blocks).
        public var mutedFill: Double
        /// Fill opacity for subtle backgrounds (replies, embed, navigator rows).
        public var subtleFill: Double
        /// Fill opacity for selected/focused navigator rows and scope chips.
        public var selectedFill: Double
        /// Fill opacity for review card backgrounds.
        public var reviewCardFill: Double
        /// Border opacity for review cards and scope chips.
        public var reviewCardBorder: Double
        /// Fill opacity for review highlight backgrounds (non-focused).
        public var reviewHighlightFill: Double
        /// Fill opacity for focused review highlight backgrounds.
        public var reviewHighlightFocusedFill: Double
        /// Border opacity for review highlights (non-focused).
        public var reviewHighlightBorder: Double
        /// Border opacity for focused review highlights.
        public var reviewHighlightFocusedBorder: Double
        /// Line width for review highlights (non-focused).
        public var reviewHighlightLineWidth: CGFloat
        /// Line width for focused review highlights.
        public var reviewHighlightFocusedLineWidth: CGFloat
        /// Border opacity for scope chips (non-selected).
        public var scopeChipBorder: Double
        /// Border opacity for scope chips (selected).
        public var scopeChipSelectedBorder: Double
        /// Opacity for the page card shadow.
        public var pageShadowOpacity: Double
        /// Opacity for the section card shadow.
        public var sectionShadowOpacity: Double
        /// Opacity for the continuation chip background.
        public var continuationChipBackground: Double
        /// Opacity for ruler tick minor marks.
        public var rulerTickMinor: Double
        /// Opacity for ruler marker border.
        public var rulerMarkerBorder: Double

        public init(
            canvasFill: Double = 0.05,
            mutedFill: Double = 0.08,
            subtleFill: Double = 0.06,
            selectedFill: Double = 0.12,
            reviewCardFill: Double = 0.08,
            reviewCardBorder: Double = 0.18,
            reviewHighlightFill: Double = 0.07,
            reviewHighlightFocusedFill: Double = 0.12,
            reviewHighlightBorder: Double = 0.24,
            reviewHighlightFocusedBorder: Double = 0.55,
            reviewHighlightLineWidth: CGFloat = 1,
            reviewHighlightFocusedLineWidth: CGFloat = 1.6,
            scopeChipBorder: Double = 0.18,
            scopeChipSelectedBorder: Double = 0.35,
            pageShadowOpacity: Double = 0.08,
            sectionShadowOpacity: Double = 0.05,
            continuationChipBackground: Double = 0.92,
            rulerTickMinor: Double = 0.45,
            rulerMarkerBorder: Double = 0.25
        ) {
            self.canvasFill = canvasFill
            self.mutedFill = mutedFill
            self.subtleFill = subtleFill
            self.selectedFill = selectedFill
            self.reviewCardFill = reviewCardFill
            self.reviewCardBorder = reviewCardBorder
            self.reviewHighlightFill = reviewHighlightFill
            self.reviewHighlightFocusedFill = reviewHighlightFocusedFill
            self.reviewHighlightBorder = reviewHighlightBorder
            self.reviewHighlightFocusedBorder = reviewHighlightFocusedBorder
            self.reviewHighlightLineWidth = reviewHighlightLineWidth
            self.reviewHighlightFocusedLineWidth = reviewHighlightFocusedLineWidth
            self.scopeChipBorder = scopeChipBorder
            self.scopeChipSelectedBorder = scopeChipSelectedBorder
            self.pageShadowOpacity = pageShadowOpacity
            self.sectionShadowOpacity = sectionShadowOpacity
            self.continuationChipBackground = continuationChipBackground
            self.rulerTickMinor = rulerTickMinor
            self.rulerMarkerBorder = rulerMarkerBorder
        }
    }

    // MARK: - Shadow

    /// Shadow tokens for page and section cards.
    public struct Shadow: Sendable {
        /// Shadow radius for page cards.
        public var pageRadius: CGFloat
        /// Shadow Y offset for page cards.
        public var pageY: CGFloat
        /// Shadow radius for section cards in continuous mode.
        public var sectionRadius: CGFloat
        /// Shadow Y offset for section cards.
        public var sectionY: CGFloat

        public init(
            pageRadius: CGFloat = 20,
            pageY: CGFloat = 8,
            sectionRadius: CGFloat = 12,
            sectionY: CGFloat = 6
        ) {
            self.pageRadius = pageRadius
            self.pageY = pageY
            self.sectionRadius = sectionRadius
            self.sectionY = sectionY
        }
    }

    // MARK: - Properties

    /// Color tokens.
    public var colors: Colors
    /// Typography tokens.
    public var typography: Typography
    /// Spacing tokens.
    public var spacing: Spacing
    /// Metric (size/radius/dimension) tokens.
    public var metrics: Metrics
    /// Opacity tokens.
    public var opacity: Opacity
    /// Shadow tokens.
    public var shadow: Shadow

    /// Animation used when scrolling to a page.
    public var scrollAnimation: Animation
    /// Animation used for hover badge appearance.
    public var hoverBadgeAnimationDuration: Double

    /// The default theme matching Apple HIG conventions.
    public static let `default` = DocumentTheme()

    public init(
        colors: Colors = .init(),
        typography: Typography = .init(),
        spacing: Spacing = .init(),
        metrics: Metrics = .init(),
        opacity: Opacity = .init(),
        shadow: Shadow = .init(),
        scrollAnimation: Animation = .easeInOut(duration: 0.2),
        hoverBadgeAnimationDuration: Double = 0.16
    ) {
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.metrics = metrics
        self.opacity = opacity
        self.shadow = shadow
        self.scrollAnimation = scrollAnimation
        self.hoverBadgeAnimationDuration = hoverBadgeAnimationDuration
    }

    // MARK: - Convenience Computed Properties

    /// Tint color for a tracked change type (insertion, deletion, format).
    public func changeTint(for changeType: TrackedChangeType) -> Color {
        switch changeType {
        case .insertion:
            colors.insertionTint
        case .deletion:
            colors.deletionTint
        case .formatChange:
            colors.formatChangeTint
        }
    }

    /// The muted fill used for reorder handles, ruler backgrounds, etc.
    public var mutedFill: Color {
        colors.secondary.opacity(opacity.mutedFill)
    }

    /// The subtle fill used for reply bubbles, navigator rows, etc.
    public var subtleFill: Color {
        colors.secondary.opacity(opacity.subtleFill)
    }

    /// The selected-state accent fill.
    public var selectedFill: Color {
        colors.accent.opacity(opacity.selectedFill)
    }
}

// MARK: - Tracked Change Type (local bridge)

/// Lightweight enum mirroring the tracked change kind so the theme can resolve
/// tints without importing TrackChangesPrimitive in every file.
public enum TrackedChangeType: Sendable {
    case insertion
    case deletion
    case formatChange
}

// MARK: - Environment Integration

private struct DocumentThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: DocumentTheme = .default
}

public extension EnvironmentValues {
    /// The current document theme injected into the environment.
    var documentTheme: DocumentTheme {
        get { self[DocumentThemeEnvironmentKey.self] }
        set { self[DocumentThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Applies a custom document theme to this view and its descendants.
    func documentTheme(_ theme: DocumentTheme) -> some View {
        environment(\.documentTheme, theme)
    }
}
