import Foundation
import AppKit
import PDFVeCore

/// 侧边栏标签页
public enum SidebarTab: String, CaseIterable {
    case outline = "outline"
    case annotation = "annotation"
    case bookmark = "bookmark"
    case thumbnail = "thumbnail"
}

/// 窗口状态管理器 - 持久化窗口大小、位置和侧边栏标签页状态
@MainActor
public class WindowStateManager: ObservableObject {
    public static let shared = WindowStateManager()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let lastSidebarTab = "lastSidebarTab"
        static let sidebarVisible = "sidebarVisible"
        static let windowWidth = "windowWidth"
        static let windowHeight = "windowHeight"
        static let windowX = "windowX"
        static let windowY = "windowY"
        static let lastOpenedFilePath = "lastOpenedFilePath"
        static let autoReopenLastDocument = "autoReopenLastDocument"
        static let defaultReadingMode = "defaultReadingMode"
        static let defaultDisplayMode = "defaultDisplayMode"
    }

    public init() {}

    // MARK: - 侧边栏标签页

    /// 上次选择的侧边栏标签页
    public var lastSidebarTab: SidebarTab {
        get {
            guard let raw = defaults.string(forKey: Keys.lastSidebarTab),
                  let tab = SidebarTab(rawValue: raw) else {
                return .outline
            }
            return tab
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.lastSidebarTab)
        }
    }

    // MARK: - 侧边栏可见性

    /// 侧边栏是否可见
    public var sidebarVisible: Bool {
        get { defaults.object(forKey: Keys.sidebarVisible) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.sidebarVisible) }
    }

    // MARK: - 窗口尺寸

    /// 保存的窗口尺寸
    public var savedWindowSize: CGSize? {
        get {
            let w = defaults.double(forKey: Keys.windowWidth)
            let h = defaults.double(forKey: Keys.windowHeight)
            guard w > 0 && h > 0 else { return nil }
            return CGSize(width: w, height: h)
        }
        set {
            if let size = newValue {
                defaults.set(size.width, forKey: Keys.windowWidth)
                defaults.set(size.height, forKey: Keys.windowHeight)
            }
        }
    }

    /// 保存的窗口位置
    public var savedWindowOrigin: CGPoint? {
        get {
            let x = defaults.double(forKey: Keys.windowX)
            let y = defaults.double(forKey: Keys.windowY)
            guard x != 0 || y != 0 else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            if let origin = newValue {
                defaults.set(origin.x, forKey: Keys.windowX)
                defaults.set(origin.y, forKey: Keys.windowY)
            }
        }
    }

    /// 最近打开文件路径
    public var lastOpenedFilePath: String? {
        get { defaults.string(forKey: Keys.lastOpenedFilePath) }
        set { defaults.set(newValue, forKey: Keys.lastOpenedFilePath) }
    }

    // MARK: - 偏好设置

    /// 自动恢复上次文档
    public var autoReopenLastDocument: Bool {
        get { defaults.object(forKey: Keys.autoReopenLastDocument) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoReopenLastDocument) }
    }

    /// 默认阅读模式
    public var defaultReadingMode: ReaderViewModel.ReadingMode {
        get {
            guard let raw = defaults.string(forKey: Keys.defaultReadingMode),
                  let mode = ReaderViewModel.ReadingMode(rawValue: raw) else {
                return .normal
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.defaultReadingMode)
        }
    }

    /// 默认显示模式
    public var defaultDisplayMode: ReaderViewModel.DisplayMode {
        get {
            guard let raw = defaults.string(forKey: Keys.defaultDisplayMode),
                  let mode = ReaderViewModel.DisplayMode(rawValue: raw) else {
                return .singleContinuous
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.defaultDisplayMode)
        }
    }

    /// 保存窗口状态
    public func saveWindowState(frame: NSRect) {
        savedWindowOrigin = frame.origin
        savedWindowSize = frame.size
    }

    /// 获取默认窗口尺寸
    public static var defaultWindowSize: NSSize {
        NSSize(width: 900, height: 700)
    }
}