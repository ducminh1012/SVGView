//
//  CMCSVGView.swift
//  comico
//
//  Created by NHNVN on 11/20/17.
//  Copyright © 2017 NHN SINGAPORE PTE LTD. All rights reserved.
//

import UIKit

class SVGData {
    var attributes: [String: String]?
    var layers: [CAShapeLayer]?
}

class CMCSVGView: UIView {

    var svgFileUrl: URL? {
        didSet {
            self.canvas?.transform = CGAffineTransform.identity
            guard let svgFileUrl = self.svgFileUrl else { return }
            self.parseSVG(svgFileUrl) { (svgData) in
                self.svgData = svgData
                self.adjustCanvas()
                self.createAnimation()
            }
        }
    }
    var progress: CGFloat = 0 {
        willSet (progress) {
            if (!animating) {
                self.progress = progress
                self.createAnimation()
            }
        }
    }
    var animating = false
    var svgData: SVGData?
    var canvas: UIView?
    var duration: TimeInterval = 1
    var completion: (() -> Void)?
    var completionCount = 0

    init() {
        super.init(frame: CGRect.zero)
        awakeFromNib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        awakeFromNib()

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        animating = false
        duration = 1
        progress = 1
        canvas = UIView()
        addSubview(canvas!)
    }

    func animate(withDuration duration: TimeInterval, completion: @escaping () -> Void) {
        self.animating = true
        self.completionCount = 0
        self.progress = 0
        self.completion = completion
        self.duration = duration
        createAnimation()
    }

    func createAnimation() {
        canvas?.layer.sublayers?.forEach({ (layer) in
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        })

        if animating {
           CATransaction.begin()
            CATransaction.setCompletionBlock({
                self.progress = 0
                self.completionCount = 0
                self.animating = false
                if let completion = self.completion {
                    completion()
                }
            })
        }

        guard let layers = svgData?.layers else { return }
        for (id, layer) in layers.enumerated() {
            let pathAnimation = CAKeyframeAnimation(keyPath: "strokeEnd")
            pathAnimation.isRemovedOnCompletion = false
            pathAnimation.duration = self.duration
            pathAnimation.values = [0,1]
            pathAnimation.keyTimes = [0,1]
            pathAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)

            var timeOffset: Double = 0

            if self.animating {
                pathAnimation.delegate = self
                pathAnimation.speed = 1
            } else {
                pathAnimation.speed = 0
                timeOffset = pathAnimation.duration * Double(max(min(self.progress, 0.99), 0.0))
            }

            pathAnimation.timeOffset = timeOffset
            layer.add(pathAnimation, forKey: "Animation__\(id)")
            self.canvas?.layer.addSublayer(layer)
        }

        if self.animating {
            OperationQueue.main.addOperation {
                CATransaction.commit()
            }

        }

    }

    func createRectFromViewBox(_ string: String) -> CGRect? {
        var bounds = CGRect.zero
        guard !string.isEmpty else { return nil }

        let viewBoxAttr = string.components(separatedBy: " ")
        guard viewBoxAttr.count == 4 else { return nil }

        bounds.origin.x = CGFloat(Double(viewBoxAttr[0]) ?? 0)
        bounds.origin.y = CGFloat(Double(viewBoxAttr[1]) ?? 0)
        bounds.size.width = CGFloat(Double(viewBoxAttr[2]) ?? 0)
        bounds.size.height = CGFloat(Double(viewBoxAttr[3]) ?? 0)

        return bounds
    }

    func parseSVG(_ url: URL, completion: ((SVGData?) -> Void)?) {

        do {
            var svgString = try NSString(contentsOf: url, encoding: String.EncodingConversionOptions.externalRepresentation.rawValue) as String
//            svgString = svgString.replacingOccurrences(of: "\\"", with: "\"")
            svgString = svgString.replacingOccurrences(of: "\"/>", with: "")
            svgString = svgString.replacingOccurrences(of: "\n", with: "")
            svgString = svgString.replacingOccurrences(of: "#", with: "")
            svgString = svgString.replacingOccurrences(of: "\r", with: "")
            svgString = svgString.replacingOccurrences(of: "\t", with: "")
            svgString = svgString.replacingOccurrences(of: "</g>", with: "")
            svgString = svgString.replacingOccurrences(of: "</svg>", with: "")

            print("svg string \(svgString)")

            var components = svgString.components(separatedBy: "<")
            for (id, obj) in components.enumerated() {
                if obj.hasPrefix("!") || obj.hasPrefix("?") || obj.count <= 1 {
                    guard let index = components.index(of: obj) else { return }
                    components.remove(at: index)
                }
            }

            guard var svgHeaderString = components.first?.components(separatedBy: "svg ").last else { return }
            svgHeaderString = svgHeaderString.replacingOccurrences(of: ">", with: "")

            let header = createAttribute(svgHeaderString)
            var layers = [CAShapeLayer]()
            components.forEach({ (obj) in
                var layer: CAShapeLayer?
                var line: String?

                if obj.hasPrefix("path") {
                    line = obj.replacingOccurrences(of: "path ", with: "")
                    layer = parsePath(line!)
                }else if obj.hasPrefix("circle") {
                    line = obj.replacingOccurrences(of: "circle ", with: "")
                    layer = parseCircle(line!)
                }else if obj.hasPrefix("rect") {
                    line = obj.replacingOccurrences(of: "rect ", with: "")
                    layer = parseRect(line!)
                }

                if let layer = layer {
                    layers.append(layer)
                }
            })

            let svgData = SVGData()
            svgData.layers = layers
            svgData.attributes = header

            OperationQueue.main.addOperation {
                if let completion = completion {
                    completion(svgData)
                }
            }


        } catch {
            print(error)
            if let completion = completion {
                completion(nil)
            }
        }


    }

    func parseRect(_ string: String) -> CAShapeLayer? {
        var rect = createAttribute(string)
        guard let x = rect["x"]?.toCGFloat(),
              let y = rect["y"]?.toCGFloat(),
              let width = rect["width"]?.toCGFloat(),
              let height = rect["height"]?.toCGFloat() else { return nil }

        let bezier = UIBezierPath(rect: CGRect(x: x, y: y, width: width, height: height))

        let layer = CAShapeLayer()
        layer.path = bezier.cgPath
        attachAttribute(layer, attributes: rect)
        return layer
    }

    func parseCircle(_ string: String) -> CAShapeLayer? {
        var circle = createAttribute(string)
        guard let cx = circle["cx"]?.toCGFloat(),
            let cy = circle["cy"]?.toCGFloat(),
            let r = circle["r"]?.toCGFloat() else { return nil }

        let bezier = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: r, startAngle: -CGFloat.pi/2, endAngle: CGFloat.pi*2, clockwise: true)

        let layer = CAShapeLayer()
        layer.path = bezier.cgPath
        attachAttribute(layer, attributes: circle)
        return layer
    }

    func parsePath(_ string: String) -> CAShapeLayer? {
        var path = createAttribute(string)

        guard var d = path["d"] else { return nil }

        d = d.components(separatedBy: CharacterSet.newlines).joined()

        let pathRef = PocketSVG.path(fromDAttribute: d).takeUnretainedValue()

        let layer = CAShapeLayer()
        layer.path = pathRef
        attachAttribute(layer, attributes: path)
        return layer
    }

    func attachAttribute(_ layer: CAShapeLayer, attributes: [String: String]) {
        if let stroke = attributes["stroke"] {
            layer.strokeColor = UIColor.hexStringToUIColor(hex: stroke).cgColor
        } else {
            layer.strokeColor = UIColor.clear.cgColor
        }

        if let fill = attributes["fill"] {
            layer.fillColor = UIColor.hexStringToUIColor(hex: fill).cgColor
        } else {
            layer.fillColor = UIColor.black.cgColor
        }

        if let strokeWidth = attributes["stroke-width"] {
            layer.lineWidth = strokeWidth.toCGFloat() ?? 0
        } else {
            layer.lineWidth = 1/UIScreen.main.scale
        }

        if let strokeLineCap = attributes["stroke-linecap"] {
            layer.lineCap = strokeLineCap
        }

        if let strokeLineJoin = attributes["stroke-linejoin"] {
            layer.lineJoin = strokeLineJoin
        }

        if let strokeMiterlimit = attributes["stroke-miterlimit"] {
            layer.miterLimit = strokeMiterlimit.toCGFloat() ?? 0
        }
    }

    func createAttribute(_ string: String) -> [String: String] {
        let svgHeaderList = string.components(separatedBy: "\" ")
        var result = [String: String]()

        svgHeaderList.forEach { (s) in
            let attr = s.components(separatedBy: "=\"")
            if attr.count >= 2 {
                guard let key = attr.first else { return }

                if !key.hasPrefix("xml") {
                    let value = attr.last
                    result[key] = value
                }
            }
        }

        return result
    }

    func adjustCanvas() {
        guard let data = self.svgData, let attributes = data.attributes, let viewBox = attributes["viewBox"] else { return }

        guard let canvasRect = createRectFromViewBox(viewBox) else { return }

        canvas?.frame = canvasRect
        let rate = min(bounds.width/canvasRect.width, bounds.height/canvasRect.height)

        canvas?.transform = CGAffineTransform(scaleX: rate, y: rate)
        canvas?.center = CGPoint(x: bounds.width/2, y: bounds.height/2)
    }


}

extension CMCSVGView: CAAnimationDelegate {

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag && anim.isKind(of: CAKeyframeAnimation.self) {
            completionCount+=1
        }
    }
}





