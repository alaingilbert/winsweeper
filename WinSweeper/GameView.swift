import Foundation
import AppKit
import GameplayKit

@IBDesignable
class GameView : NSView {
    
    enum State {
        case Waiting, GameOver, Win, Playing
    }
    
    var flagsLbl = NSTextField()
    var timerLbl = NSTextField()
    var safeSqLbl = NSTextField()
    
    var timer = Timer()
    var seconds = 0
    let tileSize = 40
    let nbHorizontalTiles = 19
    let nbVerticalTiles = 13
    var state = State.Waiting
    var tilesView: [TileView] = []
    var safe: Int = 0
    var debugMines = false
    var dbgIdx = false
    var dbgProb = false
    var knownSafeCount = 0
    var gameBoard: GameBoard
    var isAutoplaying = false
    
    required init?(coder decoder: NSCoder) {
        gameBoard = GameBoard(width: nbHorizontalTiles, height: nbVerticalTiles)
        super.init(coder: decoder)
        tilesView = gameBoard.tiles.map { TileView(tile: $0, coord: coordFromIdx($0.idx()), size: tileSize) }
    }
    
    func horizontalSize() -> Int { return nbHorizontalTiles * tileSize }
    func verticalSize() -> Int { return nbVerticalTiles * tileSize }
    func nbTiles() -> Int { return nbHorizontalTiles * nbVerticalTiles }
    func idxFromCoordinate(_ x: Int, _ y: Int) -> Int { y * nbHorizontalTiles + x }

    func coordFromIdx(_ idx: Int) -> (Int, Int) {
        coordFromIdxUtils(idx, width: nbHorizontalTiles)
    }

    func reset() {
        gameBoard.reset()
        seconds = 0
        flagsLbl.stringValue = "Flags: 0/50"
        timerLbl.stringValue = "Time: 0"
        safeSqLbl.stringValue = "Safe: 0"
        knownSafeCount = 0
    }

    func coordFromPoint(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor( point.x       / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }
    
    func idxFromPoint(_ point: NSPoint) -> Int {
        let (x, y) = coordFromPoint(point)
        return idxFromCoordinate(x, y)
    }
    
    func showMines(deadIdx: Int) {
        for tile in gameBoard.tiles {
            let tileIdx = tile.idx()
            if tile.idx() == deadIdx {
                tile.state = .ExplodedMine
            } else if gameBoard.isMine(tileIdx) && gameBoard.isFlag(tileIdx) {
                tile.state = .FlaggedMine
            } else if gameBoard.isFlag(tileIdx) {
                tile.state = .BadFlag
            } else if gameBoard.isMine(tileIdx) {
                tile.state = .Mine
            }
        }
    }
    
    func gameOver(_ tile: Tile) {
        state = .GameOver
        showMines(deadIdx: tile.idx());
    }
    
    func win(ctx: CGContext) {
        showMines(deadIdx: -1)
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
        ctx.fill(bounds)
        ctx.restoreGState()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Arial", size: 40)!,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor(calibratedRed: 0, green: 0.502, blue: 0, alpha: 1),
        ]
        "Win".draw(with: CGRect(x: 0, y: ((verticalSize()) + tileSize) / 2, width: horizontalSize(), height: tileSize), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    func toggleFlag(_ tile: Tile) {
        if tile.state == .Empty {
            tile.state = .Flagged
        } else if tile.state == .Flagged {
            tile.state = .Empty
        }
        flagsLbl.stringValue = String(format: "Flags: %d/%d", gameBoard.countFlags(), gameBoard.nbMines)
    }
    
    func checkGameOver(_ tilesToShow: [Tile]) -> Bool {
        for tile in tilesToShow {
            guard tile.state == .Empty else { continue }
            if tile.isMine {
                gameOver(tile)
                return true
            }
        }
        return false
    }
    
    @objc func updateTimer() {
        seconds += 1
        timerLbl.stringValue = String(format: "Time: %d", seconds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect);
        NSColor.white.setFill()
        dirtyRect.fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            for tileView in tilesView {
                tileView.render(ctx: ctx, debugMines: debugMines, dbgIdx: dbgIdx, dbgProb: dbgProb)
            }
            if state == .Win {
                win(ctx: ctx)
            }
        }
    }
    
    func blessing(_ tile: Tile) {
        // No blessing if there was a 50/50 and you didn't click one
        guard gameBoard.halfPairs.isEmpty || tile.getProb() == 0.5 else { return }
        if let pair = gameBoard.halfPairs.first(tile) {
            // Swap mines if the board stays valid
            pair.a.isMine.toggle()
            pair.b.isMine.toggle()
            if gameBoard.isValid() {
                return
            }
            // Otherwise, revert the change
            pair.a.isMine.toggle()
            pair.b.isMine.toggle()
            
            let globalUnknownMines = gameBoard.countUnknownMines()
            // If there is only 1 mine left to find, swap the mine to the other tile
            if globalUnknownMines == 1 {
                if pair.a == tile {
                    pair.a.isMine = false
                    pair.b.isMine = true
                } else {
                    pair.a.isMine = true
                    pair.b.isMine = false
                }
                return
            } else if globalUnknownMines == 2 {
                let sut = gameBoard.unknownTiles().sorted()
                let isSquare = sut.count == 4 &&
                               sut[0].idx()+1 == sut[1].idx() &&
                               sut[2].idx()+1 == sut[3].idx() &&
                               sut[0].idx()+nbHorizontalTiles == sut[2].idx()
                // 4 tiles in a 2x2 square with 2 mines, swap mines location
                if isSquare {
                    if sut[0] == tile || sut[3] == tile {
                        sut[0].isMine = false
                        sut[3].isMine = false
                        sut[1].isMine = true
                        sut[2].isMine = true
                    } else if sut[1] == tile || sut[2] == tile {
                        sut[0].isMine = true
                        sut[3].isMine = true
                        sut[1].isMine = false
                        sut[2].isMine = false
                    }
                    return
                }
            }
        }
        if !gameBoard.rebalance(tile) {
            fatalError("failed to rebalance")
        }
    }
    
    func autoplay() {
        isAutoplaying = true
        self.startRound()
    }
    
    func stopAutoplay() {
        isAutoplaying = false
    }
    
    private func startRound() {
        guard isAutoplaying else { return }
        let mineTiles = gameBoard.knownMines().filter { !$0.isFlagged() }
        flagMinesRecursively(mineTiles)
    }
    
    private func flagMinesRecursively(_ tiles: [Tile]) {
        guard isAutoplaying else { return }
        guard !tiles.isEmpty else {
            revealSafeTiles()
            return
        }
        var remainingTiles = tiles
        let tile = remainingTiles.removeFirst()
        if !tile.isFlagged() {
            print("AUTOPLAY: flag \(tile.idx())")
            rightClickOnTile(tile)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
             self.flagMinesRecursively(remainingTiles)
        }
    }
    
    private func revealSafeTiles() {
        let safeTiles = gameBoard.knownSafeTiles()
        revealSafeTilesRecursively(safeTiles)
    }

    private func revealSafeTilesRecursively(_ tiles: [Tile]) {
        guard isAutoplaying else { return }
        guard !tiles.isEmpty else {
            if gameBoard.knownSafeTiles().count > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.startRound() }
            } else if let pair = gameBoard.halfPairs.first {
                print("AUTOPLAY: take 50/50 on \(pair.a.idx())")
                clickOnTile(pair.a)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.startRound() }
            } else if let tile = gameBoard.tiles.first(where: { $0.isFound() }) {
                print("AUTOPLAY: take guess on \(tile.idx())")
                clickOnTile(tile)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.startRound() }
            } else if let tile = gameBoard.tiles.first(where: { $0.isUnfound() }) {
                print("AUTOPLAY: take guess on unfound tile \(tile.idx())")
                clickOnTile(tile)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.startRound() }
            } else {
                print("AUTOPLAY: noting to click on")
                isAutoplaying = false
            }
            return
        }

        var remainingTiles = tiles
        let tile = remainingTiles.removeFirst()
        print("AUTOPLAY: click on \(tile.idx())")
        clickOnTile(tile)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.revealSafeTilesRecursively(remainingTiles)
        }
    }
    
    func clickOnTile(_ tile: Tile) {
        if state == .Waiting {
            let seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
            gameBoard.initBoard(seed: seed, tile.idx())
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            state = .Playing
        }
        
        if state == .Playing {
            // Game will make the odds works for you if there is no more safe square to click
            if tile.isMine &&         // cliked a mine
                !tile.IsProbMine() && // that is not `known`
                knownSafeCount == 0   // and there is no safe tile remaining
            {
                blessing(tile)
            }
            
            var tilesToShow = [tile]
            if tile.IsDiscovered() && gameBoard.countFlags(around: tile) == gameBoard.countMines(around: tile) {
                tilesToShow.append(contentsOf: tile.neighbors())
            }
            if !checkGameOver(tilesToShow) {
                gameBoard.showTiles(tilesToShow)
                if gameBoard.didWin() {
                    state = .Win
                    updateSafeCount()
                }
            }
            if state == .Playing {
                updateSafeCount()
            }
        } else if state == .GameOver || state == .Win {
            reset()
            state = .Waiting
        }
        
        if state == .GameOver || state == .Win {
            timer.invalidate()
        }
        redraw()
    }
    
    func rightClickOnTile(_ tile: Tile) {
        if state == .Playing {
            toggleFlag(tile)
        }
        redraw()
    }
    
    func updateSafeCount() {
        knownSafeCount = gameBoard.knownSafeTiles().count
        safeSqLbl.stringValue = String(format: "Safe: %d", knownSafeCount)
    }
    
    override func mouseUp(with event: NSEvent) {
        if !checkBounds(event) {
            return
        }
        if event.modifierFlags.contains(.command) {
            rightMouseUp(with: event)
            return
        }
        super.mouseUp(with: event)
        let tile = gameBoard.tiles[idxFromPoint(event.locationInWindow)]
        clickOnTile(tile)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        if !checkBounds(event) {
            return
        }
        super.rightMouseUp(with: event)
        let tile = gameBoard.tiles[idxFromPoint(event.locationInWindow)]
        rightClickOnTile(tile)
    }
    
    // Return true if the event is within the application bounds
    // It is possible to mousedown in the window and mouseup outside of it and still receive the event.
    // This will prevent processing events like mouseup that are out of bounds
    func checkBounds(_ event: NSEvent) -> Bool {
        var point = event.locationInWindow
        point.y -= 20
        return bounds.contains(point)
    }
    
    func redraw() {
        setNeedsDisplay(bounds)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let character = event.characters else { return }
        switch character.lowercased() {
        case "1":
            let tileIdx = idxFromPoint(event.locationInWindow)
            try! gameBoard.tiles[tileIdx].SetProbMine()
            try! calcProb(gameBoard: gameBoard)
            redraw()
        case "0":
            let tileIdx = idxFromPoint(event.locationInWindow)
            try! gameBoard.tiles[tileIdx].SetProbNoMine()
            try! calcProb(gameBoard: gameBoard)
            redraw()
        case "a":
            if !isAutoplaying {
                autoplay()
            } else {
                stopAutoplay()
            }
        case "m":
            debugMines.toggle()
            redraw()
        case "i":
            dbgIdx.toggle()
            redraw()
        case "p":
            dbgProb.toggle()
            redraw()
        case "f":
            if state == .Playing {
                gameBoard.flagKnownMines()
                flagsLbl.stringValue = String(format: "Flags: %d/%d", gameBoard.countFlags(), gameBoard.nbMines)
                redraw()
            }
        case "c":
            if state == .Playing {
                gameBoard.showSafeTiles()
                // Update known safe tiles
                updateSafeCount()
                redraw()
            }
        case "s":
            print("Known mines:", gameBoard.countKnownMines())
            print("Unknown mines:", gameBoard.countUnknownMines())
            print("Discovered:", gameBoard.discoveredTiles().map { $0.idx() })
            print("Serialized:", gameBoard.serialize())
            print("Seed:", gameBoard.seed)
        case "r":
            timer.invalidate()
            reset()
            state = .Waiting
            redraw()
        case "z":
            if state == .Playing {
                if event.modifierFlags.contains(.shift) {
                    gameBoard.redo()
                } else {
                    gameBoard.undo()
                }
                tilesView = gameBoard.tiles.map { TileView(tile: $0, coord: coordFromIdx($0.idx()), size: tileSize) }
                redraw()
            }
        default:
            break
        }
    }
}
