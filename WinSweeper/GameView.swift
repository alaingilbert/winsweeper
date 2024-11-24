import Foundation
import AppKit
import GameplayKit

@IBDesignable
class GameView : NSView {
    
    weak var delegate: GameViewDelegate?
    weak var gameBoard: GameBoard?
    
    var flagsLbl = NSTextField()
    var timerLbl = NSTextField()
    var safeSqLbl = NSTextField()
    
    let tileSize = 40
    let nbHorizontalTiles = 19
    let nbVerticalTiles = 13
    var tilesView: [TileView] = []
    var debugMines = false
    var dbgIdx = false
    var dbgProb = false
    private let cursorLayer = CAShapeLayer()
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setupCursorLayer()
    }
    
    func showCursor() {
        cursorLayer.isHidden = false
    }
    
    func hideCursor() {
        cursorLayer.isHidden = true
    }
    
    private func setupCursorLayer() {
        self.wantsLayer = true
        self.layer?.addSublayer(cursorLayer)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: -13))
        path.addLine(to: CGPoint(x: 4, y: -12))
        path.addLine(to: CGPoint(x: 0, y: -16))
        path.closeSubpath()
        
        cursorLayer.shadowColor = NSColor.black.cgColor
        cursorLayer.shadowOpacity = 0.5
        cursorLayer.shadowOffset = CGSize(width: 0, height: -1)
        cursorLayer.shadowRadius = 1.0
        
        cursorLayer.path = path
        cursorLayer.fillColor = NSColor.black.cgColor
        cursorLayer.strokeColor = NSColor.white.cgColor
        cursorLayer.position = CGPoint(x: 100, y: 100)
        cursorLayer.isHidden = true
    }
    
    func moveCursor(to newPosition: CGPoint) {
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = cursorLayer.position
        animation.toValue = newPosition
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cursorLayer.position = newPosition
        cursorLayer.add(animation, forKey: "position")
    }
    
    func initTilesView() {
        tilesView = gameBoard!.tiles.map { TileView(tile: $0, coord: coordFromIdx($0.idx()), size: tileSize) }
    }
    
    func horizontalSize() -> Int { return nbHorizontalTiles * tileSize }
    func verticalSize() -> Int { return nbVerticalTiles * tileSize }
    func nbTiles() -> Int { return nbHorizontalTiles * nbVerticalTiles }
    func idxFromCoordinate(_ x: Int, _ y: Int) -> Int { y * nbHorizontalTiles + x }

    func coordFromIdx(_ idx: Int) -> (Int, Int) {
        coordFromIdxUtils(idx, width: nbHorizontalTiles)
    }

    func coordFromPoint(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor( point.x       / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }
    
    func pointFromCoord(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor( point.x       / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }
    
    func idxFromPoint(_ point: NSPoint) -> Int {
        let (x, y) = coordFromPoint(point)
        return idxFromCoordinate(x, y)
    }
    
    func pointFromIdx(_ idx: Int) -> CGPoint {
        let (x, y) = coordFromIdxUtils(idx, width: nbHorizontalTiles)
        return CGPoint(x: x*tileSize + tileSize/2, y: y*tileSize + tileSize/2)
    }
    
    func refreshTimerLabel(seconds: Int) {
        timerLbl.stringValue = String(format: "Time: %d", seconds)
    }
    
    func drawWin(ctx: CGContext) {
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
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect);
        NSColor.white.setFill()
        dirtyRect.fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            for tileView in tilesView {
                tileView.render(ctx: ctx, debugMines: debugMines, dbgIdx: dbgIdx, dbgProb: dbgProb)
            }
            if gameBoard!.state == .Win {
                drawWin(ctx: ctx)
            }
        }
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
        let tileIdx = idxFromPoint(event.locationInWindow)
        delegate?.gameView(self, didLeftClickTileAt: tileIdx)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        if !checkBounds(event) {
            return
        }
        super.rightMouseUp(with: event)
        let tileIdx = idxFromPoint(event.locationInWindow)
        delegate?.gameView(self, didRightClickTileAt: tileIdx)
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
        guard let gameBoard = gameBoard else { return }
        flagsLbl.stringValue = String(format: "Flags: %d/%d", gameBoard.countFlags(), gameBoard.nbMines)
        safeSqLbl.stringValue = String(format: "Safe: %d", gameBoard.knownSafeTiles().count)
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
        get { return true }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let gameBoard = gameBoard else { return }
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
            delegate?.gameViewToggleAutoPlay()
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
            gameBoard.flagKnownMines()
        case "c":
            gameBoard.showSafeTiles()
        case "s":
            print("Known mines:", gameBoard.countKnownMines())
            print("Unknown mines:", gameBoard.countUnknownMines())
            print("Discovered:", gameBoard.discoveredTiles().map { $0.idx() })
            print("Serialized:", gameBoard.serialize())
            print("Seed:", gameBoard.seed)
        case "r":
            gameBoard.reset()
        case "z":
            if event.modifierFlags.contains(.shift) {
                gameBoard.redo()
            } else {
                gameBoard.undo()
            }
            tilesView = gameBoard.tiles.map { TileView(tile: $0, coord: coordFromIdx($0.idx()), size: tileSize) }
            redraw()
        default:
            break
        }
    }
}
