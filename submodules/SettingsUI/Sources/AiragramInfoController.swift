import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import AuthorizationUtils

private let airagramColorBlue = UIColor(rgb: 0x0079ff)
private let airagramColorGreen = UIColor(rgb: 0x34C759)
private let airagramColorPink = UIColor(rgb: 0xFF2D55)
private let airagramColorPurple = UIColor(rgb: 0xAF52DE)
private let airagramColorGray = UIColor(rgb: 0x8E8E93)

private let airagramTitleFont = Font.bold(20.0)
private let airagramVersionFont = Font.regular(13.0)
private let airagramSectionHeaderFont = Font.regular(13.0)
private let airagramRowFont = Font.regular(17.0)

private func airagramString(_ ru: String, _ en: String, languageCode: String) -> String {
    return languageCode.hasPrefix("ru") ? ru : en
}

private struct AiragramFunctionRow {
    let icon: String
    let color: UIColor
    let titleRu: String
    let titleEn: String
}

private let airagramFunctionRows: [AiragramFunctionRow] = [
    AiragramFunctionRow(icon: "Item List/Icons/AiragramProfile", color: airagramColorBlue, titleRu: "Профиль", titleEn: "Profile"),
    AiragramFunctionRow(icon: "Item List/Icons/AiragramMessages", color: airagramColorGreen, titleRu: "Сообщения", titleEn: "Messages"),
    AiragramFunctionRow(icon: "Item List/Icons/AiragramGifts", color: airagramColorPink, titleRu: "Подарки", titleEn: "Gifts"),
    AiragramFunctionRow(icon: "Item List/Icons/AiragramAppearance", color: airagramColorPurple, titleRu: "Внешний вид", titleEn: "Appearance"),
    AiragramFunctionRow(icon: "Item List/Icons/AiragramSettings", color: airagramColorGray, titleRu: "Настройки", titleEn: "Settings"),
]

private final class AiragramFunctionRowNode: ASDisplayNode {
    private let row: AiragramFunctionRow
    private let iconNode: ASImageNode
    private let titleNode: ASTextNode
    private let arrowNode: ASImageNode
    private let separatorNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode

    private var normalBackgroundColor: UIColor = .clear
    private var highlightedBackgroundColor: UIColor = .clear

    init(row: AiragramFunctionRow) {
        self.row = row

        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false

        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false

        self.separatorNode = ASDisplayNode()
        self.buttonNode = HighlightTrackingButtonNode()

        super.init()

        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.buttonNode)

        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.backgroundColor = strongSelf.highlightedBackgroundColor
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    strongSelf.backgroundColor = strongSelf.normalBackgroundColor
                })
            }
        }
    }

    func update(width: CGFloat, presentationData: PresentationData, isLast: Bool) -> CGFloat {
        let theme = presentationData.theme
        self.normalBackgroundColor = theme.list.itemBlocksBackgroundColor
        self.highlightedBackgroundColor = theme.list.itemHighlightedBackgroundColor
        self.backgroundColor = self.normalBackgroundColor

        let height: CGFloat = 50.0
        let leftInset: CGFloat = 16.0
        let iconSize = CGSize(width: 29.0, height: 29.0)

        self.iconNode.image = renderSettingsIcon(name: self.row.icon, backgroundColors: [self.row.color])
        self.iconNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - iconSize.height) / 2.0)), size: iconSize)

        let title = airagramString(self.row.titleRu, self.row.titleEn, languageCode: presentationData.strings.baseLanguageCode)
        self.titleNode.attributedText = NSAttributedString(string: title, font: airagramRowFont, textColor: theme.list.itemPrimaryTextColor)
        let titleMaxWidth = width - leftInset - iconSize.width - 16.0 - leftInset - 24.0
        let titleSize = self.titleNode.measure(CGSize(width: max(0.0, titleMaxWidth), height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + iconSize.width + 16.0, y: floor((height - titleSize.height) / 2.0)), size: titleSize)

        self.arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(theme)
        if let arrowSize = self.arrowNode.image?.size {
            self.arrowNode.frame = CGRect(origin: CGPoint(x: width - leftInset - arrowSize.width, y: floor((height - arrowSize.height) / 2.0)), size: arrowSize)
        }

        let separatorX = leftInset + iconSize.width + 16.0
        self.separatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        self.separatorNode.frame = CGRect(origin: CGPoint(x: separatorX, y: height - UIScreenPixel), size: CGSize(width: max(0.0, width - separatorX - leftInset), height: UIScreenPixel))
        self.separatorNode.isHidden = isLast

        self.buttonNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))

        return height
    }
}

final class AiragramInfoControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData

    private let iconNode: ASImageNode
    private let titleNode: ASTextNode
    private let versionLineNode: ASDisplayNode
    private let versionNode: ASTextNode
    private let buildNode: ASTextNode
    private let sectionHeaderNode: ASTextNode
    private let sectionBackgroundNode: ASDisplayNode
    private var rowNodes: [AiragramFunctionRowNode] = []

    private var validLayout: (ContainerViewLayout, CGFloat)?

    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData

        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = UIImage(bundleImageName: "Item List/Icons/AiragramHero")

        self.titleNode = ASTextNode()
        self.versionLineNode = ASDisplayNode()
        self.versionNode = ASTextNode()
        self.buildNode = ASTextNode()

        self.sectionHeaderNode = ASTextNode()
        self.sectionBackgroundNode = ASDisplayNode()

        self.rowNodes = airagramFunctionRows.map { AiragramFunctionRowNode(row: $0) }

        super.init()

        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.versionLineNode.addSubnode(self.versionNode)
        self.versionLineNode.addSubnode(self.buildNode)
        self.addSubnode(self.versionLineNode)
        self.addSubnode(self.sectionHeaderNode)
        self.addSubnode(self.sectionBackgroundNode)
        for rowNode in self.rowNodes {
            self.addSubnode(rowNode)
        }

        self.updatePresentationData(presentationData)
    }

    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        let theme = presentationData.theme

        self.backgroundColor = theme.list.blocksBackgroundColor
        self.sectionBackgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor

        self.titleNode.attributedText = NSAttributedString(string: "AiraGram", font: airagramTitleFont, textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)

        let baseVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "12.9.2"
        self.versionNode.attributedText = NSAttributedString(string: "v1.0.0", font: airagramVersionFont, textColor: theme.list.freeTextColor)
        self.buildNode.attributedText = NSAttributedString(string: "Telegram \(baseVersion) (1)", font: airagramVersionFont, textColor: theme.list.freeTextColor)

        let sectionHeaderText = airagramString("ФУНКЦИИ", "FUNCTIONS", languageCode: presentationData.strings.baseLanguageCode)
        self.sectionHeaderNode.attributedText = NSAttributedString(string: sectionHeaderText, font: airagramSectionHeaderFont, textColor: theme.list.freeTextColor)

        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)

        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight

        let sideInset: CGFloat = 16.0
        let contentWidth = layout.size.width - sideInset * 2.0

        var contentY: CGFloat = insets.top + 28.0

        let iconSize = CGSize(width: 72.0, height: 72.0)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentY), size: iconSize))
        contentY += iconSize.height + 16.0

        let titleSize = self.titleNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: contentY), size: titleSize))
        contentY += titleSize.height + 8.0

        let versionSize = self.versionNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        let buildSize = self.buildNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        let versionLineHeight = max(versionSize.height, buildSize.height)
        self.versionNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((versionLineHeight - versionSize.height) / 2.0)), size: versionSize)
        self.buildNode.frame = CGRect(origin: CGPoint(x: contentWidth - buildSize.width, y: floor((versionLineHeight - buildSize.height) / 2.0)), size: buildSize)
        transition.updateFrame(node: self.versionLineNode, frame: CGRect(origin: CGPoint(x: sideInset, y: contentY), size: CGSize(width: contentWidth, height: versionLineHeight)))
        contentY += versionLineHeight + 32.0

        let sectionHeaderSize = self.sectionHeaderNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.sectionHeaderNode, frame: CGRect(origin: CGPoint(x: sideInset, y: contentY), size: sectionHeaderSize))
        contentY += sectionHeaderSize.height + 7.0

        let sectionTop = contentY
        var rowY: CGFloat = 0.0
        for (index, rowNode) in self.rowNodes.enumerated() {
            let rowHeight = rowNode.update(width: layout.size.width, presentationData: self.presentationData, isLast: index == self.rowNodes.count - 1)
            transition.updateFrame(node: rowNode, frame: CGRect(origin: CGPoint(x: 0.0, y: sectionTop + rowY), size: CGSize(width: layout.size.width, height: rowHeight)))
            rowY += rowHeight
        }
        transition.updateFrame(node: self.sectionBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: sectionTop), size: CGSize(width: layout.size.width, height: rowY)))
    }
}

public final class AiragramInfoController: ViewController {
    private let context: AccountContext

    private var controllerNode: AiragramInfoControllerNode {
        return self.displayNode as! AiragramInfoControllerNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData, style: .glass))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = "AiraGram"
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self else {
                return
            }
            let previousTheme = strongSelf.presentationData.theme
            let previousStrings = strongSelf.presentationData.strings

            strongSelf.presentationData = presentationData

            if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                strongSelf.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: presentationData, style: .glass), transition: .immediate)
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = AiragramInfoControllerNode(context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

public func airagramInfoController(context: AccountContext) -> ViewController {
    return AiragramInfoController(context: context)
}
