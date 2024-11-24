import Foundation

struct Pair<T: Hashable>: Hashable, Sequence {
    let a: T
    let b: T
    
    init(a: T, b: T) {
        self.a = a
        self.b = b
    }

    init?<C: Collection>(from collection: C) where C.Element == T {
        guard collection.count == 2 else { return nil }
        self.a = collection.first!
        self.b = collection.dropFirst().first!
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.a)
        hasher.combine(self.b)
    }
    
    static func ==(lhs: Pair, rhs: Pair) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
    
    func contains(_ other: T) -> Bool {
        return a == other || b == other
    }
    
    func makeIterator() -> PairIterator<T> {
        return PairIterator(pair: self)
    }
}

struct PairIterator<T: Hashable>: IteratorProtocol {
    let pair: Pair<T>
    var index = 0
    
    mutating func next() -> T? {
        guard index < 2 else { return nil }
        defer { index += 1 }
        return index == 0 ? pair.a : pair.b
    }
}

// Given two Pair, return the value that is common in both pairs, if any
func commonElement<T>(in pair1: Pair<T>, and pair2: Pair<T>) -> T? {
    if pair1.contains(pair2.a) {
        return pair2.a
    } else if pair1.contains(pair2.b) {
        return pair2.b
    }
    return nil
}

// Finds and returns pairs that share at least one common element.
func findIntersectingPairs<T>(_ pairs: Set<Pair<T>>) -> [(Pair<T>, Pair<T>)] {
    var intersectingPairs: [(Pair<T>, Pair<T>)] = []
    var visitedPairs: Set<Pair<T>> = []
    for pair1 in pairs {
        for pair2 in pairs where pair1 != pair2 && !visitedPairs.contains(pair2) {
            // Check if pair1 and pair2 have at least one value in common
            if pair1.contains(pair2.a) || pair1.contains(pair2.b) {
                intersectingPairs.append((pair1, pair2))
            }
        }
        // Mark pair1 as visited after checking all other pairs against it
        visitedPairs.insert(pair1)
    }
    return intersectingPairs
}
