//MIT License
//
//Copyright (c) 2020 Gwan-ho Kim <pikachu77769@gmail.com>
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

import UIKit
import AVKit

// MARK: VideoTrimDelegate
public protocol VideoTrimDelegate: AnyObject {
    func videoTrimStartTrimChange(_ videoTrim: VideoTrim)
    func videoTrimEndTrimChange(_ videoTrim: VideoTrim)
    func videoTrimPlayTimeChange(_ videoTrim: VideoTrim)
}

public extension VideoTrimDelegate {
    func videoTrimStartTrimChange(_ videoTrim: VideoTrim) {}
    func videoTrimEndTrimChange(_ videoTrim: VideoTrim) {}
    func videoTrimPlayTimeChange(_ videoTrim: VideoTrim) {}
}

// MARK: VideoFrameView
open class VideoTrim: UIView {
    public weak var delegate: VideoTrimDelegate?

    // Number of Frame View Images
    public var frameImageCount = 20 {
        didSet {
            remakeFrameImages(count: frameImageCount)
        }
    }

    // Trim minimum length
    public var trimRemainWidth: CGFloat = 50

    // Trim Maximum Duration
    public var trimMaximumDuration: CMTime = .zero

    public var topMargin: CGFloat = 0 {
        didSet {
            constraints.filter({ $0.identifier == "stackViewTop" }).first?.constant = topMargin
        }
    }

    public var bottomMargin: CGFloat = 0 {
        didSet {
            constraints.filter({ $0.identifier == "stackViewBottom" }).first?.constant = -bottomMargin - playLineVerticalSize
        }
    }

    public var leadingMargin: CGFloat = 14 {
        didSet {
            let constant = leadingMargin + trimLineWidth
            constraints.filter({ $0.identifier == "stackViewLeading" }).first?.constant = constant
        }
    }

    public var trailingMargin: CGFloat = 14 {
        didSet {
            let constant = trailingMargin + trimLineWidth
            constraints.filter({ $0.identifier == "stackViewTrailing" }).first?.constant = -constant
        }
    }

    public var frameHeight: CGFloat = 48 {
        didSet {
            frameContainerView.constraints.filter({ $0.identifier == "frameContainerViewHeight" }).first?.constant = frameHeight
        }
    }

    public var trimMaskDimViewColor: UIColor = UIColor(white: 0/255, alpha: 0.7) {
        didSet {
            trimStartTimeDimView.backgroundColor = trimMaskDimViewColor
            trimEndTimeDimView.backgroundColor = trimMaskDimViewColor
        }
    }

    public var trimLineRadius: CGFloat = 4 {
        didSet {
            trimLineView.layer.cornerRadius = trimLineRadius
        }
    }

    public var trimLineWidth: CGFloat = 4 {
        didSet {
            trimLineView.layer.borderWidth = trimLineWidth
            frameContainerView.constraints.filter({ $0.identifier == "frameViewTop" }).first?.constant = trimLineWidth
            frameContainerView.constraints.filter({ $0.identifier == "frameViewBottom" }).first?.constant = -trimLineWidth
            frameContainerView.constraints.filter({ $0.identifier == "trimLineViewLeading" }).first?.constant = -trimLineWidth
            frameContainerView.constraints.filter({ $0.identifier == "trimLineViewTrailing" }).first?.constant = trimLineWidth

            let leadingMargin = self.leadingMargin
            self.leadingMargin = leadingMargin

            let trailingMargin = self.trailingMargin
            self.trailingMargin = trailingMargin
        }
    }

    public var playLineRadius: CGFloat = 3 {
        didSet {
            playTimeLineView.layer.cornerRadius = playLineRadius
        }
    }

    public var playLineWidth: CGFloat = 6 {
        didSet {
            playTimeLineView.constraints.filter({ $0.identifier == "playTimeLineViewWidth" }).first?.constant = playLineWidth
        }
    }

    public var playLineVerticalSize: CGFloat = 4 {
        didSet {
            frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewTop" }).first?.constant = -playLineVerticalSize
            frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewBottom" }).first?.constant = playLineVerticalSize
            let bottomMargin = self.bottomMargin
            self.bottomMargin = bottomMargin
        }
    }

    public var trimLineViewColor: CGColor = UIColor.white.cgColor {
        didSet {
            trimLineView.layer.borderColor = trimLineViewColor
        }
    }

    public var playTimeLineViewColor: UIColor = UIColor.white {
        didSet {
            playTimeLineView.backgroundColor = playTimeLineViewColor
        }
    }

    public var isHiddenTime: Bool = false {
        didSet {
            if isHiddenTime {
                timeContainerView.isHidden = true
            }
        }
    }

    public var timeColor: UIColor = UIColor.white {
        didSet {
            timeLabel.textColor = timeColor
            totalTimeLabel.textColor = timeColor
        }
    }

    public var timeFont: UIFont = UIFont.systemFont(ofSize: 15) {
        didSet {
            timeLabel.font = timeFont
            totalTimeLabel.font = timeFont
        }
    }

    public var playTime: CMTime {
        guard let asset = asset,
            let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first,
            let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first else { return .zero }
        let playTimeWidth = playTimeLineViewLeadingConstraint.constant - leadingConstraint.constant
        let duration = asset.duration
        let value = CGFloat(duration.value)
        let playTime = value * playTimeWidth / frameWidth
        return CMTime(value: CMTimeValue(playTime), timescale: duration.timescale)
    }

    public var startTime: CMTime {
        set {
            guard let asset = asset else { return }
            let constant = ((CGFloat(newValue.value) * CGFloat(newValue.timescale)) / (CGFloat(asset.duration.value) * CGFloat(asset.duration.timescale))) * frameWidth
            frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first?.constant = constant
            updateTotalTime()
            if let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first {
                if constant > playTimeLineViewLeadingConstraint.constant {
                    playTimeLineViewLeadingConstraint.constant = constant
                    updatePlayTime()
                }
            }
        }
        get {
            guard let asset = asset,
                let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first else { return .zero }
            let startTimeWidth = leadingConstraint.constant
            let duration = asset.duration
            let value = CGFloat(duration.value)
            let startTime = value * startTimeWidth / frameWidth
            return CMTime(value: CMTimeValue(startTime), timescale: duration.timescale)
        }
    }

    public var endTime: CMTime {
        set {
            let value = (CGFloat(newValue.value) * CGFloat(newValue.timescale)) - (CGFloat(startTime.value) * CGFloat(startTime.timescale))
            durationTime = CMTime(value: CMTimeValue(value / CGFloat(newValue.timescale)), timescale: newValue.timescale)
        }
        get {
            CMTime(value: CMTimeValue(CGFloat(startTime.value) + CGFloat(durationTime.value)), timescale: startTime.timescale)
        }
    }

    public var durationTime: CMTime {
        set {
            guard let asset = asset,
            let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first else { return }
            let constant = ((CGFloat(newValue.value) * CGFloat(newValue.timescale)) / (CGFloat(asset.duration.value) * CGFloat(asset.duration.timescale))) * frameWidth
            let remainWidth = frameWidth - abs(leadingConstraint.constant) - abs(constant)
            frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first?.constant = -remainWidth
            updateTotalTime()
        }
        get {
            guard let asset = asset,
                let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first,
                let trailingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first else { return .zero }
            let remainWidth = frameWidth - abs(leadingConstraint.constant) - abs(trailingConstraint.constant)
            let duration = asset.duration
            let value = CGFloat(duration.value)
            let endTime = value * remainWidth / frameWidth
            return CMTime(value: CMTimeValue(endTime), timescale: duration.timescale)
        }
    }

    public var canTrimTime: Bool = true {
        didSet {
            trimStartTimeView.gestureRecognizers?.first { $0 is UIPanGestureRecognizer }?.isEnabled = canTrimTime
            trimEndTimeView.gestureRecognizers?.first { $0 is UIPanGestureRecognizer }?.isEnabled = canTrimTime
        }
    }

    public var currentImage: UIImage? {
        if asset != nil {
            return imageTo(time: playTime)
        } else {
            guard let playTimeX = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first?.constant else { return nil }
            return frameView.subviews
                .compactMap { $0 as? UIImageView }
                .sorted(by: { $0.frame.origin.x < $1.frame.origin.x })
                .first(where: { $0.frame.contains(.init(x: playTimeX, y: $0.frame.origin.y)) })?
                .image
        }
    }

    // asset
    open var asset: AVAsset? {
        didSet {
            updateLayout()
            if let asset = asset, asset.duration.value != 0 {
                if !isHiddenTime {
                    timeContainerView.isHidden = false
                }
                frameContainerView.isHidden = false
                trimStartTimeDimView.isHidden = false
                trimEndTimeDimView.isHidden = false
            } else {
                timeContainerView.isHidden = true
                frameContainerView.isHidden = true
                trimStartTimeDimView.isHidden = true
                trimEndTimeDimView.isHidden = true
            }
            if frameImages.count != frameImageCount {
                remakeFrameImages(count: frameImageCount)
            }

            frameImages.forEach { (imageView) in
                imageView.image = nil
                imageView.showVisualEffect()
            }
            if let asset = asset {
                let duration = asset.duration
                let timescale = duration.timescale
                let timescaleValue = CGFloat(timescale)
                let totalTime = Int(ceil(CMTimeGetSeconds(duration)))

                DispatchQueue.global().async {
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true

                    var extractionImages = [UIImage?]()
                    for index in 0..<self.frameImageCount {
                        let timeValue = (CGFloat(totalTime) * (CGFloat(index) / CGFloat(self.frameImageCount))) * timescaleValue
                        let time = CMTime(value: CMTimeValue(timeValue), timescale: timescale)
                        if let imageRef = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
                            let image = UIImage(cgImage: imageRef)
                            if index == 0 {
                                DispatchQueue.main.async {
                                    if self.asset == asset {
                                        self.frameImages.forEach({ $0.image = image })
                                    }
                                }
                            }
                            extractionImages.append(image)
                        }
                    }
                    DispatchQueue.main.async {
                        if self.asset == asset {
                            for (index, imageView) in self.frameImages.enumerated() {
                                if extractionImages.count > index {
                                    imageView.image = extractionImages[index]
                                }
                                imageView.hideVisualEffect()
                            }
                        }
                    }
                }
                timeLabel.text = 0.time
                totalTimeLabel.text = totalTime.time
            }
            frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first?.constant = 0
            if trimMaximumDuration == .zero {
                frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first?.constant = 0
            } else {
                let duration = CGFloat(durationTime.value) / CGFloat(durationTime.timescale)
                let maximumDuration = CGFloat(trimMaximumDuration.value) / CGFloat(trimMaximumDuration.timescale)
                if duration > maximumDuration {
                    durationTime = trimMaximumDuration
                }
            }
            frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first?.constant = 0
        }
    }

    open var images: [UIImage]? {
        set {
            asset = nil
            timeContainerView.isHidden = true
            guard let images = newValue else {
                frameContainerView.isHidden = true
                trimStartTimeDimView.isHidden = true
                trimEndTimeDimView.isHidden = true
                return
            }
            frameContainerView.isHidden = false
            trimStartTimeDimView.isHidden = false
            trimEndTimeDimView.isHidden = false
            remakeFrameImages(count: images.count)

            frameImages.forEach { (imageView) in
                imageView.image = nil
                imageView.showVisualEffect()
            }

            for (index, imageView) in frameImages.enumerated() {
                if images.count > index {
                    imageView.image = images[index]
                }
                imageView.hideVisualEffect()
            }

            frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first?.constant = 0
            frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first?.constant = 0
            frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first?.constant = 0
        }
        get {
            frameView.subviews.compactMap { $0 as? UIImageView }.compactMap { $0.image }
        }
    }

    // current time
    open var currentTime: CMTime? {
        didSet {
            guard let asset = asset,
                let current = currentTime,
                let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first,
                let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first,
                let trailingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first else { return }
            let totalTime = CGFloat(asset.duration.value) / CGFloat(asset.duration.timescale)
            let currentTime = CGFloat(current.value) / CGFloat(current.timescale)
            let percentage = currentTime / totalTime
            var leading = frameWidth * percentage
            if leading <= leadingConstraint.constant {
                leading = leadingConstraint.constant
            }
            if leading >= frameWidth - abs(trailingConstraint.constant) - playLineWidth {
                leading = frameWidth - abs(trailingConstraint.constant) - playLineWidth
            }
            playTimeLineViewLeadingConstraint.constant = leading
            updatePlayTime()
        }
    }

    private lazy var stackView: UIStackView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.spacing = 6
        $0.axis = .vertical
        $0.distribution = .fillProportionally
        return $0
    }(UIStackView(arrangedSubviews: [timeContainerView, frameContainerView]))

    private let timeContainerView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let timeLabel: UILabel = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.text = "0:00"
        return $0
    }(UILabel())

    private let totalTimeLabel: UILabel = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.text = "0:00"
        return $0
    }(UILabel())

    private let frameContainerView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let frameView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private lazy var frameImages: [VisualEffectImageView] = []

    private let trimLineContainerView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimLineView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimStartTimeLineView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimEndTimeLineView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimStartTimeView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimEndTimeView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimStartTimeDimView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let trimEndTimeDimView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let playTimeLineView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private let playTimeContainerView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .clear
        return $0
    }(UIView())

    private var frameWidth: CGFloat {
        if frameContainerView.bounds.width == 0 {
            return 1
        } else {
            return frameContainerView.bounds.width
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = true
        clipsToBounds = true
        backgroundColor = .black

        timeContainerView.isHidden = true
        frameContainerView.isHidden = true
        trimStartTimeDimView.isHidden = true
        trimEndTimeDimView.isHidden = true

        addSubview(stackView)
        timeContainerView.addSubview(timeLabel)
        timeContainerView.addSubview(totalTimeLabel)
        frameContainerView.addSubview(frameView)
        frameContainerView.addSubview(trimStartTimeDimView)
        frameContainerView.addSubview(trimEndTimeDimView)
        frameContainerView.addSubview(trimLineContainerView)
        frameContainerView.addSubview(trimLineView)
        frameContainerView.addSubview(trimStartTimeLineView)
        frameContainerView.addSubview(trimEndTimeLineView)
        frameContainerView.addSubview(trimStartTimeView)
        frameContainerView.addSubview(trimEndTimeView)
        frameContainerView.addSubview(playTimeLineView)
        frameContainerView.addSubview(playTimeContainerView)

        // StackView
        let stackViewTopConstraint = NSLayoutConstraint(item: stackView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 10)
        stackViewTopConstraint.identifier = "stackViewTop"

        let stackViewLeadingConstraint = NSLayoutConstraint(item: stackView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 20)
        stackViewLeadingConstraint.identifier = "stackViewLeading"

        let stackViewTrailingConstraint = NSLayoutConstraint(item: stackView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: -20)
        stackViewTrailingConstraint.identifier = "stackViewTrailing"

        let stackViewBottomConstraint = NSLayoutConstraint(item: stackView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: -16)
        stackViewBottomConstraint.identifier = "stackViewBottom"

        addConstraints([
            stackViewTopConstraint,
            stackViewLeadingConstraint,
            stackViewTrailingConstraint,
            stackViewBottomConstraint
        ])

        // timeLabel
        timeContainerView.addConstraints([
            NSLayoutConstraint(item: timeLabel, attribute: .top, relatedBy: .equal, toItem: timeContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: timeLabel, attribute: .bottom, relatedBy: .equal, toItem: timeContainerView, attribute: .bottom, multiplier: 1, constant: 0),
        ])

        // totalTimeLabel
        timeContainerView.addConstraints([
            NSLayoutConstraint(item: totalTimeLabel, attribute: .top, relatedBy: .equal, toItem: timeContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: totalTimeLabel, attribute: .bottom, relatedBy: .equal, toItem: timeContainerView, attribute: .bottom, multiplier: 1, constant: 0),
        ])

        let totalTimeLabelTrailingConstraint = NSLayoutConstraint(item: totalTimeLabel, attribute: .centerX, relatedBy: .equal, toItem: trimEndTimeLineView, attribute: .centerX, multiplier: 1, constant: 0)
        totalTimeLabelTrailingConstraint.priority = UILayoutPriority(rawValue: 960)

        stackView.addConstraints([
            NSLayoutConstraint(item: timeLabel, attribute: .centerX, relatedBy: .equal, toItem: trimStartTimeLineView, attribute: .centerX, multiplier: 1, constant: 0),
            totalTimeLabelTrailingConstraint
        ])

        // frameContainerView
        let frameContainerViewHeightConstraint = NSLayoutConstraint(item: frameContainerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 48)
        frameContainerViewHeightConstraint.identifier = "frameContainerViewHeight"
        frameContainerView.addConstraints([
            frameContainerViewHeightConstraint
        ])

        // frameView
        let frameViewTopConstraint = NSLayoutConstraint(item: frameView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: 0)
        frameViewTopConstraint.identifier = "frameViewTop"
        let frameViewBottomConstraint = NSLayoutConstraint(item: frameView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 0)
        frameViewBottomConstraint.identifier = "frameViewBottom"
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: frameView, attribute: .leading, relatedBy: .equal, toItem: frameContainerView, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: frameView, attribute: .trailing, relatedBy: .equal, toItem: frameContainerView, attribute: .trailing, multiplier: 1, constant: 0),
            frameViewTopConstraint,
            frameViewBottomConstraint
        ])

        // trimLineContainerView
        let trimContainerViewLeadingConstraint = NSLayoutConstraint(item: trimLineContainerView, attribute: .leading, relatedBy: .equal, toItem: frameContainerView, attribute: .leading, multiplier: 1, constant: 0)
        trimContainerViewLeadingConstraint.identifier = "trimContainerViewLeading"
        let trimContainerViewTrailingConstraint = NSLayoutConstraint(item: trimLineContainerView, attribute: .trailing, relatedBy: .equal, toItem: frameContainerView, attribute: .trailing, multiplier: 1, constant: 0)
        trimContainerViewTrailingConstraint.identifier = "trimContainerViewTrailing"
        frameContainerView.addConstraints([
            trimContainerViewLeadingConstraint,
            trimContainerViewTrailingConstraint,
            NSLayoutConstraint(item: trimLineContainerView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimLineContainerView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 0)
        ])

        // trimLineView
        let trimLineViewLeadingConstraint = NSLayoutConstraint(item: trimLineView, attribute: .leading, relatedBy: .equal, toItem: trimLineContainerView, attribute: .leading, multiplier: 1, constant: 0)
        trimLineViewLeadingConstraint.identifier = "trimLineViewLeading"
        let trimLineViewTrailingConstraint = NSLayoutConstraint(item: trimLineView, attribute: .trailing, relatedBy: .equal, toItem: trimLineContainerView, attribute: .trailing, multiplier: 1, constant: 0)
        trimLineViewTrailingConstraint.identifier = "trimLineViewTrailing"
        frameContainerView.addConstraints([
            trimLineViewLeadingConstraint,
            trimLineViewTrailingConstraint,
            NSLayoutConstraint(item: trimLineView, attribute: .top, relatedBy: .equal, toItem: trimLineContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimLineView, attribute: .bottom, relatedBy: .equal, toItem: trimLineContainerView, attribute: .bottom, multiplier: 1, constant: 0)
        ])

        // trimStartTimeLineView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeLineView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimStartTimeLineView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimStartTimeLineView, attribute: .leading, relatedBy: .equal, toItem: trimLineContainerView, attribute: .leading, multiplier: 1, constant: 0)
        ])

        // trimStartTimeLineView
        trimStartTimeLineView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeLineView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 2)
        ])

        // trimEndTimeLineView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeLineView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimEndTimeLineView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimEndTimeLineView, attribute: .trailing, relatedBy: .equal, toItem: trimLineContainerView, attribute: .trailing, multiplier: 1, constant: 0)
        ])

        // trimEndTimeLineView
        trimEndTimeLineView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeLineView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 2)
        ])

        // trimStartTimeView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimStartTimeView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 0)
        ])

        // trimStartTimeView
        trimStartTimeView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 80)
        ])

        // trimStartTimeView & trimLineContainerView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeView, attribute: .leading, relatedBy: .equal, toItem: trimLineContainerView, attribute: .leading, multiplier: 1, constant: -60)
        ])

        // trimEndTimeView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimEndTimeView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 0)
        ])

        // trimEndTimeView
        trimEndTimeView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 80)
        ])

        // trimEndTimeView & trimLineContainerView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeView, attribute: .trailing, relatedBy: .equal, toItem: trimLineContainerView, attribute: .trailing, multiplier: 1, constant: 60)
        ])

        // trimStartTimeDimView & frameView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeDimView, attribute: .top, relatedBy: .equal, toItem: frameView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimStartTimeDimView, attribute: .bottom, relatedBy: .equal, toItem: frameView, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimStartTimeDimView, attribute: .leading, relatedBy: .equal, toItem: frameView, attribute: .leading, multiplier: 1, constant: 0)
        ])

        // trimStartTimeDimView & trimLineContainerView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimStartTimeDimView, attribute: .trailing, relatedBy: .equal, toItem: trimLineContainerView, attribute: .leading, multiplier: 1, constant: 0)
        ])

        // trimEndTimeDimView & frameView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeDimView, attribute: .top, relatedBy: .equal, toItem: frameView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimEndTimeDimView, attribute: .bottom, relatedBy: .equal, toItem: frameView, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: trimEndTimeDimView, attribute: .trailing, relatedBy: .equal, toItem: frameView, attribute: .trailing, multiplier: 1, constant: 0)
        ])

        // trimEndTimeDimView & trimLineContainerView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: trimEndTimeDimView, attribute: .leading, relatedBy: .equal, toItem: trimLineContainerView, attribute: .trailing, multiplier: 1, constant: 0)
        ])

        // playTimeLineView
        let playTimeLineViewLeadingConstraint = NSLayoutConstraint(item: playTimeLineView, attribute: .leading, relatedBy: .equal, toItem: frameContainerView, attribute: .leading, multiplier: 1, constant: 0)
        playTimeLineViewLeadingConstraint.identifier = "playTimeLineViewLeading"
        let playTimeLineViewTopConstraint = NSLayoutConstraint(item: playTimeLineView, attribute: .top, relatedBy: .equal, toItem: frameContainerView, attribute: .top, multiplier: 1, constant: -2)
        playTimeLineViewTopConstraint.identifier = "playTimeLineViewTop"
        let playTimeLineViewBottomConstraint = NSLayoutConstraint(item: playTimeLineView, attribute: .bottom, relatedBy: .equal, toItem: frameContainerView, attribute: .bottom, multiplier: 1, constant: 2)
        playTimeLineViewBottomConstraint.identifier = "playTimeLineViewBottom"
        frameContainerView.addConstraints([
            playTimeLineViewLeadingConstraint,
            playTimeLineViewTopConstraint,
            playTimeLineViewBottomConstraint
        ])

        // playTimeLineView
        let playTimeLineViewWidthConstraint = NSLayoutConstraint(item: playTimeLineView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 6)
        playTimeLineViewWidthConstraint.identifier = "playTimeLineViewWidth"
        playTimeLineView.addConstraints([
            playTimeLineViewWidthConstraint
        ])

        // playTimeContainerView
        frameContainerView.addConstraints([
            NSLayoutConstraint(item: playTimeContainerView, attribute: .top, relatedBy: .equal, toItem: playTimeLineView, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: playTimeContainerView, attribute: .bottom, relatedBy: .equal, toItem: playTimeLineView, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: playTimeContainerView, attribute: .centerX, relatedBy: .equal, toItem: playTimeLineView, attribute: .centerX, multiplier: 1, constant: 0)
        ])

        // playTimeContainerView
        playTimeContainerView.addConstraints([
            NSLayoutConstraint(item: playTimeContainerView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 40)
        ])

        remakeFrameImages(count: frameImageCount)

        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(emptyAction(_:))))
        frameContainerView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(emptyAction(_:))))
        trimStartTimeView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(trimStartTimeGesture(_:))))
        trimEndTimeView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(trimEndTimeGesture(_:))))
        playTimeContainerView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(playTimeGesture(_:))))
        trimLineView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(frameTap(_:))))
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func imageTo(time: CMTime) -> UIImage? {
        guard let asset = asset else { return nil }
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        guard let imageRef = try? imageGenerator.copyCGImage(at: time, actualTime: nil) else { return nil }
        let image = UIImage(cgImage: imageRef)
        return image
    }

    private func remakeFrameImages(count: Int) {
        var imageViews = [VisualEffectImageView]()
        for _ in 0..<count {
            let imageView = VisualEffectImageView(frame: .zero)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFill
            imageView.backgroundColor = .clear
            imageView.clipsToBounds = true
            imageViews.append(imageView)
        }
        frameImages = imageViews

        frameView.subviews.forEach {
            frameView.removeConstraints($0.constraints)
            $0.removeConstraints($0.constraints)
            $0.removeFromSuperview()
        }

        frameImages.forEach { frameView.addSubview($0) }

        var beforeImage: UIImageView?
        for imageView in frameImages {
            if let beforeImage = beforeImage {
                frameView.addConstraints([
                    NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal, toItem: beforeImage, attribute: .trailing, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: beforeImage, attribute: .width, multiplier: 1, constant: 0)
                ])
            } else {
                frameView.addConstraints([
                    NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal, toItem: frameView, attribute: .leading, multiplier: 1, constant: 0)
                ])
            }
            frameView.addConstraints([
                NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: frameView, attribute: .top, multiplier: 1, constant: 0),
                NSLayoutConstraint(item: imageView, attribute: .bottom, relatedBy: .equal, toItem: frameView, attribute: .bottom, multiplier: 1, constant: 0)
            ])
            beforeImage = imageView
        }
        if let beforeImage = beforeImage {
            frameView.addConstraints([
                NSLayoutConstraint(item: beforeImage, attribute: .trailing, relatedBy: .equal, toItem: frameView, attribute: .trailing, multiplier: 1, constant: 0)
            ])
        }
    }

    private func updateLayout() {
        let topMargin = self.topMargin
        self.topMargin = topMargin

        let bottomMargin = self.bottomMargin
        self.bottomMargin = bottomMargin

        let leadingMargin = self.leadingMargin
        self.leadingMargin = leadingMargin

        let trailingMargin = self.trailingMargin
        self.trailingMargin = trailingMargin

        let frameHeight = self.frameHeight
        self.frameHeight = frameHeight

        let trimMaskDimViewColor = self.trimMaskDimViewColor
        self.trimMaskDimViewColor = trimMaskDimViewColor

        let trimLineRadius = self.trimLineRadius
        self.trimLineRadius = trimLineRadius

        let trimLineWidth = self.trimLineWidth
        self.trimLineWidth = trimLineWidth

        let playLineRadius = self.playLineRadius
        self.playLineRadius = playLineRadius

        let playLineWidth = self.playLineWidth
        self.playLineWidth = playLineWidth

        let playLineVerticalSize = self.playLineVerticalSize
        self.playLineVerticalSize = playLineVerticalSize

        let trimLineViewColor = self.trimLineViewColor
        self.trimLineViewColor = trimLineViewColor

        let playTimeLineViewColor = self.playTimeLineViewColor
        self.playTimeLineViewColor = playTimeLineViewColor

        let timeColor = self.timeColor
        self.timeColor = timeColor

        let timeFont = self.timeFont
        self.timeFont = timeFont
    }

    @objc private func emptyAction(_ sender: Any?) { }

    private func makeDuration(leading: CGFloat?, trailing: CGFloat?) -> CMTime? {
        guard let asset = asset else { return nil }
        var leadingConstant = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first?.constant
        var trailingConstant = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first?.constant
        if let leading = leading {
            leadingConstant = leading
        }
        if let trailing = trailing {
            trailingConstant = trailing
        }
        if let leadingConstant = leadingConstant, let trailingConstant = trailingConstant {
            let remainWidth = frameWidth - abs(leadingConstant) - abs(trailingConstant)
            let duration = asset.duration
            let value = CGFloat(duration.value)
            let endTime = value * remainWidth / frameWidth
            return CMTime(value: CMTimeValue(endTime), timescale: duration.timescale)
        } else {
            return nil
        }
    }

    @objc private func trimStartTimeGesture(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            delegate?.videoTrimStartTrimChange(self)
        } else if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            delegate?.videoTrimEndTrimChange(self)
        }
        let point = sender.location(in: frameContainerView)
        let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first
        let constant = point.x
        let trailingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first
        let remainWidth = frameWidth - abs((trailingConstraint?.constant ?? 0))
        if trimMaximumDuration != .zero, let makeDuration = makeDuration(leading: constant < 0 ? 0 : constant, trailing: nil) {
            let maximumTime = CGFloat(trimMaximumDuration.value) / CGFloat(trimMaximumDuration.timescale)
            let makeTime = CGFloat(makeDuration.value) / CGFloat(makeDuration.timescale)
            if maximumTime < makeTime {
                return
            }
        }
        if constant < 0 {
            leadingConstraint?.constant = 0
            updateTotalTime()
            updatePlayTime()
            return
        } else if (constant + trimLineWidth*2 + trimRemainWidth) > remainWidth {
            return
        }
        leadingConstraint?.constant = constant
        updateTotalTime()
        updatePlayTime()
        if let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first {
            if constant > playTimeLineViewLeadingConstraint.constant {
                playTimeLineViewLeadingConstraint.constant = constant
                updatePlayTime()
                delegate?.videoTrimPlayTimeChange(self)
            }
        }
    }
    
    @objc private func trimEndTimeGesture(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            delegate?.videoTrimStartTrimChange(self)
        } else if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            delegate?.videoTrimEndTrimChange(self)
        }
        let point = sender.location(in: frameContainerView)
        let trailingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first
        let constant = -(frameWidth - point.x)
        let leadingConstraint = self.frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first
        let remainWidth = frameWidth - abs((leadingConstraint?.constant ?? 0))

        if trimMaximumDuration != .zero, let makeDuration = self.makeDuration(leading: nil, trailing: constant > 0 ? 0 : constant) {
            let maximumTime = CGFloat(trimMaximumDuration.value) / CGFloat(trimMaximumDuration.timescale)
            let makeTime = CGFloat(makeDuration.value) / CGFloat(makeDuration.timescale)
            if maximumTime < makeTime {
                return
            }
        }
        if constant > 0 {
            trailingConstraint?.constant = 0
            updateTotalTime()
            return
        } else if (abs(constant) + trimLineWidth*2 + trimRemainWidth) > remainWidth {
            return
        }
        trailingConstraint?.constant = constant
        updateTotalTime()
        if let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first {
            if (frameWidth - abs(constant) - playLineWidth) < playTimeLineViewLeadingConstraint.constant {
                playTimeLineViewLeadingConstraint.constant = frameWidth - abs(constant) - playLineWidth
                updatePlayTime()
                delegate?.videoTrimPlayTimeChange(self)
            }
        }
    }

    @objc private func playTimeGesture(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            delegate?.videoTrimStartTrimChange(self)
        } else if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            delegate?.videoTrimEndTrimChange(self)
        }
        if sender.state == .changed {
            let point = sender.location(in: frameContainerView)
            let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first
            let constant = point.x
            if let leadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewLeading" }).first, let trailingConstraint = frameContainerView.constraints.filter({ $0.identifier == "trimContainerViewTrailing" }).first {
                if leadingConstraint.constant > constant {
                    playTimeLineViewLeadingConstraint?.constant = leadingConstraint.constant
                    updatePlayTime()
                    delegate?.videoTrimPlayTimeChange(self)
                    return
                } else if constant > frameWidth - abs(trailingConstraint.constant) - playLineWidth {
                    playTimeLineViewLeadingConstraint?.constant = frameWidth - abs(trailingConstraint.constant) - playLineWidth
                    updatePlayTime()
                    delegate?.videoTrimPlayTimeChange(self)
                    return
                }
            }
            playTimeLineViewLeadingConstraint?.constant = constant
            updatePlayTime()
            delegate?.videoTrimPlayTimeChange(self)
        }
    }

    @objc private func frameTap(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: frameContainerView)
        let constant = point.x
        let playTimeLineViewLeadingConstraint = frameContainerView.constraints.filter({ $0.identifier == "playTimeLineViewLeading" }).first
        playTimeLineViewLeadingConstraint?.constant = constant + (playLineWidth / 2)
        updatePlayTime()
        delegate?.videoTrimPlayTimeChange(self)
    }

    private func updatePlayTime() {
        let time = playTime
        if time == .zero {
            timeLabel.text = 0.time
        }
        timeLabel.text = Int(ceil(CGFloat(time.value) / CGFloat(time.timescale))).time
    }

    private func updateTotalTime() {
        let time = durationTime
        if time == .zero {
            totalTimeLabel.text = 0.time
        }
        totalTimeLabel.text = Int(ceil(CGFloat(time.value) / CGFloat(time.timescale))).time
    }
}
