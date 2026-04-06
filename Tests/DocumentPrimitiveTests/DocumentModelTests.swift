import BookmarkPrimitive
import CommentPrimitive
import Foundation
import Testing
import TrackChangesPrimitive
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@Suite("DocumentPrimitive Model Tests")
struct DocumentModelTests {
    @Test func pageSetupPresets() {
        #expect(PageSetup.letter.pageSize == .letter)
        #expect(PageSetup.a4.pageSize == .a4)
    }

    @Test func columnLayoutEqualWidthCalculation() {
        let layout = ColumnLayout(columns: 3, spacing: 18, equalWidth: true)
        let widths = layout.resolvedWidths(totalWidth: 300)
        #expect(widths.count == 3)
        #expect(widths[0] == widths[1])
    }

    @Test func listDefinitionFormatRendering() {
        let definition = ListDefinition(
            id: "legal",
            levels: [
                ListLevelFormat(style: .decimal, format: "%1."),
                ListLevelFormat(style: .lowerAlpha, format: "(%1.%2)"),
            ]
        )

        let rendered = definition.render(level: 1, counters: [2, 3])
        #expect(rendered == "(2.c)")
    }

    @Test func documentCodableRoundTrip() throws {
        let document = Document(
            id: "doc",
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [Block(id: "b1", type: .paragraph, content: .text(.plain("Hello")))]
                ),
            ]
        )

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(Document.self, from: data)
        #expect(decoded == document)
    }

    @MainActor
    @Test func autoBookmarksTrackHeadingsAndPreserveManualBookmarks() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "heading", type: .heading, content: .heading(.plain("Intro"), level: 1)),
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello"))),
                        ]
                    ),
                ]
            )
        )

        #expect(state.bookmarkStore.autoBookmarks.map(\.name) == ["Intro"])

        state.addBookmark(named: "Custom", for: "body")
        state.replaceBlock(
            Block(id: "heading", type: .heading, content: .heading(.plain("Overview"), level: 1)),
            in: "section"
        )

        #expect(state.bookmarkStore.autoBookmarks.map(\.name) == ["Overview"])
        #expect(state.bookmarkStore.manualBookmarks.map(\.name) == ["Custom"])
    }

    @MainActor
    @Test func bookmarkCrossReferencesResolvePageNumbersAndRelativePosition() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "intro", type: .heading, content: .heading(.plain("Intro"), level: 1)),
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello"))),
                        ]
                    ),
                ]
            )
        )

        state.addBookmark(named: "Tail", for: "body")

        let introBookmark = try! #require(state.bookmarkStore.bookmark(named: "Intro"))
        let tailBookmark = try! #require(state.bookmarkStore.bookmark(named: "Tail"))

        let pageReference = state.resolvedReference(
            CrossReference(targetBookmarkID: introBookmark.id, displayStyle: .pageNumber)
        )
        let relativeReference = state.resolvedReference(
            CrossReference(targetBookmarkID: introBookmark.id, displayStyle: .aboveBelow),
            from: tailBookmark.anchor
        )

        #expect(pageReference.displayText == "page 1")
        #expect(relativeReference.displayText == "above")
    }

    @MainActor
    @Test func focusBookmarkMovesEditorToAnchoredLocation() {
        let longText = String(repeating: "Page filler ", count: 2500)
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "lead", type: .paragraph, content: .text(.plain(longText))),
                            Block(id: "tail", type: .paragraph, content: .text(.plain("Tail"))),
                        ]
                    ),
                ]
            )
        )

        state.addBookmark(named: "Tail", for: "tail", offset: 2)
        let bookmark = try! #require(state.bookmarkStore.bookmark(named: "Tail"))
        let tailPage = try! #require(state.layoutEngine.pageNumber(for: "tail"))

        state.focusBookmark(bookmark.id)

        #expect(state.currentSection == "section")
        #expect(state.currentPage == tailPage)
        #expect(state.richTextState.selection == .caret("tail", offset: 2))
        #expect(state.richTextState.focusedBlockID == "tail")
    }

    @MainActor
    @Test func addCommentCreatesQuotedTextAnchorFromSelection() throws {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello world"))),
                        ]
                    ),
                ]
            )
        )

        state.richTextState.selection = .range(
            start: TextPosition(blockID: "body", offset: 6),
            end: TextPosition(blockID: "body", offset: 11)
        )

        let comment = try #require(state.addComment(body: "Needs review", authorID: "todd"))
        let anchor = try comment.anchor.resolve(TextCommentAnchor.self)

        #expect(state.commentStore.comments.count == 1)
        #expect(anchor.blockID == "body")
        #expect(anchor.offset == 6)
        #expect(anchor.length == 5)
        #expect(anchor.selector.exact == "world")
    }

    @MainActor
    @Test func pageAnnotationLookupsFilterBookmarksAndCommentsByVisibleBlocks() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "first", type: .paragraph, content: .text(.plain("Hello world"))),
                            Block(id: "second", type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        ]
                    ),
                ]
            )
        )

        state.addBookmark(named: "Target", for: "second")
        state.richTextState.selection = .range(
            start: TextPosition(blockID: "first", offset: 0),
            end: TextPosition(blockID: "first", offset: 5)
        )
        _ = state.addComment(body: "Check intro", authorID: "todd")

        let firstPage = ComputedPage(
            sectionID: "section",
            pageNumber: 1,
            blockRanges: [BlockRange(startIndex: 0, endIndex: 0)]
        )
        let secondPage = ComputedPage(
            sectionID: "section",
            pageNumber: 2,
            blockRanges: [BlockRange(startIndex: 1, endIndex: 1)]
        )

        #expect(state.comments(on: firstPage).count == 1)
        #expect(state.bookmarks(on: firstPage).isEmpty)
        #expect(Set(state.bookmarks(on: secondPage).map(\.name)) == ["Intro", "Target"])
        #expect(state.comments(on: secondPage).isEmpty)
    }

    @MainActor
    @Test func focusCommentRestoresAnchoredSelection() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello world"))),
                        ]
                    ),
                ]
            )
        )

        state.richTextState.selection = .range(
            start: TextPosition(blockID: "body", offset: 6),
            end: TextPosition(blockID: "body", offset: 11)
        )
        let comment = try! #require(state.addComment(body: "Needs review", authorID: "todd"))

        state.richTextState.selection = .caret("body", offset: 0)
        state.focusComment(comment.id)

        #expect(state.commentStore.activeCommentID == comment.id)
        #expect(
            state.richTextState.selection
                == .range(
                    start: TextPosition(blockID: "body", offset: 6),
                    end: TextPosition(blockID: "body", offset: 11)
                )
        )
    }

    @MainActor
    @Test func resolveCurrentCommentAdvancesToNextOpenComment() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "first", type: .paragraph, content: .text(.plain("First note"))),
                            Block(id: "second", type: .paragraph, content: .text(.plain("Second note"))),
                        ]
                    ),
                ]
            )
        )

        let firstComment = try! #require(
            state.addComment(
                body: "Review first",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "first", offset: 0),
                    end: TextPosition(blockID: "first", offset: 5)
                )
            )
        )
        let secondComment = try! #require(
            state.addComment(
                body: "Review second",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "second", offset: 0),
                    end: TextPosition(blockID: "second", offset: 6)
                )
            )
        )

        state.focusComment(firstComment.id)
        state.resolveCurrentComment()

        #expect(state.commentStore.comment(for: firstComment.id)?.status == .resolved)
        #expect(state.commentStore.activeCommentID == secondComment.id)
        #expect(
            state.richTextState.selection
                == .range(
                    start: TextPosition(blockID: "second", offset: 0),
                    end: TextPosition(blockID: "second", offset: 6)
                )
        )
    }

    @MainActor
    @Test func blockReviewLookupsFilterCommentsAndChangesByAnchoredBlock() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "first", type: .paragraph, content: .text(.plain("First block"))),
                            Block(id: "second", type: .paragraph, content: .text(.plain("Second block"))),
                        ]
                    ),
                ]
            ),
            changeTracker: tracker
        )

        _ = try! #require(
            state.addComment(
                body: "Check first",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "first", offset: 0),
                    end: TextPosition(blockID: "first", offset: 5)
                )
            )
        )

        let source = state.dataSource(for: "section")
        source.updateTextContent(blockID: "second", content: .plain("Second block revised"))

        #expect(state.comments(for: "first").count == 1)
        #expect(state.comments(for: "second").isEmpty)
        #expect(state.changes(for: "first").isEmpty)
        #expect(state.changes(for: "second").count == 1)
    }

    @MainActor
    @Test func blockReviewLookupsTrackCurrentCommentAndChangeTargets() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "first", type: .paragraph, content: .text(.plain("First block"))),
                            Block(id: "second", type: .paragraph, content: .text(.plain("Second block"))),
                        ]
                    ),
                ]
            ),
            changeTracker: tracker
        )

        let comment = try! #require(
            state.addComment(
                body: "Check first",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "first", offset: 0),
                    end: TextPosition(blockID: "first", offset: 5)
                )
            )
        )

        let source = state.dataSource(for: "section")
        source.updateTextContent(blockID: "second", content: .plain("Second block revised"))
        let change = try! #require(tracker.changes.first)

        state.focusComment(comment.id)
        #expect(state.isCurrentComment(on: "first"))
        #expect(!state.isCurrentComment(on: "second"))

        state.focusChange(change.id)
        #expect(state.isCurrentTrackedChange(on: "second"))
        #expect(!state.isCurrentTrackedChange(on: "first"))
    }

    @MainActor
    @Test func updateCurrentCommentMutatesStoredBody() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello world"))),
                        ]
                    ),
                ]
            )
        )

        let comment = try! #require(
            state.addComment(
                body: "Original",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "body", offset: 0),
                    end: TextPosition(blockID: "body", offset: 5)
                )
            )
        )

        state.focusComment(comment.id)
        state.updateCurrentComment(body: "Updated body")

        #expect(state.commentStore.comment(for: comment.id)?.body == "Updated body")
    }

    @MainActor
    @Test func replyToCurrentCommentAddsReplyAndTrimsWhitespace() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello world"))),
                        ]
                    ),
                ]
            )
        )

        let comment = try! #require(
            state.addComment(
                body: "Original",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "body", offset: 0),
                    end: TextPosition(blockID: "body", offset: 5)
                )
            )
        )

        state.focusComment(comment.id)
        state.replyToCurrentComment(body: "  Sounds good  ", authorID: "reviewer")

        #expect(state.commentStore.comment(for: comment.id)?.replies.count == 1)
        #expect(state.commentStore.comment(for: comment.id)?.replies.first?.body == "Sounds good")
        #expect(state.commentStore.comment(for: comment.id)?.replies.first?.author == "reviewer")
    }

    @MainActor
    @Test func pageScopedReviewNavigationTargetsVisibleAnchors() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "first", type: .paragraph, content: .text(.plain("First"))),
                            Block(id: "second", type: .paragraph, content: .text(.plain("Second"))),
                        ]
                    ),
                ]
            ),
            changeTracker: tracker
        )

        state.addBookmark(named: "Target", for: "first", offset: 1)
        let comment = try! #require(
            state.addComment(
                body: "Check first",
                authorID: "todd",
                selection: .range(
                    start: TextPosition(blockID: "first", offset: 0),
                    end: TextPosition(blockID: "first", offset: 5)
                )
            )
        )
        let source = state.dataSource(for: "section")
        source.updateTextContent(blockID: "second", content: .plain("Second revised"))
        let change = try! #require(tracker.changes.first)

        let firstPage = ComputedPage(
            sectionID: "section",
            pageNumber: 1,
            blockRanges: [BlockRange(startIndex: 0, endIndex: 0)]
        )
        let secondPage = ComputedPage(
            sectionID: "section",
            pageNumber: 2,
            blockRanges: [BlockRange(startIndex: 1, endIndex: 1)]
        )

        state.focusFirstBookmark(on: firstPage)
        #expect(state.richTextState.selection == .caret("first", offset: 1))

        state.focusFirstComment(on: firstPage)
        #expect(state.commentStore.activeCommentID == comment.id)

        state.focusFirstChange(on: secondPage)
        #expect(state.currentTrackedChangeID == change.id)
        #expect(state.richTextState.selection == .caret("second", offset: 6))
    }

    @MainActor
    @Test func trackingRecordsInsertionAndRejectRestoresOriginalText() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [Block(id: "body", type: .paragraph, content: .text(.plain("Hello")))]
                    ),
                ]
            ),
            changeTracker: tracker
        )
        let source = state.dataSource(for: "section")

        source.updateTextContent(blockID: "body", content: .plain("Hello world"))

        let change = try! #require(tracker.changes.first)
        #expect(change.type == .insertion(text: " world"))
        #expect(state.changes(on: state.layoutEngine.pages[0]).count == 1)

        state.rejectChange(change.id)

        #expect(state.document.section("section")?.blocks.first?.content.textContent?.plainText == "Hello")
        #expect(tracker.changes.isEmpty)
    }

    @MainActor
    @Test func trackingRecordsDeletionAndRejectRestoresOriginalText() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [Block(id: "body", type: .paragraph, content: .text(.plain("Hello world")))]
                    ),
                ]
            ),
            changeTracker: tracker
        )
        let source = state.dataSource(for: "section")

        source.updateTextContent(blockID: "body", content: .plain("Hello"))

        let change = try! #require(tracker.changes.first)
        #expect(change.type == .deletion(text: " world"))

        state.rejectChange(change.id)

        #expect(state.document.section("section")?.blocks.first?.content.textContent?.plainText == "Hello world")
        #expect(tracker.changes.isEmpty)
    }

    @MainActor
    @Test func trackingRecordsFormatChangesAndRejectRestoresAttributes() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [Block(id: "body", type: .paragraph, content: .text(.plain("Hello")))]
                    ),
                ]
            ),
            changeTracker: tracker
        )
        let source = state.dataSource(for: "section")

        source.updateTextContent(
            blockID: "body",
            content: TextContent(runs: [TextRun(text: "Hello", attributes: TextAttributes(bold: true))])
        )

        let change = try! #require(tracker.changes.first)
        guard case .formatChange = change.type else {
            Issue.record("Expected a format change")
            return
        }

        state.rejectChange(change.id)

        let restoredRun = try! #require(state.document.section("section")?.blocks.first?.content.textContent?.runs.first)
        #expect(restoredRun.attributes == .plain)
        #expect(tracker.changes.isEmpty)
    }

    @MainActor
    @Test func changeNavigationMovesSelectionToTrackedEdit() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let longText = String(repeating: "Page filler ", count: 2500)
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "lead", type: .paragraph, content: .text(.plain(longText))),
                            Block(id: "tail", type: .paragraph, content: .text(.plain("Tail"))),
                        ]
                    ),
                ]
            ),
            changeTracker: tracker
        )
        let source = state.dataSource(for: "section")

        source.updateTextContent(blockID: "tail", content: .plain("Tail edit"))
        let trackedChange = try! #require(tracker.changes.first)
        let tailPage = try! #require(state.layoutEngine.pageNumber(for: "tail"))

        state.goToNextChange()

        #expect(state.currentTrackedChangeID == trackedChange.id)
        #expect(state.currentSection == "section")
        #expect(state.currentPage == tailPage)
        #expect(state.richTextState.selection == .caret("tail", offset: 4))
        #expect(state.richTextState.focusedBlockID == "tail")
    }

    @MainActor
    @Test func rejectAllChangesRestoresDocumentAndClearsNavigationState() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [Block(id: "body", type: .paragraph, content: .text(.plain("Hello")))]
                    ),
                ]
            ),
            changeTracker: tracker
        )
        let source = state.dataSource(for: "section")

        source.updateTextContent(blockID: "body", content: .plain("Hello world"))
        source.updateTextContent(
            blockID: "body",
            content: TextContent(runs: [TextRun(text: "Hello world", attributes: TextAttributes(bold: true))])
        )
        state.goToNextChange()

        state.rejectAllChanges()

        let restoredBlock = try! #require(state.document.section("section")?.blocks.first)
        #expect(restoredBlock.content.textContent?.plainText == "Hello")
        #expect(restoredBlock.content.textContent?.runs.first?.attributes == .plain)
        #expect(tracker.changes.isEmpty)
        #expect(state.currentTrackedChangeID == nil)
    }

    @MainActor
    @Test func acceptCurrentChangeAdvancesToNextTrackedChange() {
        let tracker = ChangeTracker(
            currentAuthor: TrackChangesPrimitive.AuthorID(rawValue: "todd"),
            isTracking: true
        )
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [Block(id: "body", type: .paragraph, content: .text(.plain("Hello")))]
                    ),
                ]
            ),
            changeTracker: tracker
        )
        let source = state.dataSource(for: "section")

        source.updateTextContent(blockID: "body", content: .plain("Hello world"))
        source.updateTextContent(
            blockID: "body",
            content: TextContent(runs: [TextRun(text: "Hello world", attributes: TextAttributes(bold: true))])
        )

        let firstChange = try! #require(tracker.changes.first)
        let secondChange = try! #require(tracker.changes.last)
        state.focusChange(firstChange.id)

        state.acceptCurrentChange()

        #expect(tracker.changes.count == 1)
        #expect(tracker.changes.first?.id == secondChange.id)
        #expect(state.currentTrackedChangeID == secondChange.id)
        #expect(state.currentTrackedChangeSummary == "Formatting change")
    }

    @MainActor
    @Test func sectionAndPageDataSourcesBroadcastSharedMutations() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "b1", type: .paragraph, content: .text(.plain("Hello"))),
                    ]
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let sectionDataSource = state.dataSource(for: "section")
        guard let firstPage = state.layoutEngine.pages.first else {
            Issue.record("Expected at least one laid out page")
            return
        }
        let pageDataSource = state.dataSource(for: firstPage)
        var observedMutations: [RichTextMutation] = []

        let observerID = sectionDataSource.addMutationObserver { mutation in
            observedMutations.append(mutation)
        }

        pageDataSource.updateTextContent(blockID: "b1", content: .plain("Updated"))

        #expect(sectionDataSource.blocks.first?.content.textContent?.plainText == "Updated")
        #expect(observedMutations.contains(.batchUpdate))
        sectionDataSource.removeMutationObserver(observerID)
    }

    @MainActor
    @Test func headerFooterDataSourcesBroadcastSharedMutations() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [Block(id: "b1", type: .paragraph, content: .text(.plain("Hello")))],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(left: [TextRun(text: "Left")], center: [TextRun(text: "Center")])
                    )
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let leftDataSource = state.headerFooterDataSource(for: "section", slot: .headerLeft)
        let centerDataSource = state.headerFooterDataSource(for: "section", slot: .headerCenter)
        var observedMutations: [RichTextMutation] = []

        let observerID = leftDataSource.addMutationObserver { mutation in
            observedMutations.append(mutation)
        }

        guard let centerBlockID = centerDataSource.blocks.first?.id else {
            Issue.record("Expected center header/footer block")
            return
        }
        centerDataSource.updateTextContent(blockID: centerBlockID, content: .plain("Updated Center"))

        #expect(observedMutations.contains(.batchUpdate))
        #expect(state.document.section("section")?.headerFooter?.header?.center.first?.text == "Updated Center")
        leftDataSource.removeMutationObserver(observerID)
    }

    @MainActor
    @Test func evenHeaderFooterDataSourcesWriteSeparateChrome() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [Block(id: "b1", type: .paragraph, content: .text(.plain("Hello")))],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Odd Header")]),
                        footer: HeaderFooter(center: [TextRun(text: "Odd Footer")]),
                        differentOddEven: true
                    )
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let evenHeaderSource = state.headerFooterDataSource(for: "section", slot: .evenHeaderCenter)
        let evenFooterSource = state.headerFooterDataSource(for: "section", slot: .evenFooterCenter)
        let oddHeaderSource = state.headerFooterDataSource(for: "section", slot: .headerCenter)

        let evenHeaderBlockID = try! #require(evenHeaderSource.blocks.first?.id)
        let evenFooterBlockID = try! #require(evenFooterSource.blocks.first?.id)

        evenHeaderSource.updateTextContent(blockID: evenHeaderBlockID, content: .plain("Even Header"))
        evenFooterSource.updateTextContent(blockID: evenFooterBlockID, content: .plain("Even Footer"))

        #expect(state.document.section("section")?.headerFooter?.header?.center.first?.text == "Odd Header")
        #expect(state.document.section("section")?.headerFooter?.evenHeader?.center.first?.text == "Even Header")
        #expect(state.document.section("section")?.headerFooter?.evenFooter?.center.first?.text == "Even Footer")
        #expect(oddHeaderSource.blocks.first?.content.textContent?.plainText == "Odd Header")
    }

    @MainActor
    @Test func firstHeaderFooterDataSourcesWriteSeparateChrome() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [Block(id: "b1", type: .paragraph, content: .text(.plain("Hello")))],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Default Header")]),
                        footer: HeaderFooter(center: [TextRun(text: "Default Footer")]),
                        differentFirstPage: true
                    )
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let firstHeaderSource = state.headerFooterDataSource(for: "section", slot: .firstHeaderCenter)
        let firstFooterSource = state.headerFooterDataSource(for: "section", slot: .firstFooterCenter)

        let firstHeaderBlockID = try! #require(firstHeaderSource.blocks.first?.id)
        let firstFooterBlockID = try! #require(firstFooterSource.blocks.first?.id)

        firstHeaderSource.updateTextContent(blockID: firstHeaderBlockID, content: .plain("First Header"))
        firstFooterSource.updateTextContent(blockID: firstFooterBlockID, content: .plain("First Footer"))

        #expect(state.document.section("section")?.headerFooter?.firstHeader?.center.first?.text == "First Header")
        #expect(state.document.section("section")?.headerFooter?.firstFooter?.center.first?.text == "First Footer")
        #expect(state.document.section("section")?.headerFooter?.header?.center.first?.text == "Default Header")
    }

    @MainActor
    @Test func headerFooterInsertBlocksPreservesParagraphBreaks() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [Block(id: "body", type: .paragraph, content: .text(.plain("Hello")))]
                    ),
                ]
            )
        )
        let headerSource = state.headerFooterDataSource(for: "section", slot: .headerCenter)

        headerSource.insertBlocks(
            [
                Block(id: "first", type: .paragraph, content: .text(.plain("Line one"))),
                Block(id: "second", type: .paragraph, content: .text(.plain("Line two"))),
            ],
            at: 0
        )

        let runs = state.document.section("section")?.headerFooter?.header?.center ?? []
        #expect(TextContent(runs: runs).plainText == "Line one\nLine two")
        #expect(headerSource.blocks.first?.content.textContent?.plainText == "Line one\nLine two")
    }

    @MainActor
    @Test func selectionOffsetTracksCurrentPageAcrossSplitBlocks() {
        let longText = String(repeating: "Split me across pages ", count: 2500)
        let document = Document(
            title: "Paged",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ]
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let lastPageNumber = try! #require(state.layoutEngine.pages.last?.pageNumber)

        state.richTextState.selection = .caret("body", offset: 0)
        state.richTextState.focusedBlockID = "body"
        state.syncCurrentLocationToSelection()
        #expect(state.currentPage == 1)
        #expect(state.currentSection == "section")

        state.richTextState.selection = .caret("body", offset: longText.count)
        state.syncCurrentLocationToSelection()
        #expect(state.currentPage == lastPageNumber)
    }

    @MainActor
    @Test func sectionAndHeaderFooterEditorStatesStayIsolated() {
        let document = Document(
            title: "Draft",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain("Hello body"))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Header")])
                    )
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let sectionEditorState = state.richTextState(forSection: "section")
        let repeatedSectionEditorState = state.richTextState(forSection: "section")
        let headerEditorState = state.headerFooterRichTextState(for: "section", slot: .headerCenter)

        #expect(sectionEditorState === repeatedSectionEditorState)
        #expect(sectionEditorState !== headerEditorState)

        sectionEditorState.selection = .caret("body", offset: 5)
        sectionEditorState.focusedBlockID = "body"
        headerEditorState.selection = .caret(BlockID("section-headerCenter"), offset: 2)
        headerEditorState.focusedBlockID = BlockID("section-headerCenter")

        #expect(sectionEditorState.focusedBlockID == "body")
        #expect(headerEditorState.focusedBlockID == BlockID("section-headerCenter"))
        #expect(sectionEditorState.selection != headerEditorState.selection)
    }

    @MainActor
    @Test func pageEditorStateSelectionDrivesCurrentPageIndependentlyOfSharedState() {
        let longText = String(repeating: "Split me across pages ", count: 2500)
        let document = Document(
            title: "Paged",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ]
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let firstPage = try! #require(state.layoutEngine.pages.first)
        let pageEditorState = state.richTextState(forPage: firstPage)
        let lastPageNumber = try! #require(state.layoutEngine.pages.last?.pageNumber)

        state.richTextState.selection = .caret("body", offset: 0)
        pageEditorState.selection = .caret("body", offset: longText.count)
        pageEditorState.focusedBlockID = "body"

        state.syncCurrentLocation(using: pageEditorState)

        #expect(state.currentPage == lastPageNumber)
        #expect(state.currentSection == "section")
        #expect(state.richTextState.selection == .caret("body", offset: longText.count))
        #expect(state.richTextState.focusedBlockID == "body")
    }

    @MainActor
    @Test func blockEditorStateSelectionTracksCurrentPageAcrossSplitBlocks() {
        let longText = String(repeating: "Split me across pages ", count: 2500)
        let document = Document(
            title: "Paged",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(id: "body", type: .paragraph, content: .text(.plain(longText))),
                    ]
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        let blockEditorState = state.richTextState(forBlock: "body", in: "section")
        let lastPageNumber = try! #require(state.layoutEngine.pages.last?.pageNumber)

        blockEditorState.selection = .caret("body", offset: longText.count)
        blockEditorState.focusedBlockID = "body"
        state.syncCurrentLocation(using: blockEditorState)

        #expect(state.currentPage == lastPageNumber)
        #expect(state.currentSection == "section")
    }

    @MainActor
    @Test func blockDataSourcePreservesOriginalIdentityWhenSingleBlockSplits() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(
                                id: "body",
                                type: .paragraph,
                                content: .text(.plain("Original")),
                                metadata: BlockMetadata(custom: ["locked": .bool(true)])
                            ),
                        ]
                    ),
                ]
            )
        )
        let dataSource = state.dataSource(forBlock: "body", in: "section")
        let firstReplacement = Block(id: "replacement", type: .paragraph, content: .text(.plain("First")))
        let secondReplacement = Block(id: "tail", type: .paragraph, content: .text(.plain("Second")))

        dataSource.insertBlocks([firstReplacement, secondReplacement], at: 0)

        let blocks = state.document.section("section")?.blocks ?? []
        #expect(blocks.count == 2)
        #expect(blocks[0].id == "body")
        #expect(blocks[0].content.textContent?.plainText == "First")
        #expect(blocks[0].metadata.custom["locked"] == .bool(true))
        #expect(blocks[1].id == "tail")
        #expect(blocks[1].content.textContent?.plainText == "Second")
    }

    @MainActor
    @Test func blockDataSourceMovesFocusIntoInsertedTrailingBlock() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("Original"))),
                        ]
                    ),
                ]
            )
        )
        let dataSource = state.dataSource(forBlock: "body", in: "section")

        dataSource.insertBlocks(
            [
                Block(id: "replacement", type: .paragraph, content: .text(.plain("First"))),
                Block(id: "tail", type: .paragraph, content: .text(.plain("Second"))),
            ],
            at: 0
        )

        #expect(state.richTextState.focusedBlockID == "tail")
        #expect(state.richTextState.selection == .caret("tail", offset: 0))
    }

    @MainActor
    @Test func blockDataSourceDeleteRemovesBlockAndFocusesNextSibling() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "first", type: .paragraph, content: .text(.plain("First"))),
                            Block(id: "second", type: .paragraph, content: .text(.plain("Second"))),
                        ]
                    ),
                ]
            )
        )
        let dataSource = state.dataSource(forBlock: "first", in: "section")

        dataSource.deleteBlocks(at: IndexSet(integer: 0))

        let blocks = state.document.section("section")?.blocks ?? []
        #expect(blocks.map(\.id) == ["second"])
        #expect(state.richTextState.focusedBlockID == "second")
        #expect(state.richTextState.selection == .caret("second", offset: 0))
    }

    @MainActor
    @Test func blockDataSourceDeleteLeavesEmptyParagraphWhenRemovingLastBlock() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(
                                id: "only",
                                type: .paragraph,
                                content: .text(.plain("Only")),
                                metadata: BlockMetadata(custom: ["sticky": .bool(true)])
                            ),
                        ]
                    ),
                ]
            )
        )
        let dataSource = state.dataSource(forBlock: "only", in: "section")

        dataSource.deleteBlocks(at: IndexSet(integer: 0))

        let blocks = state.document.section("section")?.blocks ?? []
        #expect(blocks.count == 1)
        #expect(blocks[0].id == "only")
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].content.textContent?.plainText == "")
        #expect(blocks[0].metadata.custom["sticky"] == .bool(true))
        #expect(state.richTextState.focusedBlockID == "only")
        #expect(state.richTextState.selection == .caret("only", offset: 0))
    }

    @MainActor
    @Test func fragmentDataSourceReplacesOnlyVisibleSliceOfBlock() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("abcdefghij"))),
                        ]
                    ),
                ]
            )
        )
        let placement = BlockFragmentPlacement(
            id: UUID(),
            blockID: "body",
            blockIndex: 0,
            frame: .zero,
            isPartial: true,
            partialRange: 20...80,
            itemHeight: 100
        )
        let dataSource = state.dataSource(forFragment: placement, in: "section")

        dataSource.updateTextContent(blockID: "body", content: .plain("XYZ"))

        let blocks = state.document.section("section")?.blocks ?? []
        #expect(blocks.count == 1)
        #expect(blocks[0].content.textContent?.plainText == "abXYZij")
    }

    @MainActor
    @Test func fragmentDataSourceSplitPreservesPrefixAndSuffixAroundReplacement() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("abcdefghij"))),
                        ]
                    ),
                ]
            )
        )
        let placement = BlockFragmentPlacement(
            id: UUID(),
            blockID: "body",
            blockIndex: 0,
            frame: .zero,
            isPartial: true,
            partialRange: 20...80,
            itemHeight: 100
        )
        let dataSource = state.dataSource(forFragment: placement, in: "section")

        dataSource.deleteBlocks(at: IndexSet(integer: 0))
        dataSource.insertBlocks(
            [
                Block(id: "first", type: .paragraph, content: .text(.plain("X"))),
                Block(id: "second", type: .paragraph, content: .text(.plain("Y"))),
            ],
            at: 0
        )

        let blocks = state.document.section("section")?.blocks ?? []
        #expect(blocks.count == 2)
        #expect(blocks[0].id == "body")
        #expect(blocks[0].content.textContent?.plainText == "abX")
        #expect(blocks[1].content.textContent?.plainText == "Yij")
    }

    @MainActor
    @Test func fragmentEditorSelectionMirrorsBackToSharedState() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("abcdefghij"))),
                        ]
                    ),
                ]
            )
        )
        let placement = BlockFragmentPlacement(
            id: UUID(),
            blockID: "body",
            blockIndex: 0,
            frame: .zero,
            isPartial: true,
            partialRange: 20...80,
            itemHeight: 100
        )
        let fragmentState = state.richTextState(forFragment: placement, in: "section")

        fragmentState.selection = .caret("body", offset: 2)
        fragmentState.focusedBlockID = "body"
        state.syncCurrentLocation(usingFragmentEditor: fragmentState, sectionID: "section", placement: placement)

        #expect(state.richTextState.selection == .caret("body", offset: 4))
        #expect(state.richTextState.focusedBlockID == "body")
    }

    @MainActor
    @Test func blockEditorSyncMirrorsFormattingStateBackToSharedState() {
        let state = DocumentEditorState(
            document: Document(
                title: "Draft",
                sections: [
                    DocumentSection(
                        id: "section",
                        blocks: [
                            Block(id: "body", type: .paragraph, content: .text(.plain("Hello"))),
                        ]
                    ),
                ]
            )
        )
        let blockEditorState = state.richTextState(forBlock: "body", in: "section")

        blockEditorState.selection = .caret("body", offset: 3)
        blockEditorState.focusedBlockID = "body"
        blockEditorState.activeAttributes.bold = true
        blockEditorState.zoomLevel = 1.5

        state.syncCurrentLocation(using: blockEditorState)

        #expect(state.richTextState.selection == .caret("body", offset: 3))
        #expect(state.richTextState.focusedBlockID == "body")
        #expect(state.richTextState.activeAttributes.bold == true)
        #expect(state.richTextState.zoomLevel == 1.5)
    }

    @MainActor
    @Test func pageNavigationMovesThroughLaidOutPagesInOrder() {
        let longText = String(repeating: "Body copy ", count: 2000)
        let document = Document(
            title: "Navigation",
            sections: [
                DocumentSection(
                    id: "one",
                    blocks: [Block(id: "a", type: .paragraph, content: .text(.plain(longText)))]
                ),
                DocumentSection(
                    id: "two",
                    blocks: [Block(id: "b", type: .paragraph, content: .text(.plain("Tail")))],
                    startPageNumber: 10
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        guard state.layoutEngine.pages.count > 2 else {
            Issue.record("Expected multiple laid out pages to test navigation")
            return
        }

        let firstPage = try! #require(state.layoutEngine.pages.first)
        let secondPage = try! #require(state.layoutEngine.pages.dropFirst().first)
        let lastPage = try! #require(state.layoutEngine.pages.last)

        state.currentPage = firstPage.pageNumber
        state.currentSection = firstPage.sectionID

        state.goToNextPage()
        #expect(state.currentPage == secondPage.pageNumber)
        #expect(state.currentSection == secondPage.sectionID)

        while state.canGoToNextPage {
            state.goToNextPage()
        }

        #expect(state.currentPage == lastPage.pageNumber)
        #expect(state.currentSection == lastPage.sectionID)

        state.goToPreviousPage()
        #expect(state.currentPage != lastPage.pageNumber || state.currentSection != lastPage.sectionID)
    }

    @MainActor
    @Test func replaceBlockUpdatesDocumentAndLookupReflectsChange() {
        let originalBlock = Block(
            id: "table",
            type: .table,
            content: .table(TableContent(rows: [[.plain("Original")]], caption: .plain("Inventory"))),
            metadata: BlockMetadata(custom: ["pinned": .bool(true)])
        )
        let updatedBlock = Block(
            id: "table",
            type: .table,
            content: .table(TableContent(rows: [[.plain("Updated")]], caption: .plain("Inventory"))),
            metadata: BlockMetadata(custom: ["pinned": .bool(true)])
        )
        let document = Document(
            title: "Tables",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [originalBlock]
                ),
            ]
        )

        let state = DocumentEditorState(document: document)
        state.replaceBlock(updatedBlock, in: "section")

        let resolvedBlock = try! #require(state.block(in: "section", id: "table"))
        #expect(resolvedBlock == updatedBlock)
        #expect(state.document.section("section")?.blocks.first == updatedBlock)
    }
}
