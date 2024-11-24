import Foundation

class AutoPlayer {
    private weak var gameBoard: GameBoard?
    private weak var gameView: GameView?
    private var isPlaying = false
    
    init(gameBoard: GameBoard, gameView: GameView) {
        self.gameBoard = gameBoard
        self.gameView = gameView
    }
    
    func toggle() {
        isPlaying.toggle()
        if isPlaying {
            gameView?.showCursor()
            self.startRound()
        } else {
            gameView?.hideCursor()
        }
    }
    
    private func startRound() {
        guard let gameBoard = gameBoard else { return }
        guard isPlaying else { return }
        let mineTiles = gameBoard.knownMines().filter { !$0.isFlagged() }
        flagMinesRecursively(mineTiles)
    }
    
    private func flagMinesRecursively(_ tiles: [Tile]) {
        guard isPlaying else { return }
        guard !tiles.isEmpty else {
            revealSafeTiles()
            return
        }
        var remainingTiles = tiles
        let tile = remainingTiles.removeFirst()
        if !tile.isFlagged() {
            print("AUTOPLAY: flag \(tile.idx())")
            moveCursor(to: tile.idx(), clb: {
                self.gameBoard?.handleRightClick(at: tile.idx())
            })
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             self.flagMinesRecursively(remainingTiles)
        }
    }
    
    private func revealSafeTiles() {
        guard let gameBoard = gameBoard else { return }
        let safeTiles = gameBoard.knownSafeTiles()
        revealSafeTilesRecursively(safeTiles)
    }
    
    private func moveCursor(to: Int, clb: @escaping () -> Void) {
        gameView?.moveCursor(to: gameView!.pointFromIdx(to))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            clb()
        }
    }

    private func revealSafeTilesRecursively(_ tiles: [Tile]) {
        guard let gameBoard = gameBoard else { return }
        guard isPlaying else { return }
        guard !tiles.isEmpty else {
            if gameBoard.knownSafeTiles().count > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.startRound() }
            } else if let pair = gameBoard.halfPairs.first {
                print("AUTOPLAY: take 50/50 on \(pair.a.idx())")
                moveCursor(to: pair.a.idx(), clb: {
                    gameBoard.handleLeftClick(at: pair.a.idx())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.startRound() }
                })
            } else if let tile = gameBoard.tiles.first(where: { $0.isFound() }) {
                print("AUTOPLAY: take guess on \(tile.idx())")
                moveCursor(to: tile.idx(), clb: {
                    gameBoard.handleLeftClick(at: tile.idx())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.startRound() }
                })
            } else if let tile = gameBoard.tiles.first(where: { $0.isUnfound() }) {
                print("AUTOPLAY: take guess on unfound tile \(tile.idx())")
                moveCursor(to: tile.idx(), clb: {
                    gameBoard.handleLeftClick(at: tile.idx())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.startRound() }
                })
            } else {
                print("AUTOPLAY: noting to click on")
                isPlaying = false
                gameView?.hideCursor()
            }
            return
        }

        var remainingTiles = tiles
        let tile = remainingTiles.removeFirst()
        print("AUTOPLAY: click on \(tile.idx())")
        moveCursor(to: tile.idx(), clb: {
            gameBoard.handleLeftClick(at: tile.idx())
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.revealSafeTilesRecursively(remainingTiles)
        }
    }
}
