import Foundation

func calcProb(gameBoard: GameBoard) throws {
    try calcProb(gameBoard: gameBoard, recurs: false)
}

func calcProb(gameBoard: GameBoard, recurs: Bool) throws {
    let startTime = Date()
    var halfPairs: Set<Pair<Tile>> = []
    try partialCalcProb(gameBoard, gameBoard.tiles, recurs, &halfPairs)
    gameBoard.halfPairs = halfPairs
    let timeInterval = Date().timeIntervalSince(startTime)
    if !recurs {
        print("Time taken: \(String(format: "%.3f", timeInterval)) seconds")
    }
}

func partialCalcProb(_ gameBoard: GameBoard, _ tiles: [Tile], _ recurs: Bool, _ halfPairs: inout Set<Pair<Tile>>) throws {
    var loopIdx = 0
    var stable = false
    outerLoop: repeat {
        loopIdx += 1
        if loopIdx > 20 {
            print("NOT GOOD")
            break
        }
        stable = true
        for tile in tiles where tile.IsDiscovered() {
            let nbUnknownMines = tile.unknownMines()
            let tileUnknown = Set(tile.unknownNeighbors())
            let prob = Double(nbUnknownMines) / Double(tileUnknown.count) //  1/2  2/4  4/8  ->  0.5
            
            let conditions = [
                buildCleanHalfPairs(gameBoard, tileUnknown, prob, &halfPairs),
                try processTile(gameBoard, tile, tileUnknown, nbUnknownMines, recurs, &halfPairs),
                try containsHalfPair(gameBoard, tile, tileUnknown, nbUnknownMines, recurs, &halfPairs),
                try tileTouchesAllRemainingMines(gameBoard, tile, recurs),
                try setNeighborsProb(gameBoard, tile, prob, recurs, halfPairs),
            ]
            if conditions.contains(where: { $0 }) {
                stable = false
            }
        }
        if !recurs && stable && gameBoard.knownSafeTiles().isEmpty && recursAttempts(gameBoard) {
            stable = false
        }
        if stable {
            if try oneRemainingTileWithoutMine(gameBoard, test: recurs, &halfPairs) {
                stable = false
            }
        }
        if stable {
            if try distinctGroupsContainsAllMines(gameBoard, test: recurs) {
                stable = false
            }
        }
    } while !stable
}

private func maxPossibleMines(_ gameBoard: GameBoard) -> Int {
    let uniquePairs = maxNonOverlappingPairs(gameBoard.halfPairs)
    let unknownTiles = Set(gameBoard.tiles.filter { $0.IsUnknown() })
    let nonPairTiles = unknownTiles.subtracting(uniquePairs.tiles())
    let additionalMines = nonPairTiles.allSatisfy({ $0.isFound() })
          ? Int(nonPairTiles.map { $0.getProb() }.reduce(0, +).rounded())
          : nonPairTiles.count
    return uniquePairs.count + additionalMines
}

private func recursAttempts(_ gameBoard: GameBoard) -> Bool {
    let tiles = gameBoard.tiles.filter { $0.isFound() }
    for tile in tiles {
        let gbc = gameBoard.copy()
        try! gbc.tiles[tile.idx()].SetProbNoMine(test: true)
        let eligibleTiles = eligibleTilesForRebalance(gbc.tiles[tile.idx()])
        let tiles = Set(eligibleTiles.flatMap { $0.neighbors() }.filter { $0.IsDiscovered() }).sorted()
        try! partialCalcProb(gbc, tiles, true, &gbc.halfPairs)
        if maxPossibleMines(gbc) < gbc.countUnknownMines() ||
            !gbc.isProbValid()
        {
            try! tile.SetProbMine()
            return true
        }
    }
    return false
}

private func buildCleanHalfPairs(_ gameBoard: GameBoard, _ tileUnknown: Set<Tile>, _ prob: Double, _ halfPairs: inout Set<Pair<Tile>>) -> Bool {
    let out = buildHalfPairs(gameBoard, tileUnknown, prob, &halfPairs)
    cleanupHalfPairs(gameBoard, &halfPairs)
    return out
}

private func buildHalfPairs(_ gameBoard: GameBoard, _ tileUnknown: Set<Tile>, _ prob: Double, _ halfPairs: inout Set<Pair<Tile>>) -> Bool {
    guard prob == 0.5 else { return false }
    switch tileUnknown.count {
    case 2:
        let pair = Pair(from: tileUnknown.sorted())!
        if halfPairs.insert(pair).inserted {
            return true
        }
    case 4:
        var out = false
        let pairs = pairsOf(halfPairs, of: tileUnknown)
        for pair in pairs {
            let newPair = Pair(from: tileUnknown.subtracting(pair).sorted())!
            if halfPairs.insert(newPair).inserted {
                out = true
            }
        }
        return out
    case 8: break // TODO
    default: break
    }
    return false
}

private func cleanupHalfPairs(_ gameBoard: GameBoard, _ halfPairs: inout Set<Pair<Tile>>) {
    halfPairs = halfPairs.filter { $0.a.IsUnknown() && $0.b.IsUnknown() }
}

// If a tile has all the remaining unknown mines in its neighbors, then all other tiles have prob 0
private func tileTouchesAllRemainingMines(_ gameBoard: GameBoard, _ tile: Tile, _ test: Bool) throws -> Bool {
    guard tile.unknownMines() == gameBoard.countUnknownMines() else { return false }
    var out = false
    let boardUnknown = gameBoard.unknownTiles()
    let tileNeighbors = tile.neighbors()
    let diff = Set(boardUnknown).subtracting(tileNeighbors)
    try diff.forEach {
        try $0.SetProbNoMine(test: test)
        out = true
    }
    return out
}

private func oneRemainingTileWithoutMine(_ gameBoard: GameBoard, test: Bool, _ halfPairs: inout Set<Pair<Tile>>) throws -> Bool {
    let (unknownTiles, unknownMines) = gameBoard.getAllUnknownTilesMines()
    guard unknownTiles-1 == unknownMines, halfPairs.count == 2 else { return false }
    let p1 = halfPairs.popFirst()!
    let p2 = halfPairs.popFirst()!
    guard let res = Set(p1).intersection(p2).first else { return false }
    try res.SetProbNoMine(test: test)
    return true
}

struct Group: Hashable {
    var nbMines: Int
    var tiles: Set<Tile>
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.tiles)
    }
}

// Get distinct groups of unknown tiles.
// If the total mines contained by the distincts groups equals the remaining unfound mines,
// tag all undiscovered tiles that are not part of the distinct groups as "no-mine"
private func distinctGroupsContainsAllMines(_ gameBoard: GameBoard, test: Bool) throws -> Bool {
    let unknownMines = gameBoard.countUnknownMines()
    guard unknownMines < 10 else { return false }
    var groups: Set<Group> = []
    for tile in gameBoard.tiles where tile.IsDiscovered() {
        let unknown = tile.unknownNeighbors()
        guard unknown.count > 0 else { continue }
        groups.insert(Group(nbMines: tile.unknownMines(), tiles: Set(unknown)))
    }
    let sortedGroups = groups.sorted {
        if $0.tiles.count == $1.tiles.count {
            return $0.nbMines > $1.nbMines
        }
        return $0.tiles.count > $1.tiles.count
    }
    guard sortedGroups.count > 0 else { return false }
    var distincts: Set<Group> = [sortedGroups[0]]
    for group in sortedGroups {
        if !distincts.contains(where: { $0.tiles.intersection(group.tiles).count > 0 }) {
            distincts.insert(group)
        }
    }
    let tot = distincts.reduce(0) { $0 + $1.nbMines }
    guard tot == unknownMines else { return false }
    var out = false
    for t in gameBoard.unknownTiles() {
        if !distincts.contains(where: { $0.tiles.contains(t) }) {
            try t.SetProbNoMine(test: test)
            out = true
        }
    }
    return out
}

// tile `A` has `X` unknown neighbors and `X-1` unfound mines, tile `B` with `1` unfound mine share two neighbors of `A`,
// then `B` other neighbors are set to no-mine, and the other neighbors  of `A` set to "mine".
// Handle `1|2|1` pattern
private func processTile(_ gameBoard: GameBoard, _ tile: Tile, _ aUnknown: Set<Tile>, _ aUnknownMines: Int, _ test: Bool, _ halfPairs: inout Set<Pair<Tile>>) throws -> Bool {
    guard aUnknownMines > 0 else { return false }
    
    let aPairs = pairsOf(halfPairs, of: aUnknown)
    let aUnknown = aUnknown.subtract(aPairs)
    let aUnknownMines = aUnknownMines - aPairs.count
    
    var out = false
    // these half-pairs are only real half-pairs if after processing the tile,
    // the combined pairs account for all the unfound mines of the tile
    var maybeHalfPairs: Set<Pair<Tile>> = []
    for tile in tile.extendedNeighbors() where tile.IsDiscovered() {
        let (bUnknown, bUnknownMines) = prepareNeighbor(tile, aUnknown, halfPairs)
        if try processTilePart1(aUnknown, bUnknown, aUnknownMines, bUnknownMines, &maybeHalfPairs, test) {
            out = true
        }
    }
    maybeHalfPairs = uniquePairs(maybeHalfPairs)
    if aUnknown.count == maybeHalfPairs.count*2 + 1 &&
        aUnknownMines == maybeHalfPairs.count + 1
    {
        let diff = aUnknown.subtract(maybeHalfPairs)
        halfPairs.formUnion(maybeHalfPairs)
        try diff.setProbeMine(test: test)
        out = true
    }
    return out
}

private func prepareNeighbor(_ tile: Tile, _ aUnknown: Set<Tile>, _ halfPairs: Set<Pair<Tile>>) -> (Set<Tile>, Int) {
    let tileUnknown = Set(tile.unknownNeighbors())
    let sharedNeighbors = aUnknown.intersection(tileUnknown)
    let bPairs = uniquePairs(sortPairs(pairsOf(halfPairs, of: tileUnknown), avoid: sharedNeighbors))
    let bUnknown = tileUnknown.subtract(bPairs)
    let bUnknownMines = tile.unknownMines() - bPairs.count
    return (bUnknown, bUnknownMines)
}

private func processTilePart1(
    _ aUnknown: Set<Tile>, _ bUnknown: Set<Tile>,
    _ aUnknownMines: Int, _ bUnknownMines: Int,
    _ maybeHalfPairs: inout Set<Pair<Tile>>,
    _ test: Bool
) throws -> Bool {
    let sharedNeighbors = aUnknown.intersection(bUnknown)
    guard bUnknownMines == 1, sharedNeighbors.count >= 2 else { return false }
    if sharedNeighbors.count == 2 {
        maybeHalfPairs.insert(Pair(from: sharedNeighbors.sorted())!)
    }
    var out = false
    let aExclusive = aUnknown.subtracting(sharedNeighbors)
    let bExclusive = bUnknown.subtracting(sharedNeighbors)
    if aUnknownMines + 1 == aUnknown.count ||
       aUnknownMines - 1 == aExclusive.count {
        // If adding a mine would fill all the unknown of `A`, then `A` exclusive are mines, and `B` exclusive are not
        // If a mine is in the shared tiles, than `A` exclusive are mines, and `B` exclusive are not
        guard !aExclusive.isEmpty || !bExclusive.isEmpty else { return false }
        try aExclusive.setProbeMine(test: test)
        try bExclusive.setProbeNoMine(test: test)
        out = true
    } else if aUnknownMines == 1 && aUnknown.isSuperset(of: bUnknown) {
        guard !aExclusive.isEmpty else { return false }
        try aExclusive.setProbeNoMine(test: test)
        out = true
    }
    return out
}

private func containsHalfPair(_ gameBoard: GameBoard, _ tile: Tile, _ tileUnknown: Set<Tile>, _ nbUnknownMines: Int, _ test: Bool, _ halfPairs: inout Set<Pair<Tile>>) throws -> Bool {
    guard nbUnknownMines > 0 else { return false }
    var out = false
    let neighborsSet = Set(tile.neighbors())
    let pairs = uniquePairs(pairsOf(halfPairs, of: neighborsSet))
    guard !pairs.isEmpty else { return false }
    
    // if neighbors contains a half pair, set neighbors prob (other than the pair)
    let updateProb: (Double) throws -> Void = { probValue in
        let diff = neighborsSet.subtract(pairs)
        for tile in diff where tile.IsUnknown() {
            try tile.setProb(probValue, test: test)
            out = true
        }
    }

    if pairs.count == 1 && nbUnknownMines == tileUnknown.count - 1 {
        try updateProb(1)
    } else if (pairs.count == 1 || pairs.count == 2 || pairs.count == 3) && nbUnknownMines == pairs.count {
        try updateProb(0)
    }
    return out
}

private func setNeighborsProb(_ gameBoard: GameBoard, _ tile: Tile, _ prob: Double, _ test: Bool, _ halfPairs: Set<Pair<Tile>>) throws -> Bool {
    var out = false
    for nTile in tile.unknownNeighbors() {
        if prob == 0 || prob == 1 {
            try nTile.setProb(prob, test: test)
            out = true
            continue
        }
        let currProb = nTile.getProb()
        var newProb = currProb == 0.5 || prob == 0.5 ? 0.5 : max(currProb, prob)
        if newProb == 0.5 && !halfPairs.has(tile: nTile) && currProb != -1 {
            newProb = currProb
        }
        if currProb != newProb {
            try nTile.setProb(newProb, test: test)
            out = true
        }
    }
    return out
}

private func maxNonOverlappingPairs(_ pairs: Set<Pair<Tile>>) -> [Pair<Tile>] {
    let sortedPairs = pairs.sorted { $0.a < $1.a || ($0.a == $1.a && $0.b < $1.b) }
    var result: [Pair<Tile>] = []
    var usedValues: Set<Tile> = []
    for pair in sortedPairs {
        if !usedValues.contains(pair.a) && !usedValues.contains(pair.b) {
            result.append(pair)
            usedValues.insert(pair.a)
            usedValues.insert(pair.b)
        }
    }
    return result
}

private func uniquePairs<T, C: Collection>(_ pairs: C) -> Set<Pair<T>> where C.Element == Pair<T> {
    var uniquePairs = Set<Pair<T>>()
    var seenValues = Set<T>()
    for pair in pairs {
        // Check if either `a` or `b` is already in `seenValues`
        if !seenValues.contains(pair.a) && !seenValues.contains(pair.b) {
            // If both values are unique, add the pair to uniquePairs and mark values as seen
            uniquePairs.insert(pair)
            seenValues.insert(pair.a)
            seenValues.insert(pair.b)
        }
    }
    return uniquePairs
}

// Sorts pairs to prioritize those that do not intersect with elements in the `avoid` set.
private func sortPairs<T, C: Collection>(_ pairs: C, avoid: Set<T>) -> [Pair<T>] where C.Element == Pair<T> {
    pairs.sorted { (pair1: Pair<T>, pair2: Pair<T>) in
        let pair1Intersects = avoid.contains(where: { $0 == pair1.a || $0 == pair1.b })
        let pair2Intersects = avoid.contains(where: { $0 == pair2.a || $0 == pair2.b })
        return pair2Intersects && !pair1Intersects
    }
}

// Filters pairs to include only those that are fully contained within the specified set.
private func pairsOf<T, C: Collection>(_ pairs: C, of set: Set<T>) -> [Pair<T>] where C.Element == Pair<T> {
    pairs.filter { set.isSuperset(of: $0) }
}
