import Carbon.HIToolbox
import Foundation

/// All customizable player actions.
enum PlayerAction: String, CaseIterable, Codable, Identifiable {
    case seekBackward
    case seekForward
    case volumeDown
    case volumeUp
    case previousVideo
    case nextVideo
    case decreaseSpeed
    case increaseSpeed
    case togglePlayPause

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .seekBackward:    return "Seek Backward"
        case .seekForward:     return "Seek Forward"
        case .volumeDown:      return "Volume Down"
        case .volumeUp:        return "Volume Up"
        case .previousVideo:   return "Previous Video"
        case .nextVideo:       return "Next Video"
        case .decreaseSpeed:   return "Decrease Speed"
        case .increaseSpeed:   return "Increase Speed"
        case .togglePlayPause: return "Play / Pause"
        }
    }

    var defaultBinding: StoredKeyBinding {
        switch self {
        case .seekBackward:    return StoredKeyBinding(keyCode: kVK_LeftArrow, displayName: "←")
        case .seekForward:     return StoredKeyBinding(keyCode: kVK_RightArrow, displayName: "→")
        case .volumeDown:      return StoredKeyBinding(keyCode: kVK_DownArrow, displayName: "↓")
        case .volumeUp:        return StoredKeyBinding(keyCode: kVK_UpArrow, displayName: "↑")
        case .previousVideo:   return StoredKeyBinding(keyCode: kVK_PageUp, displayName: "Page Up")
        case .nextVideo:       return StoredKeyBinding(keyCode: kVK_PageDown, displayName: "Page Down")
        case .decreaseSpeed:   return StoredKeyBinding(keyCode: kVK_ANSI_LeftBracket, displayName: "[")
        case .increaseSpeed:   return StoredKeyBinding(keyCode: kVK_ANSI_RightBracket, displayName: "]")
        case .togglePlayPause: return StoredKeyBinding(keyCode: kVK_Space, displayName: "Space")
        }
    }
}

/// A persistable key binding using hardware key codes.
struct StoredKeyBinding: Codable, Hashable {
    /// Hardware key code (from Carbon HIToolbox kVK_* constants).
    let keyCode: Int
    /// Human-readable name for display in the UI.
    let displayName: String

    /// Build a display name from an NSEvent's key code.
    static func displayName(forKeyCode keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow:      return "←"
        case kVK_RightArrow:     return "→"
        case kVK_UpArrow:        return "↑"
        case kVK_DownArrow:      return "↓"
        case kVK_Space:          return "Space"
        case kVK_Return:         return "Return"
        case kVK_Tab:            return "Tab"
        case kVK_Delete:         return "Delete"
        case kVK_ForwardDelete:  return "Fwd Delete"
        case kVK_Escape:         return "Esc"
        case kVK_Home:           return "Home"
        case kVK_End:            return "End"
        case kVK_PageUp:         return "Page Up"
        case kVK_PageDown:       return "Page Down"
        case kVK_F1:             return "F1"
        case kVK_F2:             return "F2"
        case kVK_F3:             return "F3"
        case kVK_F4:             return "F4"
        case kVK_F5:             return "F5"
        case kVK_F6:             return "F6"
        case kVK_F7:             return "F7"
        case kVK_F8:             return "F8"
        case kVK_F9:             return "F9"
        case kVK_F10:            return "F10"
        case kVK_F11:            return "F11"
        case kVK_F12:            return "F12"
        default:
            if let characters, !characters.isEmpty {
                return characters.uppercased()
            }
            return "Key \(keyCode)"
        }
    }
}
