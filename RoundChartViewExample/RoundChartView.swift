//
//  RoundChartView.swift
//  RoundChartViewExample
//
//  Created by Oleg Shulakov on 07.03.2022.
//

import UIKit

protocol RoundChartViewDelegate: AnyObject {
    func didTapSectionAtIndex(_ index: Int?)
}

final class RoundChartView: UIView {
    private struct Constants {
        static let arcWidth: CGFloat = 10
        static let arcWidthHighlited: CGFloat = 10
    }

    public var delegate: RoundChartViewDelegate?

    private var sections: [ChartSection]
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var circleRadius: CGFloat {
        max(bounds.width / 2, bounds.height / 2)
    }
    private var totalValues: Double {
        sections.reduce(0) {$0 + $1.value}
    }
    private var partValues: [Double] {
        sections.map { $0.value/totalValues }
    }
    private var angles: [CGFloat] {
        partValues.map { CGFloat(360 * $0) }
    }
    private var anglesSum: [CGFloat] {
        var arr = [CGFloat](angles)
        for i in 1..<arr.count {
            arr[i] += arr[i-1]
        }
        return arr
    }

    private var circleLayers = [CAShapeLayer]()
    private var highlightedIndex: Int?
    private var highlightedLayer: CAShapeLayer?
    private var unhighlightedLayer: CAShapeLayer?

    override init(frame: CGRect) {
        sections = [ChartSection]()
        super.init(frame: frame)

        backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods
    public func setSections(_ sections: [ChartSection], animated: Bool) {
        self.sections = sections
        setNeedsLayout()
        layoutIfNeeded()
        addLayersFor(sections: sections, transparent: animated)
        if animated {
            animateCircle(duration: 1)
        }
    }

    public func selectSectionAtIndex(
        _ index: Int,
        userInitiated: Bool,
        duration: TimeInterval = 0.2
    ) {
        guard index >= 0, index < sections.count else {
            return
        }

        if highlightedIndex == index {
            clearSectionSelection(duration: duration)
        } else {
            if highlightedLayer != nil {
                clearSectionSelection(duration: duration)
            }

            let startAngle = index == 0 ? 0 : anglesSum[index - 1]
            let endAngle = anglesSum[index]
            let layerArc = getArcLayer(
                color: sections[index].color,
                radius: circleRadius - Constants.arcWidth / 2,
                lineWidth: Constants.arcWidth,
                startAngle: startAngle - 90,
                endAngle: endAngle - 90
            )

            let animation = highlightAnimation(duration: duration, highlight: true)
            layerArc.add(animation, forKey: "animateLineWidth")
            highlightedIndex = index
            highlightedLayer = layerArc
        }

        if userInitiated {
            delegate?.didTapSectionAtIndex(index)
        }
    }

    public func clearSectionSelection(duration: TimeInterval = 0.2) {
        let animation = highlightAnimation(duration: duration, highlight: false)
        highlightedLayer?.add(animation, forKey: "animateLineWidth")
        highlightedIndex = nil
        unhighlightedLayer = highlightedLayer
        highlightedLayer = nil
    }

    func animateCircle(duration: TimeInterval) {
        let initialTime = CACurrentMediaTime()
        let speed = Double(360) / duration
        let halfSpeed = speed / 2

        let originalStartPercent  = 0.7 // на каком участке секции начинае показываться следующая
        var nextSectionStartPercent = originalStartPercent // может пересчитываться при сильно различающихся по длительности секциях
        let fistSectionHalfDuration = Double(angles[0]) * nextSectionStartPercent / speed
        let firstStrokeDuration = fistSectionHalfDuration + Double(angles[0]) * (1 - nextSectionStartPercent) / halfSpeed
        let times: [TimeInterval] = partValues.map {duration * $0 }
        let timesSum: [TimeInterval] = {
            var arr = times
            for i in 1..<arr.count {
                arr[i] += arr[i-1]
            }
            return arr
        }()

        var beginTimes: [TimeInterval] = [0]
        var rotationDurations: [TimeInterval] = [0]
        var rotationAngles: [CGFloat] = [0]
        var strokeDurations: [TimeInterval] = [fistSectionHalfDuration + Double(angles[0]) * (1 - nextSectionStartPercent) / halfSpeed]
        var strokeKeyTimes: [[NSNumber]] = [[0, NSNumber(value: fistSectionHalfDuration/firstStrokeDuration), 1]]
        var strokeValues: [[Double]] = [[0, nextSectionStartPercent, 1]]

        for i in 1..<times.count {
            var rotationAngle = angles[i-1] * CGFloat(1 - nextSectionStartPercent)
            let endAngle = angles[i] * CGFloat(1 - nextSectionStartPercent)

            if rotationAngle > angles[i]*CGFloat(nextSectionStartPercent) {
                let prevRotationAngle = rotationAngle
                rotationAngle = angles[i]*CGFloat(nextSectionStartPercent)
                nextSectionStartPercent = Double(1 - rotationAngle/angles[i-1])

                let newDuration = strokeDurations[i-1]
                    - Double(prevRotationAngle)/halfSpeed
                    + Double(prevRotationAngle - rotationAngle)/speed
                    + Double(rotationAngle)/halfSpeed
                var newStrokeKeyTimes = strokeKeyTimes[i-1]
                let dur = Double(rotationAngle) / halfSpeed
                newStrokeKeyTimes[newStrokeKeyTimes.count-2] = NSNumber(value: (newDuration - dur) / newDuration)
                var newStrokeValues = strokeValues[i-1]
                newStrokeValues[newStrokeValues.count-2] = nextSectionStartPercent

                strokeDurations[i-1] = newDuration
                strokeKeyTimes[i-1] = newStrokeKeyTimes
                strokeValues[i-1] = newStrokeValues
            }

            let startPart = Double(rotationAngle) / halfSpeed
            let endPart = i == sections.count-1 ? 0 : Double(endAngle) / halfSpeed

            let strokeDuration = startPart*0.5 + times[i] + endPart*0.5

            if i != times.count - 1 {
                let keyTimes: [NSNumber] = [
                    NSNumber(value: 0),
                    NSNumber(value: startPart / strokeDuration),
                    NSNumber(value: (strokeDuration - endPart) / strokeDuration),
                    NSNumber(value: 1)
                ]
                strokeKeyTimes.append(keyTimes)

                let strkValues: [TimeInterval] = [
                    0,
                    Double(rotationAngle / angles[i]),
                    Double((angles[i] - endAngle) / angles[i]),
                    1
                ]
                strokeValues.append(strkValues)
            } else {
                let keyTimes: [NSNumber] = [
                    NSNumber(value: 0),
                    NSNumber(value: startPart / strokeDuration),
                    NSNumber(value: 1)
                ]
                strokeKeyTimes.append(keyTimes)

                let strkValues: [TimeInterval] = [
                    0,
                    Double(rotationAngle / angles[i]),
                    1
                ]
                strokeValues.append(strkValues)
            }

            let rotationDuration = Double(rotationAngle) / halfSpeed

            rotationAngles.append(rotationAngle)
            rotationDurations.append(rotationDuration)
            strokeDurations.append(strokeDuration)
            beginTimes.append(timesSum[i-1] - times[i-1]*(1 - nextSectionStartPercent))

            nextSectionStartPercent = originalStartPercent
        }

        beginTimes = beginTimes.map { initialTime + $0 }

        for i in 0..<sections.count {
            let strokeAnimation = strokeEndAnimation(
                beginTime: beginTimes[i],
                duration: strokeDurations[i],
                keyTimes: strokeKeyTimes[i],
                values: strokeValues[i]
            )
            let colorAnimation = strokeColorAnimation(
                beginTime: beginTimes[i],
                duration: strokeDurations[i] * 0.7,
                color: sections[i].color
            )

            let shapeLayer = circleLayers[i]
            shapeLayer.add(strokeAnimation, forKey: "animateStrokeEnd")
            shapeLayer.add(colorAnimation, forKey: "animateColor")

            let rotateAnimation = rotatationAnimation(
                beginTime: beginTimes[i],
                duration: rotationDurations[i],
                angle: rotationAngles[i]
            )
            shapeLayer.add(rotateAnimation, forKey: "animateRotation")
        }
    }

    // MARK: - Private methods
    private func addLayersFor(sections: [ChartSection], transparent: Bool) {
        if let sublayers = layer.sublayers {
            sublayers.forEach({ $0.removeFromSuperlayer() })
        }

        circleLayers.removeAll()

        var angle: CGFloat = -90
        for (index, section) in sections.enumerated() {
            let endAngle = angle + angles[index]
            let layer = getArcLayer(
                color: transparent ? .clear : section.color,
                radius: circleRadius,
                lineWidth: Constants.arcWidth,
                startAngle: angle,
                endAngle: endAngle
            )
            circleLayers.append(layer)

            angle = endAngle
        }

        if let sublayers = layer.sublayers {
            for (i, sublayer) in sublayers.enumerated() {
                sublayer.zPosition = CGFloat(100-i)
            }
        }
    }

    private func strokeEndAnimation(
        beginTime: TimeInterval,
        duration: TimeInterval,
        keyTimes: [NSNumber] = [0, 0.5, 1],
        values: [Any] = [0, 0.5, 1]
    ) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "strokeEnd")
        animation.duration = duration
        animation.beginTime = beginTime
        animation.keyTimes = keyTimes
        animation.values = values
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func strokeColorAnimation(
        beginTime: TimeInterval,
        duration: TimeInterval,
        color: UIColor
    ) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.duration = duration
        animation.beginTime = beginTime
        animation.fromValue = UIColor.clear.cgColor
        animation.toValue = color.cgColor
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func rotatationAnimation(
        beginTime: TimeInterval,
        duration: TimeInterval,
        angle: CGFloat
    ) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.duration = duration
        animation.beginTime = beginTime
        animation.fromValue = -angle.DEG2RAD
        animation.toValue = 0.DEG2RAD
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func highlightAnimation(
        duration: TimeInterval,
        highlight: Bool
    ) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "lineWidth")
        animation.duration = duration
        animation.beginTime = CACurrentMediaTime()
        animation.fromValue = highlight ? 0 : Constants.arcWidthHighlited
        animation.toValue = highlight ? Constants.arcWidthHighlited : 0
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func getArcLayer(
        color: UIColor,
        radius: CGFloat,
        lineWidth: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat
    ) -> CAShapeLayer {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let path = UIBezierPath()
        path.addArc(
            withCenter: center,
            radius: radius - lineWidth/2,
            startAngle: startAngle.DEG2RAD,
            endAngle: endAngle.DEG2RAD,
            clockwise: true
        )

        let circleLayer = CAShapeLayer()
        circleLayer.path = path.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = color.cgColor
        circleLayer.lineWidth = lineWidth
        circleLayer.strokeEnd = 1.0
        circleLayer.frame = CGRect(origin: .zero, size: layer.bounds.size)
        layer.addSublayer(circleLayer)

        return circleLayer
    }

    @objc private func tapGestureRecognized(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            if let unhighlightedLayer = unhighlightedLayer {
                unhighlightedLayer.removeFromSuperlayer()
            }

            let location = recognizer.location(in: self)
            if let index = self.getSectionIndexByPoint(location) {
                selectSectionAtIndex(index, userInitiated: true)
            }
        }
    }

    private func getSectionIndexByPoint(_ point: CGPoint, additionalSpace: CGFloat = 20) -> Int? {
        let x = point.x
        let y = point.y

        let touchDistanceToCenter = distanceToCenter(x: point.x, y: point.y)

        // check if an arc was touched
        guard touchDistanceToCenter <= circleRadius + additionalSpace
                && touchDistanceToCenter >= circleRadius - Constants.arcWidthHighlited - additionalSpace else {
            return nil
        }

        let angle = angleForPoint(x: x, y: y)
        return anglesSum.firstIndex { angle < $0 }
    }

    private func distanceToCenter(x: CGFloat, y: CGFloat) -> CGFloat {
        let c = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let xDist = x > c.x ? x - c.x : c.x - x
        let yDist = y > c.y ? y - c.y : c.y - y
        let dist = sqrt(pow(xDist, 2.0) + pow(yDist, 2.0))
        return dist
    }

    private func angleForPoint(x: CGFloat, y: CGFloat) -> CGFloat {
        let c = CGPoint(x: bounds.width / 2, y: bounds.height / 2)

        let tx = Double(x - c.x)
        let ty = Double(y - c.y)
        let length = sqrt(tx * tx + ty * ty)
        let r = acos(ty / length)

        var angle = r.RAD2DEG

        if x > c.x {
            angle = 360.0 - angle
        }

        // add 180° because chart starts NORTH
        angle += 180.0

        if angle > 360.0 {
            angle -= 360.0
        }

        return CGFloat(angle)
    }
}

extension FloatingPoint {
    var DEG2RAD: Self {
        return self * .pi / 180
    }

    var RAD2DEG: Self {
        return self * 180 / .pi
    }
}
