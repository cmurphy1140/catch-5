import Testing
@testable import CatchFiveUI

@Test func supportSuggestionsStayOpenWhenAPlayerReopensThemDuringADraft() {
    var disclosure = SupportStarterDisclosure()
    disclosure.draftChanged(to: "") // Presenting/focusing the empty field is not typing.
    #expect(disclosure.isExpanded)

    disclosure.draftChanged(to: "H")
    #expect(!disclosure.isExpanded)

    disclosure.isExpanded = true // The player asks to see the choices again.
    disclosure.draftChanged(to: "How does bidding work?")
    #expect(disclosure.isExpanded)
    disclosure.draftChanged(to: "")
    disclosure.draftChanged(to: "What about trump?")
    #expect(disclosure.isExpanded)
}
