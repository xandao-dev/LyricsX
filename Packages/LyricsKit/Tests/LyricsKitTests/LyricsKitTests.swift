import XCTest
@testable import LyricsService

let testSong = "Uprising"
let testArtist = "Muse"
let duration = 305.0
let searchReq = LyricsSearchRequest(searchTerm: .info(title: testSong, artist: testArtist), duration: duration)

final class LyricsKitTests: XCTestCase {
    
    func _test(provider: LyricsProvider) async {
        let searchResult = expectation(description: "Search result: \(provider)")
        let token = provider.lyricsPublisher(request: searchReq).sink { _ in
            searchResult.fulfill()
        }
        await fulfillment(of: [searchResult], timeout: 10)
        token.cancel()
    }
    
    func testManager() async {
        await _test(provider: LyricsProviders.Group())
    }
}
