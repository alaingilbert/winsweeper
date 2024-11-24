import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        gameView.flagsLbl = flagsLbl
        gameView.timerLbl = timerLbl
        gameView.safeSqLbl = safeSqLbl
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBOutlet weak var timerLbl: NSTextField!
    @IBOutlet weak var flagsLbl: NSTextField!
    @IBOutlet weak var safeSqLbl: NSTextField!
    @IBOutlet weak var gameView: GameView!
    
}

