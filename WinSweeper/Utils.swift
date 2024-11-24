import Foundation

func idxFromCoord(_ x: Int, _ y: Int, width: Int) -> Int { y * width + x }

func coordFromIdxUtils(_ idx: Int, width: Int) -> (Int, Int) { (idx % width, idx / width) }

func isValidPosition(x: Int, y: Int, width: Int, height: Int) -> Bool {
    return x >= 0 && x < width &&
           y >= 0 && y < height
}

func indicesInRangeUtils(idx: Int, range: Int, width: Int, height: Int) -> [Int] {
    let r = range
    var res: [Int] = []
    let (x, y) = coordFromIdxUtils(idx, width: width)
    for dx in -r...r {
        for dy in -r...r {
            let (nx, ny) = (x + dx, y + dy)
            if (dx != 0 || dy != 0) && isValidPosition(x: nx, y: ny, width: width, height: height) {
                res.append(idxFromCoord(nx, ny, width: width))
            }
        }
    }
    return res
}

func manhattanDistance(from a: (x: Int, y:  Int), to b: (x: Int, y: Int)) -> Int {
    abs(b.x - a.x) + abs(b.y - a.y)
}

func chebyshevDistance(from a: (x: Int, y: Int), to b: (x: Int, y: Int)) -> Int {
    return max(abs(b.x - a.x), abs(b.y - a.y))
}
