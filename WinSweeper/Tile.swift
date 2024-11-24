import Foundation
import AppKit

class Tile: Hashable, Comparable {
    enum State {
        case Empty, Discovered, Flagged, BadFlag, ExplodedMine, Mine, FlaggedMine
    }
    
    func copy(ctx: TileContext?) -> Tile {
        let t = Tile(ctx: ctx, idx: _idx)
        t.prob = prob
        t.isMine = isMine
        t.minesAround = minesAround
        t.state = state
        return t
    }
    
    static func < (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.idx() < rhs.idx()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.idx())
    }
    
    static func ==(lhs: Tile, rhs: Tile) -> Bool {
        return lhs.idx() == rhs.idx()
    }
    
    private let _idx: Int
    weak var ctx: TileContext?
    var state = State.Empty
    var isMine = false
    var minesAround = 0
    private var prob = -1.0
    
    init(ctx: TileContext?, idx: Int) {
        self.ctx = ctx
        self._idx = idx
    }
    
    func reset() {
        state = .Empty
        isMine = false
        resetProb()
        minesAround = 0
    }
    
    func discover(_ nbMinesAround: Int) {
        if minesAround == 0 {
            minesAround = nbMinesAround
            prob = 0
        }
        state = .Discovered
    }
    
    func isFlagged()      -> Bool { state == .Flagged }
    func IsDiscovered()   -> Bool { state == .Discovered }
    func IsUndiscovered() -> Bool { !IsDiscovered() }
    func idx() -> Int { _idx }
    func getProb() -> Double { prob }
    func resetProb() { prob = -1 }
    func SetProbMine() throws {
        try SetProbMine(test: false)
    }
    func SetProbNoMine() throws {
        try SetProbNoMine(test: false)
    }
    func SetProbMine(test: Bool) throws {
        try setProb(1, test: test)
    }
    func SetProbNoMine(test: Bool) throws {
        try setProb(0, test: test)
    }
    func setProb(_ value: Double, test: Bool) throws {
        if !test {
            if value == 1 && !isMine {
                print("Set prob mine which is not a mine \(idx())")
            } else if value == 0 && isMine {
                print("Set prob no mine which is a mine \(idx())")
            }
        }
        if IsKnown() {
            if IsProbMine() && value == 0 {
                throw SetProbError.SetProbNoMineWhichIsAMine(idx: idx())
            } else if IsProbNoMine() && value == 1 {
                throw SetProbError.SetProbMineWhichIsNotAMine(idx: idx())
            }
        }
        guard IsUnknown() else { return }
        prob = value
    }
    func IsProbMine()   -> Bool { prob == 1 }                       // a Mine according to calculated probability
    func IsProbNoMine() -> Bool { prob == 0 }                       // not a Mine according to calculated probability
    func isUnfound()    -> Bool { prob == -1 }                      // Tile was never found by any tiles and no prob assigned
    func IsKnown()      -> Bool { IsProbMine() || IsProbNoMine() }  // we know the tile value
    func IsUnknown()    -> Bool { !IsKnown() }                      // we don't know the tile value
    func isFound()      -> Bool { IsUnknown() && !isUnfound() }     // Tile was found and got a prob assigned
    
    func neighborsDiscovered() -> [Tile] { ctx!.neighbors(of: self).filter { $0.IsDiscovered() } }
    func neighbors() -> [Tile] { ctx!.neighbors(of: self) }
    func extendedNeighbors() -> [Tile] { ctx!.extendedNeighbors(of: self) }
    func unknownNeighbors() -> [Tile] { ctx!.unknownTiles(of: self) }
    func unknownMines() -> Int { ctx!.unknownMines(of: self) }
    func coord() -> (Int, Int) { ctx!.coord(of: self) }
}

enum SetProbError: Error {
    case SetProbMineWhichIsNotAMine(idx: Int)
    case SetProbNoMineWhichIsAMine(idx: Int)
}

extension Tile: CustomStringConvertible {
    var description: String {
        return "Tile(id: \(idx()), isMine: \(isMine))"
    }
}

extension Tile: CustomDebugStringConvertible {
    var debugDescription: String {
        return "T(\(idx()), \(isMine ? "t" : "f"))"
    }
}

protocol TileContext: AnyObject {
    func neighbors(of tile: Tile) -> [Tile]
    func extendedNeighbors(of tile: Tile) -> [Tile]
    func knownMines(of tile: Tile) -> [Tile]
    func knownSafe(of tile: Tile) -> [Tile]
    func unknownTiles(of tile: Tile) -> [Tile]
    func unknownMines(of tile: Tile) -> Int
    func coord(of tile: Tile) -> (Int, Int)
}

extension Set where Element == Pair<Tile> {
    func firstComplement(of tile: Tile) -> Tile? {
        guard let pair = self.first(tile) else { return nil }
        return pair.a == tile ? pair.b : pair.a
    }
    
    func has(tile: Tile) -> Bool {
        self.first(where: { $0.contains(tile) }) != nil
    }
    
    func first(_ tile: Tile) -> Pair<Tile>? {
        self.first(where: { $0.contains(tile) })
    }
}

extension Array where Element == Pair<Tile> {
    func tiles() -> Set<Tile> {
        self.reduce(into: Set<Tile>()) { $0.formUnion($1) }
    }
}

private func subtractPairs<T, C: Collection>(_ s: Set<T>, _ pairs: C) -> Set<T> where C.Element == Pair<T> {
    pairs.reduce(s) { $0.subtracting($1) }
}

extension Set where Element == Tile {
    func subtract(_ pairs: Set<Pair<Tile>>) -> Set<Tile> {
        subtractPairs(self, pairs)
    }

    func subtract(_ pairs: [Pair<Tile>]) -> Set<Tile> {
        subtractPairs(self, pairs)
    }
    
    func setProbeMine(test: Bool) throws {
        try self.forEach { try $0.SetProbMine(test: test) }
    }
    
    func setProbeNoMine(test: Bool) throws {
        try self.forEach { try $0.SetProbNoMine(test: test) }
    }
}

extension Array where Element == Tile {
    func knownMines() -> [Tile] {
        self.filter { $0.IsProbMine() }
    }
    
    mutating func remove(_ tile: Tile) {
        self.removeAll { $0 == tile }
    }
}
