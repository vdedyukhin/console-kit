#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Foundation

/// Generic console that uses a mixture of Swift standard
/// library and Foundation code to fulfill protocol requirements.
public final class Terminal: Console {
    /// See `Console`
    public var userInfo: [AnyHashable: Any]

    /// Dynamically exclude ANSI commands when in Xcode since it doesn't support them.
    internal var enableCommands: Bool {
        if let stylizeOverride = self.stylizedOutputOverride {
            return stylizeOverride
        }
        #if Xcode
            return false
        #else
            return isatty(STDOUT_FILENO) > 0
        #endif
    }

    /// Create a new Terminal.
    public init() {
        self.userInfo = [:]
    }

    /// See `Console`
    public func clear(_ type: ConsoleClear) {
        switch type {
        case .line:
            command(.cursorUp)
            command(.eraseLine)
        case .screen:
            command(.eraseScreen)
        }
    }

    /// See `Console`
    public func input(isSecure: Bool) -> String {
        didOutputLines(count: 1)
        if isSecure {
            // http://stackoverflow.com/a/30878869/2611971
            let entry: UnsafeMutablePointer<Int8> = getpass("")
            let pointer: UnsafePointer<CChar> = .init(entry)
            guard var pass = String(validatingUTF8: pointer) else {
                return ""
            }
            if pass.hasSuffix("\n") {
                pass = String(pass.dropLast())
            }
            return pass
        } else {
            guard let line = readLine(strippingNewline: true) else {
                fatalError("Received EOF on stdin; unable to read input. Stopping here.")
            }
            return line
        }
    }

    /// See `Console`
    public func output(_ text: ConsoleText, newLine: Bool) {
        var lines = 0
        for fragment in text.fragments {
            let strings = fragment.string.split(separator: "\n", omittingEmptySubsequences: false)
            for string in strings {
                let count = string.count
                if count > size.width && count > 0 && size.width > 0 {
                    lines += (count / size.width) + 1
                }
            }
            /// add line for each fragment
            lines += strings.count - 1
        }
        if newLine { lines += 1 }

        didOutputLines(count: lines)

        let terminator = newLine ? "\n" : ""

        let output: String
        if enableCommands {
            output = text.terminalStylize()
        } else {
            output = text.description
        }
        Swift.print(output, terminator: terminator)
        fflush(stdout)
    }

    /// See `Console`
    public func report(error: String, newLine: Bool) {
        let output = newLine ? error + "\n" : error
        let data = output.data(using: .utf8) ?? Data()
        FileHandle.standardError.write(data)
    }

    /// See `Console`
    public var size: (width: Int, height: Int) {
        var w = winsize()
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w);
        return (Int(w.ws_col), Int(w.ws_row))
    }
}

extension Console {
    
    /// If set, overrides a `Terminal`'s own determination as to whether its
    /// output supports color commands. Useful for easily implementing an option
    /// of the form `--color=no|yes|auto`. If the active `Console` is not
    /// specifically a `Terminal`, has no effect.
    public var stylizedOutputOverride: Bool? {
        get { return self.userInfo["stylizedOutputOverride"] as? Bool }
        set { self.userInfo["stylizedOutputOverride"] = newValue }
    }

}
