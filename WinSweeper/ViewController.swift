import Cocoa

protocol GameViewDelegate: AnyObject {
    func gameView(_ gameView: GameView, didRightClickTileAt idx: Int)
    func gameView(_ gameView: GameView, didLeftClickTileAt idx: Int)
    func gameViewToggleAutoPlay()
}

protocol GameBoardDelegate: AnyObject {
    func gameBoardGameStarted()
    func gameBoardGameEnded()
    func gameBoardGameReset()
    func gameBoardDidUpdate()
}

class ViewController: NSViewController, GameViewDelegate, GameBoardDelegate {
    
    @IBOutlet weak var timerLbl: NSTextField!
    @IBOutlet weak var flagsLbl: NSTextField!
    @IBOutlet weak var safeSqLbl: NSTextField!
    @IBOutlet weak var gameView: GameView!
    
    var autoPlayer: AutoPlayer?
    var gameBoard: GameBoard?
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        gameView.flagsLbl = flagsLbl
        gameView.timerLbl = timerLbl
        gameView.safeSqLbl = safeSqLbl
        
        gameBoard = GameBoard(width: 19, height: 13)
        gameBoard?.delegate = self
        gameView.delegate = self
        gameView.gameBoard = gameBoard
        gameView.initTilesView()
        
        autoPlayer = AutoPlayer(gameBoard: gameBoard!, gameView: gameView!)
    }

    func gameViewToggleAutoPlay() {
        autoPlayer?.toggle()
    }
    
    func gameView(_ gameView: GameView, didLeftClickTileAt idx: Int) {
        gameBoard?.handleLeftClick(at: idx)
    }
    
    func gameView(_ gameView: GameView, didRightClickTileAt idx: Int) {
        gameBoard?.handleRightClick(at: idx)
    }
    
    func gameBoardGameStarted() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    func gameBoardGameEnded() {
        timer.invalidate()
    }
    
    func gameBoardDidUpdate() {
        gameView.redraw()
    }
    
    func gameBoardGameReset() {
        guard let gameBoard = gameBoard else { return }
        timer.invalidate()
        gameView.refreshTimerLabel(seconds: gameBoard.seconds)
    }
    
    @objc func updateTimer() {
        guard let gameBoard = gameBoard else { return }
        gameView.refreshTimerLabel(seconds: gameBoard.tick())
    }
}

