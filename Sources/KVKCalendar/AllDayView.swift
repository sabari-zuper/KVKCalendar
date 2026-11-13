//
//  AllDayView.swift
//  KVKCalendar
//
//  Created by Sergei Kviatkovskii on 20.05.2021.
//

#if os(iOS)

import UIKit

final class AllDayView: UIView {
    
    struct PrepareEvents {
        let events: [Event]
        let date: Date?
        let xOffset: CGFloat
        let width: CGFloat
    }
    
    struct Parameters {
        let date: Date
        let prepareEvents: [PrepareEvents]
        let type: CalendarType
        var style: Style
        weak var delegate: TimelineDelegate?
        var isExpanded: Bool = false
        var didToggleExpand: (() -> Void)?
    }
    
    struct CollapseInfo {
        let totalRows: Int
        let visibleRows: Int
        let hiddenCount: Int
        
        var isCollapsible: Bool {
            hiddenCount > 0
        }
    }
    
    static func collapseInfo(prepareEvents: [PrepareEvents], type: CalendarType, maxRows: Int?) -> CollapseInfo {
        switch type {
        case .day:
            let count = prepareEvents.first?.events.count ?? 0
            let totalRows = Int((CGFloat(count) / 2).rounded(.up))
            guard let maxRows = maxRows.map({ max($0, 1) }), totalRows > maxRows else {
                return CollapseInfo(totalRows: totalRows, visibleRows: totalRows, hiddenCount: 0)
            }
            return CollapseInfo(totalRows: totalRows, visibleRows: maxRows, hiddenCount: count - maxRows * 2)
        default:
            let totalRows = prepareEvents.map { $0.events.count }.max() ?? 0
            guard let maxRows = maxRows.map({ max($0, 1) }), totalRows > maxRows else {
                return CollapseInfo(totalRows: totalRows, visibleRows: totalRows, hiddenCount: 0)
            }
            // a multi-day event is repeated in every column:
            // count it once and only if it isn't visible in any other column
            var visibleIDs = Set<String>()
            var hiddenIDs = Set<String>()
            prepareEvents.forEach { (item) in
                item.events.prefix(maxRows).forEach { visibleIDs.insert($0.ID) }
                item.events.dropFirst(maxRows).forEach { hiddenIDs.insert($0.ID) }
            }
            let hiddenCount = hiddenIDs.subtracting(visibleIDs).count
            // nothing is really hidden, show all rows so no day looks free when it isn't
            guard hiddenCount > 0 else {
                return CollapseInfo(totalRows: totalRows, visibleRows: totalRows, hiddenCount: 0)
            }
            return CollapseInfo(totalRows: totalRows, visibleRows: maxRows, hiddenCount: hiddenCount)
        }
    }
    
    static func moreButtonAreaHeight(info: CollapseInfo, isExpanded: Bool, style: AllDayStyle) -> CGFloat {
        guard info.isCollapsible, !isExpanded || style.lessTitle != nil else { return 0 }
        return style.moreHeight + 8
    }
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.tag = 123
        return label
    }()
    
    private let scrollView = UIScrollView()
    
    private lazy var expandImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 123
        return imageView
    }()
    
    private lazy var expandButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tag = 123
        button.addTarget(self, action: #selector(toggleExpand), for: .touchUpInside)
        return button
    }()
    
    private lazy var moreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tag = 123
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        button.addTarget(self, action: #selector(toggleExpand), for: .touchUpInside)
        return button
    }()
    private let linePoints: [CGPoint]
    private var params: Parameters
    private weak var dataSource: DisplayDataSource?

    let items: [[AllDayEvent]]
    private let collapseInfo: CollapseInfo
    
    init(parameters: Parameters, frame: CGRect, dataSource: DisplayDataSource?) {
        self.params = parameters
        self.items = parameters.prepareEvents.compactMap { item -> [AllDayEvent] in
            item.events.compactMap { AllDayEvent(date: $0.start, event: $0, xOffset: item.xOffset, width: item.width) }
        }
        self.linePoints = parameters.prepareEvents.compactMap({ CGPoint(x: $0.xOffset, y: 0) })
        self.dataSource = dataSource
        self.collapseInfo = AllDayView.collapseInfo(prepareEvents: parameters.prepareEvents,
                                                    type: parameters.type,
                                                    maxRows: parameters.style.allDay.maxCollapsedRows)
        super.init(frame: frame)
        scrollView.tag = 123
        scrollView.contentInsetAdjustmentBehavior = .never
        setUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func calculateFrame(index: Int, countEvents: Int, width: CGFloat, height: CGFloat) -> CGRect {
        var newSize: CGSize
        var newPoint: CGPoint
        let newY = height * CGFloat(index / 2)
        let newWidth = width * 0.5
        
        if countEvents == (index + 1) {
            newSize = CGSize(width: index % 2 == 0 ? width : newWidth, height: height)
            newPoint = CGPoint(x: index % 2 == 0 ? 0 : newWidth, y: newY)
        } else if index % 2 == 0 {
            newSize = CGSize(width: newWidth, height: height)
            newPoint = CGPoint(x: 0, y: newY)
        } else {
            newSize = CGSize(width: newWidth, height: height)
            newPoint = CGPoint(x: newWidth, y: newY)
        }
        
        newSize.width -= params.style.allDay.offsetWidth
        newSize.height -= params.style.allDay.offsetHeight
        newPoint.y += 1
        
        return CGRect(origin: newPoint, size: newSize)
    }
    
    private var isCollapsed: Bool {
        collapseInfo.isCollapsible && !params.isExpanded
    }
    
    @objc private func toggleExpand() {
        params.didToggleExpand?()
    }
    
    /// Puts the toggle controls into their previous state before the expand/collapse animation.
    func prepareToggleAnimation() {
        clipsToBounds = true
        expandImageView.transform = CGAffineTransform(rotationAngle: .pi)
        moreButton.alpha = 0
    }
    
    /// Animatable part of the expand/collapse animation (call inside an animation block).
    func performToggleAnimation() {
        expandImageView.transform = .identity
        moreButton.alpha = 1
    }
    
    func finishToggleAnimation() {
        clipsToBounds = false
    }
    
    private func setupView() {
        backgroundColor = params.style.allDay.backgroundColor
        subviews.filter { $0.tag == 123 }.forEach { $0.removeFromSuperview() }
        
        titleLabel.frame = CGRect(x: params.style.allDay.offsetX, y: 0,
                                  width: leftOffsetWithAdditionalTime - params.style.allDay.offsetX,
                                  height: params.style.allDay.height)
        titleLabel.font = params.style.allDay.fontTitle
        titleLabel.textColor = params.style.allDay.titleColor
        titleLabel.textAlignment = params.style.allDay.titleAlignment
        titleLabel.text = params.style.allDay.titleText
                
        let x = titleLabel.frame.width + titleLabel.frame.origin.x
        let moreAreaHeight = AllDayView.moreButtonAreaHeight(info: collapseInfo,
                                                             isExpanded: params.isExpanded,
                                                             style: params.style.allDay)
        let scrollFrame = CGRect(origin: CGPoint(x: x, y: 0),
                                 size: CGSize(width: bounds.size.width - x, height: bounds.size.height - moreAreaHeight))
        
        let maxItems: CGFloat
        if isCollapsed {
            maxItems = CGFloat(params.type == .day ? collapseInfo.visibleRows * 2 : collapseInfo.visibleRows)
        } else {
            maxItems = CGFloat(items.max(by: { $0.count < $1.count })?.count ?? 0)
        }
        scrollView.frame = scrollFrame
        scrollView.isScrollEnabled = !isCollapsed
        
        switch params.type {
        case .day:
            scrollView.contentSize = CGSize(width: scrollFrame.width,
                                            height: (maxItems / 2).rounded(.up) * params.style.allDay.height)
        case .week:
            scrollView.contentSize = CGSize(width: scrollFrame.width,
                                            height: maxItems * params.style.allDay.height)
        default:
            break
        }
        
        if let customHeaderCornerView = dataSource?.dequeueAllDayCornerHeader(date: params.date,
                                                                              frame: CGRect(origin: frame.origin, size: CGSize(width: titleLabel.frame.width, height: frame.height))) {
            customHeaderCornerView.tag = 123
            addSubview(customHeaderCornerView)
        } else {
            addSubview(titleLabel)
            
            if collapseInfo.isCollapsible {
                let iconSize: CGFloat = 12
                expandImageView.image = (params.isExpanded ? params.style.allDay.collapseIcon : params.style.allDay.expandIcon)?
                    .withRenderingMode(.alwaysTemplate)
                expandImageView.tintColor = params.style.allDay.expandIconColor
                expandImageView.frame = CGRect(x: titleLabel.frame.midX - iconSize * 0.5,
                                               y: titleLabel.frame.maxY,
                                               width: iconSize, height: iconSize)
                addSubview(expandImageView)
                
                expandButton.frame = CGRect(x: 0, y: 0, width: x, height: bounds.height)
                expandButton.accessibilityLabel = params.isExpanded ? params.style.allDay.lessTitle : moreTitle
                addSubview(expandButton)
            }
        }
        addSubview(scrollView)
        
        if moreAreaHeight > 0 {
            let style = params.style.allDay
            let title = params.isExpanded ? (style.lessTitle ?? "") : moreTitle
            moreButton.setTitle(title, for: .normal)
            moreButton.setTitleColor(style.moreTextColor, for: .normal)
            moreButton.titleLabel?.font = style.moreFont
            moreButton.backgroundColor = style.moreBackgroundColor
            moreButton.layer.borderColor = style.moreBorderColor.cgColor
            moreButton.layer.borderWidth = 1
            moreButton.layer.cornerRadius = style.moreHeight * 0.5
            moreButton.sizeToFit()
            moreButton.frame = CGRect(x: scrollFrame.origin.x + 2,
                                      y: scrollFrame.maxY + (moreAreaHeight - style.moreHeight) * 0.5,
                                      width: min(moreButton.frame.width, scrollFrame.width - 4),
                                      height: style.moreHeight)
            addSubview(moreButton)
        }
    }
    
    private var moreTitle: String {
        String(format: params.style.allDay.moreTitleFormat, collapseInfo.hiddenCount)
    }
    
    private func createEventViews() {
        switch params.type {
        case .day:
            if let allItems = items.first {
                let item = isCollapsed ? Array(allItems.prefix(collapseInfo.visibleRows * 2)) : allItems
                item.enumerated().forEach { (event) in
                    let frameEvent = calculateFrame(index: event.offset,
                                                    countEvents: item.count,
                                                    width: scrollView.bounds.width,
                                                    height: params.style.allDay.height)
                    let eventView = createEventView(event: event.element.event, frame: frameEvent)
                    scrollView.addSubview(eventView)
                }
            }
        case .week:
            items.enumerated().forEach { item in
                let events = isCollapsed ? Array(item.element.prefix(collapseInfo.visibleRows)) : item.element
                events.enumerated().forEach { (event) in
                    let x = item.offset == 0 ? 0 : event.element.xOffset
                    let frameEvent = CGRect(origin: CGPoint(x: x, y: params.style.allDay.height * CGFloat(event.offset)),
                                            size: CGSize(width: event.element.width - params.style.allDay.offsetWidth,
                                                         height: params.style.allDay.height - params.style.allDay.offsetHeight))
                    let eventView = createEventView(event: event.element.event, frame: frameEvent)
                    scrollView.addSubview(eventView)
                }
            }
            
            if params.style.allDay.isPinned {
                linePoints.enumerated().forEach { (point) in
                    let x = point.offset == 0 ? scrollView.frame.origin.x : (point.element.x + scrollView.frame.origin.x)
                    let line = createVerticalLine(pointX: x)
                    addSubview(line)
                }
            }
        default:
            break
        }
    }
    
    private func createEventView(event: Event, frame: CGRect) -> UIView {
        if let customView = dataSource?.dequeueAllDayViewEvent(event, date: event.start, frame: frame) {
            return customView
        } else {
            let eventView = AllDayEventView(style: params.style.allDay, event: event, frame: frame)
            eventView.delegate = self
            return eventView
        }
    }
    
    private func createVerticalLine(pointX: CGFloat) -> VerticalLineView {
        let frame = CGRect(x: pointX, y: 0, width: params.style.timeline.widthLine, height: scrollView.frame.height)
        let line = VerticalLineView(frame: frame)
        line.backgroundColor = params.style.timeline.separatorLineColor
        line.isHidden = !params.style.week.showVerticalDayDivider
        return line
    }
}

extension AllDayView: AllDayEventDelegate {
    
    func didSelectAllDayEvent(_ event: Event, frame: CGRect?) {
        params.delegate?.didSelectEvent(event, frame: frame)
    }
    
}

extension AllDayView: CalendarSettingProtocol {
    
    var style: Style {
        get {
            params.style
        }
        set {
            params.style = newValue
        }
    }
    
    func reloadFrame(_ frame: CGRect) {
        
    }
    
    func updateStyle(_ style: Style, force: Bool) {
        self.style = style
        setUI(reload: force)
    }
    
    func setUI(reload: Bool = false) {
        setupView()
        createEventViews()
    }
    
}

#endif
