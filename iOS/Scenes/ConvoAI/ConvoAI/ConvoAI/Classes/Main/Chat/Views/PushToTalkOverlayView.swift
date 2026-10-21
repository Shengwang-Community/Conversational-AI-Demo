//
//  PushToTalkOverlayView.swift
//  ConvoAI
//

import UIKit
import Common

// A centered row of bars, 6 apart: 2 + 35 * 6 = 212 wide.
private let barCount = 36
private let barStep: CGFloat = 6
// The base's vertical radius as a fraction of the view height, so the largest drift (up 8%, scale 1.15) and
// volume swell (1.25) still end inside the view: (0.08 + 0.62 * 1.15) * 1.25 ≈ 0.99.
private let baseHeight: CGFloat = 0.62
// Blobs, back to front: base, mid, accent and aurora.
private let blobColors = ["ai_brand_main7", "ai_brand_main6", "ai_blue6", "ai_brand_lightbrand7"]
private let blobAlphas: [[CGFloat]] = [[1, 0.95, 0.55, 0], [0.9, 0.6, 0.2, 0], [0.7, 0.4, 0.1, 0], [0.7, 0.35, 0.08, 0]]
// Radii relative to the base, whose ellipse spans the view width.
private let blobSizes: [CGFloat] = [1, 0.7, 0.45, 0.55]
// Max horizontal drift as a fraction of the view width.
private let blobDriftX: [CGFloat] = [0.15, 0.15, 0.25, 0.25]
// The aurora's breathing period in seconds; it moves the glow between brand cyan and indigo.
private let auroraPeriod: CGFloat = 9
// The crest light: a ring on the base between 0.68 and 0.9 of its radii, brightest at 0.79.
private let crestAlphas: [CGFloat] = [0, 0, 0.5, 0, 0]
private let crestStops: [NSNumber] = [0, 0.68, 0.79, 0.9, 1]
// The glint glides along the crest at 0.78 of the base's radii, 90 ± 50 degrees (90 is the top), every 7 s.
private let glintRadius: CGFloat = 0.78
private let glintSweep: CGFloat = 50
private let glintPeriod: CGFloat = 7
// Its width as a fraction of the view width; it is 10 tall.
private let glintWidth: CGFloat = 0.16
private let glintStops: [NSNumber] = [0, 0.4, 1]
// The deep spot under the finger: its size as a fraction of the view, and how dark its bottom is
// (0 is ai_brand_main7, 1 is black). Its top is a fifth as dark.
private let spotSize: CGFloat = 0.3
private let spotDarken: CGFloat = 0.5
// Center-weighted envelope of the volume bars: 1 at the center, 0 at the edges.
private let barWeights: [CGFloat] = (0..<barCount).map { index in
    let x = CGFloat(index) / CGFloat(barCount - 1) * 2 - 1
    return 1 - x * x
}

// An elliptical radial gradient filling the layer, transparent at its edge, so it has no hard edge.
private func radialLayer(_ colors: [UIColor], _ locations: [NSNumber] = [0, 0.45, 0.75, 1]) -> CAGradientLayer {
    let layer = CAGradientLayer()
    layer.type = .radial
    layer.colors = colors.map { $0.cgColor }
    layer.locations = locations
    layer.startPoint = CGPoint(x: 0.5, y: 0.5)
    layer.endPoint = CGPoint(x: 1, y: 1)
    return layer
}

// The color at each alpha.
private func withAlphas(_ color: UIColor, _ alphas: [CGFloat]) -> [UIColor] {
    alphas.map { color.withAlphaComponent($0) }
}

// Blends the color toward black by the given fraction.
private func darkened(_ color: UIColor, by fraction: CGFloat) -> UIColor {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let keep = 1 - fraction
    return UIColor(red: red * keep, green: green * keep, blue: blue * keep, alpha: alpha)
}

/// Hold-to-talk glow over the bottom of the call page: four drifting color blobs (the last, a cyan aurora, breathes
/// slowly) that swell with the local microphone level, a crest light on the base with a glint gliding along it, a
/// deeper spot that follows the finger, the "release to send" label and a row of volume bars.
/// It only draws and never takes touches.
class PushToTalkOverlayView: UIView {
    private var holding = false
    private var targetLevel: CGFloat = 0
    private var smoothedLevel: CGFloat = 0
    // Seconds since the press; drives the aurora's breathing and the glint.
    private var elapsed: CGFloat = 0
    private var barTargets = [CGFloat](repeating: 0, count: barCount)
    private var barLevels = [CGFloat](repeating: 0, count: barCount)
    // Bumped on every stop, so a finished drift of an earlier press does not start a new one.
    private var generation = 0
    // The only frame callback, running while holding: smooths the level and the spot, and drives the blob group,
    // the lights, the spot and the bars.
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private let blobGroup = CALayer()
    private let label = UILabel()
    private let blobs: [CAGradientLayer] = zip(blobColors, blobAlphas).map { name, alphas in
        radialLayer(withAlphas(UIColor.themColor(named: name), alphas))
    }
    // Holds the aurora, the last blob, and breathes its opacity; the blob itself drifts like the others.
    private let auroraBreath: CALayer = {
        let layer = CALayer()
        // A single sublayer: apply the opacity to it directly instead of compositing a group offscreen.
        layer.allowsGroupOpacity = false
        return layer
    }()
    // The crest light has the base's box and follows its drift inside the group.
    private let crest = radialLayer(
        withAlphas(UIColor.themColor(named: "ai_brand_lightbrand7"), crestAlphas), crestStops
    )
    // A short bright streak on the crest, white to cyan to clear.
    private let glint: CAGradientLayer = {
        let lightbrand7 = UIColor.themColor(named: "ai_brand_lightbrand7")
        let colors = [
            UIColor.themColor(named: "ai_brand_white10"),
            lightbrand7.withAlphaComponent(0.7),
            lightbrand7.withAlphaComponent(0)
        ]
        return radialLayer(colors, glintStops)
    }()
    // The deep spot: a soft round edge, filled top to bottom with a darkening base color.
    private let spot: CAGradientLayer = {
        let main7 = UIColor.themColor(named: "ai_brand_main7")
        let spot = CAGradientLayer()
        spot.colors = [darkened(main7, by: spotDarken * 0.2).cgColor, darkened(main7, by: spotDarken).cgColor]
        // Opaque at the center, clear at the edge.
        spot.mask = radialLayer(withAlphas(.black, [1, 0.75, 0.3, 0]))
        return spot
    }()
    // The reported finger, and the smoothed point the spot follows.
    private var touch = CGPoint.zero
    private var finger = CGPoint.zero
    private var hasTouchPoint = false
    // Bars change their real height, not their scale, so the round caps stay round and silence shows dots.
    private let bars: [CALayer] = barWeights.map { weight in
        let bar = CALayer()
        bar.backgroundColor = UIColor.themColor(named: "ai_brand_white10").cgColor
        // Edge bars are dimmer.
        bar.opacity = Float(0.5 + 0.5 * weight)
        bar.cornerRadius = 1
        return bar
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        // The volume swell is anchored at the bottom center.
        blobGroup.anchorPoint = CGPoint(x: 0.5, y: 1)
        // Back to front: base, mid, accent, the aurora in its breathing holder, then the crest light.
        for (index, blob) in blobs.enumerated() {
            (index == blobs.count - 1 ? auroraBreath : blobGroup).addSublayer(blob)
        }
        blobGroup.addSublayer(auroraBreath)
        blobGroup.addSublayer(crest)
        layer.addSublayer(blobGroup)
        layer.addSublayer(spot)
        layer.addSublayer(glint)
        label.text = ResourceManager.localizedString("conversation.ptt.release")
        label.textColor = UIColor.themColor(named: "ai_brand_white10").withAlphaComponent(0.85)
        label.font = UIFont.systemFont(ofSize: 14)
        addSubview(label)
        bars.forEach { layer.addSublayer($0) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the glow while holding (180 ms fade-in with a slight rise) and hides it otherwise (120 ms fade-out).
    func setHolding(_ holding: Bool) {
        guard holding != self.holding else { return }
        self.holding = holding
        stop()
        layer.removeAllAnimations()
        guard holding else {
            hasTouchPoint = false
            UIView.animate(withDuration: 0.12, animations: { self.alpha = 0 }) { [weak self] finished in
                if finished { self?.isHidden = true }
            }
            return
        }
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: 24)
        isHidden = false
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
        }
        // Each press starts from a fresh random state, with the spot as close to the finger as it may go.
        smoothedLevel = 0
        elapsed = 0
        lastTimestamp = 0
        for index in blobs.indices { drift(index, animated: false) }
        // Without a finger point the spot sits at the top of its reach.
        if !hasTouchPoint { setTouchPoint(CGPoint(x: bounds.width / 2, y: 0)) }
        finger = touch
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blobGroup.transform = CATransform3DIdentity
        blobGroup.opacity = 0.85
        placeLights(base: blobs[0].transform)
        placeSpot(base: blobs[0].transform)
        CATransaction.commit()
        for index in blobs.indices { drift(index, animated: true) }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Local microphone level, 0-255, reported every 100 ms.
    func setVolume(_ level: Int) {
        // The Web curve: a small noise gate, then a square root with a gain of 1.1, so speech lifts the glow as there.
        let gated = (CGFloat(min(max(level, 0), 255)) / 255 - 0.02) / 0.98
        targetLevel = gated > 0 ? min(1, sqrt(gated) * 1.1) : 0
        // Each sample re-rolls a small per-bar variation on the center-weighted envelope.
        for index in barTargets.indices {
            barTargets[index] = targetLevel * (0.3 + 0.7 * barWeights[index]) * .random(in: 0.7...1)
        }
    }

    /// The finger position in this view's coordinates; the deep spot follows it within the glow.
    func setTouchPoint(_ point: CGPoint) {
        hasTouchPoint = true
        touch = point
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        // The bar row: 28 tall, centered, 24 above the bottom safe area.
        let rowCenterY = size.height - safeAreaInsets.bottom - 24 - 14
        let firstBarX = (size.width - 2 - CGFloat(barCount - 1) * barStep) / 2 + 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blobGroup.bounds = CGRect(origin: .zero, size: size)
        blobGroup.position = CGPoint(x: size.width / 2, y: size.height)
        auroraBreath.frame = CGRect(origin: .zero, size: size)
        // Each blob is an ellipse centered on the bottom edge; the drift moves it through its transform.
        for (index, blob) in blobs.enumerated() {
            let width = 2 * size.width * blobSizes[index]
            let height = 2 * size.height * baseHeight * blobSizes[index]
            blob.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            blob.position = CGPoint(x: size.width / 2, y: size.height)
        }
        crest.bounds = blobs[0].bounds
        crest.position = blobs[0].position
        spot.bounds = CGRect(x: 0, y: 0, width: size.width * spotSize, height: size.height * spotSize)
        spot.mask?.frame = spot.bounds
        glint.bounds = CGRect(x: 0, y: 0, width: size.width * glintWidth, height: 10)
        for (index, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: 2, height: 4 + 24 * barLevels[index])
            bar.position = CGPoint(x: firstBarX + CGFloat(index) * barStep, y: rowCenterY)
        }
        CATransaction.commit()
        label.sizeToFit()
        label.center = CGPoint(x: size.width / 2, y: rowCenterY - 14 - 12 - label.bounds.height / 2)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        guard newWindow == nil else { return }
        holding = false
        hasTouchPoint = false
        stop()
        layer.removeAllAnimations()
        isHidden = true
    }

    // Moves a blob to a random offset, scale and opacity; when animated, it keeps picking a new target every 1.2-2.0 s.
    private func drift(_ index: Int, animated: Bool) {
        let dx = bounds.width * blobDriftX[index] * .random(in: -1...1)
        let dy = bounds.height * 0.08 * .random(in: -1...1)
        let scale = CGFloat.random(in: 0.85...1.15)
        let generation = self.generation
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(.random(in: 1.2...2.0))
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            CATransaction.setCompletionBlock { [weak self] in
                guard let self, self.generation == generation else { return }
                self.drift(index, animated: true)
            }
        } else {
            CATransaction.setDisableActions(true)
        }
        blobs[index].transform = CATransform3DScale(CATransform3DMakeTranslation(dx, dy, 0), scale, scale, 1)
        blobs[index].opacity = .random(in: 0.7...1)
        CATransaction.commit()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt = lastTimestamp > 0 ? CGFloat(link.timestamp - lastTimestamp) : 0
        lastTimestamp = link.timestamp
        elapsed += dt
        smoothedLevel = smooth(smoothedLevel, to: targetLevel, dt)
        // The spot trails the finger slightly so it glides instead of jumping.
        let follow = 1 - exp(-dt / 0.1)
        finger.x += (touch.x - finger.x) * follow
        finger.y += (touch.y - finger.y) * follow
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Taller and brighter when louder; the drift continues on top.
        blobGroup.transform = CATransform3DMakeScale(1, 1 + 0.25 * smoothedLevel, 1)
        blobGroup.opacity = Float(0.85 + 0.15 * smoothedLevel)
        // The base is mid-drift, so read where it is drawn now.
        let base = blobs[0].presentation()?.transform ?? blobs[0].transform
        placeLights(base: base)
        placeSpot(base: base)
        for (index, bar) in bars.enumerated() {
            barLevels[index] = smooth(barLevels[index], to: barTargets[index], dt)
            bar.bounds.size.height = 4 + 24 * barLevels[index]
        }
        CATransaction.commit()
    }

    // Breathes the aurora, puts the crest light on the base and moves the glint along the crest; the aurora and the
    // crest brighten when louder. `base` is the base's drift transform. Call inside a transaction without actions.
    private func placeLights(base: CATransform3D) {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let breath: CGFloat = 0.5 + 0.5 * sin(2 * .pi * elapsed / auroraPeriod)
        auroraBreath.opacity = Float(min(1, 0.15 + 0.45 * breath + 0.35 * smoothedLevel))
        crest.transform = base
        crest.opacity = Float(0.3 + 0.6 * smoothedLevel)
        // The glint is outside the group, so it follows the base's center and radii as drawn, like the spot.
        let swell = 1 + 0.25 * smoothedLevel
        let centerX = size.width / 2 + base.m41
        let centerY = size.height + base.m42 * swell
        let radiusX = size.width * base.m11 * glintRadius
        let radiusY = size.height * baseHeight * base.m22 * swell * glintRadius
        let theta: CGFloat = (90 + glintSweep * sin(2 * .pi * elapsed / glintPeriod)) * .pi / 180
        glint.position = CGPoint(x: centerX + radiusX * cos(theta), y: centerY - radiusY * sin(theta))
        // Along the ellipse's tangent.
        glint.transform = CATransform3DMakeRotation(atan2(radiusY * cos(theta), radiusX * sin(theta)), 0, 0, 1)
        glint.opacity = Float(0.3 + 0.5 * smoothedLevel)
    }

    // Centers the spot on the smoothed finger, kept inside a reach ellipse around the base's center so it stays
    // inside the glow while the base drifts and swells; it grows a little when louder. `base` is the base's drift
    // transform. Call inside a transaction without actions.
    private func placeSpot(base: CATransform3D) {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let swell = 1 + 0.25 * smoothedLevel
        // The base's center and radii as drawn: the group swells around the bottom edge.
        let centerX = size.width / 2 + base.m41
        let centerY = size.height + base.m42 * swell
        // At most 0.4 of the base's horizontal radius sideways and half its vertical radius up.
        let reachX = size.width * base.m11 * 0.4
        let reachY = size.height * baseHeight * base.m22 * swell * 0.5
        // Sideways first, so the spot keeps following the finger, then up to the ellipse at that x and never below
        // the center. The finger sits above the reach, so the spot rides the ellipse's top edge.
        let u = min(max((finger.x - centerX) / reachX, -1), 1)
        let v = min(max((finger.y - centerY) / reachY, -sqrt(1 - u * u)), 0)
        spot.position = CGPoint(x: centerX + u * reachX, y: centerY + v * reachY)
        let scale = 1 + 0.2 * smoothedLevel
        spot.transform = CATransform3DMakeScale(scale, scale, 1)
    }

    // Fast attack (80 ms), slower release (250 ms).
    private func smooth(_ current: CGFloat, to target: CGFloat, _ dt: CGFloat) -> CGFloat {
        current + (target - current) * (1 - exp(-dt / (target > current ? 0.08 : 0.25)))
    }

    // Stops the display link and the drift where they are; the bars drop back to dots.
    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
        generation += 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for blob in blobs {
            // Keep the current drift position instead of jumping to its target.
            if let presentation = blob.presentation() {
                blob.transform = presentation.transform
                blob.opacity = presentation.opacity
            }
            blob.removeAllAnimations()
        }
        for (index, bar) in bars.enumerated() {
            barLevels[index] = 0
            bar.bounds.size.height = 4
        }
        CATransaction.commit()
    }
}
