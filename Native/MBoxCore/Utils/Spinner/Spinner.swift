import Foundation
import Dispatch
import Signals

public final class Spinner {

    /// Pattern holding frames to be animated    
    var pattern: SpinnerPattern {
        didSet {
            self.frameTimestamp = Date()
        }
    }
    /// Text that is displayed next to spinner
    var text: String
    /// Boolean representing fs the spinner is currently animating
    var running: Bool
    /// Int representing the index of the current frame
    var frameTimestamp: Date?
    /// Double repenting the wait time for frame animation
    var speed: Double
    /// Color of the spinner
    var color: ANSIColor?
    /// timestamp
    var timestamp: Date?
    /// Format of the Spinner
    var format: String

    weak var manager: SpinnerManager?

    /**
    Create new spinner 

    - Parameter _: SpinnerPattern - The pattern the spinner will animate over
    - Parameter _: String - The text the spinner will display
    - Parameter speed: Double - The speed the spinner will animate at - default is defined per SpinnerPattern
    - Parameter color: Color - The color the animated pattern will render as - default is white
    - Parameter: format: String - The format of the spinner - default is "{S} {T}"
    */
    public init(_ pattern: SpinnerPattern, _ text: String = "", speed: Double? = nil, color: ANSIColor? = nil, format: String = "{S} {T}") {
        self.pattern = pattern
        self.text = text
        self.speed = speed ?? pattern.defaultSpeed
        self.color = color
        self.format = format.uppercased()

        self.running = false
    }

    /**
    Starts the animation for the spinner.
    */
    public func start() {
        self.running = true
        self.timestamp = Date()
        self.frameTimestamp = self.timestamp
    }

    /**
    Stops the animation for the spinner.

    - Parameter finalFrame: String - The persistent frame that will be displayed on the completed spinner, default is 'nil' this will keep the current frame the spinner is on
    - Parameter text: String - The persistent text that will be displayed on the completed spinner, default is 'nil' this will keep the current text the spinner has
    - Parameter color: Color - The color of the final spinner frame
    - Parameter terminator: String - The terminator used for ending writing a line to the terminal, default is '\n' this will return the curser to a new line
    */
    public func stop(finalFrame: String? = nil, text: String? = nil, color: ANSIColor? = nil, terminator: String = "\n") {
        if let text = text {
            self.updateText(text)
        }
        if let color = color {
            self.updateColor(color)
        }
        var finalPattern: SpinnerPattern?
        if let frame = finalFrame {
            finalPattern = SpinnerPattern(singleFrame: frame)
        }
        if let pattern = finalPattern {
            self.text += Array(repeating: " ", count: self.getPatternPadding(pattern))
            self.pattern = pattern
        }
        self.running = false
        self.manager?.updateSpinner(self)
    }

    /**
    Clears the spinner from the terminal and returns the curser to the start of the spinner
    */
    public func clear() {
        self.stop(finalFrame: "", text: "", terminator: "\r")
    }

    /**
    Updates the pattern displayed by the spinner

    - Parameter _: SpinnerPattern - New pattern the spinner should animate over
    */
    public func updatePattern(_ newPattern: SpinnerPattern) {
        self.format += Array(repeating: " ", count: self.getPatternPadding(newPattern))
        self.pattern = newPattern
    }

    /**
    Updates the text displayed next to the spinner
    
    - Parameter _: String - New text the spinner should display
    */
    public func updateText(_ newText: String) {
        self.format += Array(repeating: " ", count: self.getTextPadding(newText))
        self.text = newText
    }

    /**
    Updates the speed of the spinner

    - Parameter _: Double - New speed the spinner should animate at
    */
    public func updateSpeed(_ newSpeed: Double) {
        self.speed = newSpeed
    } 

    /**
    Updates the color of the spinner

    - Parameter _: Color - New color for the spinner
    */
    public func updateColor(_ newColor: ANSIColor) {
        self.color = newColor
    }

    /**
    Updates the format the spinier will render as

    - Parameter _: String - New format for spinner to display as
    */
    public func updateFormat(_ newFormat: String) {
        self.format = newFormat
    }

    /**
    Stops the spinner and displays a green ✔ with the provided text

   - Parameter _: String The persistent text that will be displayed on the completed spinner, default will keep the current text of the spinner 
    */
    public func succeed(_ text: String? = nil) {
        self.stop(finalFrame: "✔", text: text, color: .green)
    }

    /**
    Stops the spinner and displays a red ✖ with the provided text

    - Parameter _: String The persistent text that will be displayed on the completed spinner
    */
    public func failure(_ text: String? = nil) {
        self.stop(finalFrame: "✖", text: text, color: .red)
    }

    /**
    Stops the spinner and displays a yellow ⚠ with the provided text

    - Parameter _: String The persistent text that will be displayed on the completed spinner,  default will keep the current text of the spinner 
    */
    public func warning(_ text: String? = nil) {
        self.stop(finalFrame: "⚠", text: text, color: .yellow)
    }

    /**
    Stops the spinner and displays a blue ℹ with the provided text

    - Parameter _: String The persistent text that will be displayed on the completed spinner,  default will keep the current text of the spinner 
    */
    public func information(_ text: String? = nil) {
        self.stop(finalFrame: "ℹ", text: text, color: .blue)
    }

    func getTextPadding(_ newText: String) -> Int {

        let newText = newText.noANSI
        let oldText = self.text.noANSI

        let textLengthDifference: Int = oldText.count - newText.count

        if textLengthDifference > 0 {
            return textLengthDifference
        } else {
            return 0
        }
    }

    func getPatternPadding(_ newPattern: SpinnerPattern) -> Int {
        
        let newPatternFrameWidth: Int = newPattern.frames[0].noANSI.count
        let oldPatternFrameWidth: Int = self.pattern.frames[0].noANSI.count

        let patternFrameWidthDifference: Int = oldPatternFrameWidth - newPatternFrameWidth

        if patternFrameWidthDifference > 0 {
            return patternFrameWidthDifference
        }else {
            return 0
        }
    }

    func currentFrame() -> String {
        let frameIndex = Int(Date().timeIntervalSince(self.frameTimestamp!) / self.speed) % self.pattern.frames.count

        let currentFrame = self.pattern.frames[frameIndex]
        let frame: String
        if let color = color {
            frame = currentFrame.ANSI(color)
        } else {
            frame = currentFrame
        }
        return frame
    }

    func renderSpinner() -> String {
        // Print the spinner frame and text
        var  renderString = self.format.replacingOccurrences(of: "{S}", with: self.currentFrame()).replacingOccurrences(of: "{T}", with: self.text)
        // get duration
        if let timestamp = self.timestamp {
            let duration = Int(Date().timeIntervalSince(timestamp))
            renderString = renderString.replacingOccurrences(of: "{D}", with: duration.timeString)
        }
        renderString.append(AnsiCodes.eraseRight)
        return renderString
        
        // Flush STDOUT
//        fflush(stdout)

    }
}
