import XCTest
@testable import WinSweeper

class CoordFromIdxTests: XCTestCase {
    func assertCoordinatesEqual(_ lhs: (Int, Int), _ rhs: (Int, Int), _ message: String = "") {
        XCTAssertEqual(lhs.0, rhs.0, "X coordinate mismatch: \(message)")
        XCTAssertEqual(lhs.1, rhs.1, "Y coordinate mismatch: \(message)")
    }
    
    func testTopLeftCorner() {
        let result = coordFromIdxUtils(0, width: 5)
        assertCoordinatesEqual(result, (0, 0), "Expected (0, 0) for index 0 in a 5x5 grid")
    }

    func testTopRightCorner() {
        let result = coordFromIdxUtils(4, width: 5)
        assertCoordinatesEqual(result, (4, 0), "Expected (4, 0) for index 4 in a 5x5 grid")
    }

    func testBottomLeftCorner() {
        let result = coordFromIdxUtils(20, width: 5)
        assertCoordinatesEqual(result, (0, 4), "Expected (0, 4) for index 20 in a 5x5 grid")
    }

    func testBottomRightCorner() {
        let result = coordFromIdxUtils(24, width: 5)
        assertCoordinatesEqual(result, (4, 4), "Expected (4, 4) for index 24 in a 5x5 grid")
    }

    func testMiddleOfGrid() {
        let result = coordFromIdxUtils(12, width: 5)
        assertCoordinatesEqual(result, (2, 2), "Expected (2, 2) for index 12 in a 5x5 grid")
    }
    
    func testNonSquareGrid() {
        let result = coordFromIdxUtils(7, width: 3)
        assertCoordinatesEqual(result, (1, 2), "Expected (1, 2) for index 7 in a 3x4 grid")
    }
    
    func testLargeIndex() {
        let result = coordFromIdxUtils(100, width: 10)
        assertCoordinatesEqual(result, (0, 10), "Expected (0, 10) for index 100 in a 10x10 grid")
    }
}

class WinSweeperTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample3() throws {
        let res = indicesInRangeUtils(idx: 0, range: 1, width: 20, height: 20)
        XCTAssertEqual(res, [20, 1, 21])
        let res1 = indicesInRangeUtils(idx: 20, range: 1, width: 20, height: 20)
        XCTAssertEqual(Set(res1), Set([40, 41, 21, 0, 1]))
    }
    
    func testIsNeighbor() throws {
        let gb = GameBoard(width: 10, height: 10)
        XCTAssertTrue(gb.isNeighbor(is: 0, of: 1))
        XCTAssertFalse(gb.isNeighbor(is: 0, of: 2))
    }
    
    func testAround() throws {
        let gb = GameBoard(width: 19, height: 13)
        XCTAssertTrue(gb.around(is: 0, around: 0))
        XCTAssertTrue(gb.around(is: 1, around: 0))
        XCTAssertFalse(gb.around(is: 2, around: 0))
        XCTAssertTrue(gb.around(is: 103, around: 122))
    }
    
    func testProb1() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 14115557504606436957, 87)
        gb.state = .Playing
        gb.showTiles([87])
        XCTAssertEqual(gb.tiles[89].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[70].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[51].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[48].getProb(), 0.0)
    }
    
    func testProb2() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 10549280484909635098, 141)
        gb.state = .Playing
        gb.showTiles([141, 59, 60, 78, 79])
        XCTAssertEqual(gb.tiles[96].getProb(), 0.0)
    }
    
    func testProb3() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 2374153006497716378, 143)
        gb.state = .Playing
        gb.showTiles([143])
        XCTAssertEqual(gb.tiles[183].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[180].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[126].getProb(), 0.0)
    }
    
    func testProb4() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 17317799786981060045, 89)
        gb.state = .Playing
        gb.showTiles([89, 74, 54, 55, 56])
        XCTAssertEqual(gb.tiles[35].getProb(), 0.0)
    }
    
    func testProb5() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 4508560257332069548, 44)
        gb.state = .Playing
        gb.showTiles([44])
        gb.showTiles([8, 9, 28, 41, 47, 80, 81, 83, 84, 85])
        gb.showTiles([10, 21, 40, 48, 59, 98, 99, 100, 102, 103, 104])
        gb.showTiles([1, 2, 20, 39, 58, 78, 97, 116, 118, 120, 123])
        gb.showTiles([76, 96])
        gb.showTiles([95, 114])
        gb.showTiles([3])
        gb.showTiles([60, 117])
        gb.showTiles([133, 153, 157])
        gb.showTiles([152])
        gb.showTiles([173, 176])
        XCTAssertEqual(gb.tiles[139].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[194].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[195].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[196].getProb(), 0.0)
    }
    
    func testProb6() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 1252461538276504510, 162)
        gb.state = .Playing
        gb.showTiles([162])
        (0..<10).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[209].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[228].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[229].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[210].getProb(), 0.0)
    }
    
    func testProb7() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 9117421091547269837, 142)
        gb.state = .Playing
        gb.showTiles([142])
        (0..<2).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[218].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[237].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[240].getProb(), 1.0)
    }
    
    func testProb8() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 7247865276666383888, 123)
        gb.state = .Playing
        gb.showTiles([123])
        (0..<8).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[112].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[113].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[131].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[169].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[188].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[189].getProb(), 0.0)
    }
    
    func testProb9() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 9684687476845086059, 123)
        gb.state = .Playing
        gb.showTiles([123])
        (0..<18).forEach { _ in gb.showSafeTiles() }
        gb.showTiles([60])
        (0..<6).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[211].getProb(), 1.0)
    }

    // TODO: figure out what to do with excluded tiles
    func testProb10() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 13591810916329632083, 149)
        gb.state = .Playing
        gb.showTiles([149])
        (0..<13).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[17].getProb(), -1.0)
        XCTAssertEqual(gb.tiles[18].getProb(), -1.0)
        XCTAssertEqual(gb.tiles[36].getProb(), -1.0)
        XCTAssertEqual(gb.tiles[37].getProb(), -1.0)
    }
    
    // No idea how to fix this one
    func testProb11() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 1889567000856307763, 141)
        gb.state = .Playing
        gb.showTiles([141])
        (0..<10).forEach { _ in gb.showSafeTiles() }
        gb.showTiles([223, 167])
        XCTAssertEqual(gb.tiles[0].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[1].getProb(), 0.0)
    }
    
    func testProb12() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 10107065797273136666, 103)
        gb.state = .Playing
        gb.showTiles([103])
        XCTAssertEqual(gb.tiles[82].getProb(), 1.0)
        XCTAssertEqual(gb.tiles[139].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[142].getProb(), 1.0)
    }
    
    func testProb13() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 4108400424604885082, 122)
        gb.state = .Playing
        gb.showTiles([122])
        (0..<10).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[114].getProb(), 0.0)
    }
    
    func testProb14() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 7339686303628820957, 118)
        gb.state = .Playing
        gb.showTiles([118])
        (0..<7).forEach { _ in gb.showSafeTiles() }
        XCTAssertEqual(gb.tiles[203].getProb(), 0.0)
        XCTAssertEqual(gb.tiles[184].getProb(), 1.0)
    }
    
    func testProb15() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 2227121819766677, 122)
        gb.state = .Playing
        gb.load("**3*2*1112111111110@3*23221*3*22*21*21@3232*1113*22*213*2*2*3*310011122202*2@323*20000123*10111@*211100001**210122**211100001221012***311*11121101222*5*@212223*3*101**213*23*11*4*42102331122**4222*3*1001*102*3**3*1123210011102**2221101*10000000122")
        try! calcProb(gameBoard: gb)
        XCTAssertEqual(gb.tiles[209].getProb(), 1.0)
    }
    
    func testProb16() throws {
        let gb = GameBoard(width: 19, height: 13)
        gb.initBoard(seed: 17827288911921005597, 141)
        gb.state = .Playing
        gb.showTiles([141])
        (0..<9).forEach { _ in gb.showSafeTiles() }
        let res = gb.rebalance(gb.tiles[21])
        XCTAssertTrue(res)
        XCTAssertFalse(gb.tiles[228].isMine)
        XCTAssertFalse(gb.tiles[209].isMine)
        XCTAssertFalse(gb.tiles[229].isMine)
        XCTAssertTrue(gb.tiles[210].isMine)
    }
    
    func testExample1() throws {
        let result = 1 + 2
        XCTAssertEqual(result, 3)
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
