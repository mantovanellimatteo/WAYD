import Cocoa

// Global strong reference to keep the AppDelegate alive for the life of the app
var appDelegate: AppDelegate?

let app = NSApplication.shared
let delegate = AppDelegate()
appDelegate = delegate
app.delegate = delegate
app.run()
