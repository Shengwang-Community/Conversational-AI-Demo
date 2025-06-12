import UIKit
import AVFoundation
import AgoraRtcKit

enum AnimateState {
    case idle  // Idle state, no video or animation is playing
    case listening // Listening state, playing slow animation
    case speaking  // AI speaking animation in progress
}

protocol AnimateViewDelegate: NSObject {
    func onError(error: ConvoAIError)
}

class AnimateView: NSObject {
    weak var delegate: AnimateViewDelegate?
    
    private struct VolumeConstants {
        static let minVolume: Int = 0
        static let maxVolume: Int = 255
        static let highVolume: Int = 200
        static let mediumVolume: Int = 120
        static let lowVolume: Int = 80
    }
    
    private struct ScaleConstants {
        static let scaleHigh: Float = 1.12
        static let scaleMedium: Float = 1.1
        static let scaleLow: Float = 1.08
    }
    
    private struct AnimationConstants {
        static let durationHigh: TimeInterval = 0.4
        static let durationMedium: TimeInterval = 0.5
        static let durationLow: TimeInterval = 0.6
        static let bounceScale: Float = 0.02
        static let videoFirstFileName = "ball_video_start.mp4"
        static let videoFileName = "ball_video_rotating.mp4"
    }
    
    private weak var videoView: UIView?
    private weak var rtcEngine: AgoraRtcEngineKit?
    private weak var rtcMediaPlayer: AgoraRtcMediaPlayerProtocol?
    private var scaleAnimator: CAAnimationGroup?
    private var currentAnimParams = AnimParams()
    private var pendingAnimParams: AnimParams?
    private var isInForeground = true
    
    private var currentState: AnimateState = .idle {
        didSet {
            if oldValue != currentState {
                switch currentState {
                case .idle:
                    rtcMediaPlayer?.setPlaybackSpeed(100)
                case .listening:
                    rtcMediaPlayer?.setPlaybackSpeed(150)
                case .speaking:
                    rtcMediaPlayer?.setPlaybackSpeed(250)
                }
            }
        }
    }
    
    private struct AnimParams {
        var minScale: Float = 1.0
        var duration: TimeInterval = 0.2
    }
    
    init(videoView: UIView) {
        self.videoView = videoView
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(applicationDidEnterBackground),
                                             name: UIApplication.didEnterBackgroundNotification,
                                             object: nil)
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(applicationWillEnterForeground),
                                             name: UIApplication.willEnterForegroundNotification,
                                             object: nil)
    }
    
    @objc private func applicationDidEnterBackground() {
        isInForeground = false
        videoView?.layer.removeAllAnimations()
        scaleAnimator = nil
    }
    
    @objc private func applicationWillEnterForeground() {
        isInForeground = true
    }
    
    func setupMediaPlayer(_ rtcEngine: AgoraRtcEngineKit) {
        self.rtcEngine = rtcEngine
        rtcMediaPlayer = rtcEngine.createMediaPlayer(with: self)
        if let player = rtcMediaPlayer {
            player.mute(true)
            player.setView(videoView)
            
            // Play first video
            if let filePath = Bundle.main.path(forResource: AnimationConstants.videoFirstFileName, ofType: nil) {
                let source = AgoraMediaSource()
                source.url = filePath
                source.autoPlay = true
                player.open(with: source)
            }
        }
    }
    
    func updateAgentState(_ newState: AnimateState, volume: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            self?.updateAgentStateInternal(newState, volume: volume)
        }
    }
    
    private func updateAgentStateInternal(_ newState: AnimateState, volume: Int) {
        let oldState = currentState
        currentState = newState
        handleStateTransition(oldState: oldState, newState: newState, volume: volume)
    }
    
    private func handleStateTransition(oldState: AnimateState, newState: AnimateState, volume: Int = 0) {
        switch newState {
        case .idle, .listening:
            if let group = scaleAnimator {
                group.setValue(true, forKey: "shouldStop")
            }
            updateParentScale(1.0)
            
        case .speaking:
            startAgentAnimation(volume)
        }
    }
    
    private func startAgentAnimation(_ currentVolume: Int) {
        if !isInForeground {
            return
        }
        let safeVolume = min(max(currentVolume, VolumeConstants.minVolume), VolumeConstants.maxVolume)
        let newParams = AnimParams(
            minScale: calculateMinScale(safeVolume),
            duration: calculateDuration(safeVolume)
        )
        
        if newParams.minScale == currentAnimParams.minScale && scaleAnimator != nil {
            return
        }
        
        pendingAnimParams = newParams
        
        if scaleAnimator != nil {
            return
        }
        
        startNewAnimation(newParams)
        pendingAnimParams = nil
    }
    
    private func calculateMinScale(_ volume: Int) -> Float {
        switch volume {
        case VolumeConstants.highVolume...: return ScaleConstants.scaleHigh
        case VolumeConstants.mediumVolume...: return ScaleConstants.scaleMedium
        case VolumeConstants.lowVolume...: return ScaleConstants.scaleLow
        default: return ScaleConstants.scaleLow
        }
    }
    
    private func calculateDuration(_ volume: Int) -> TimeInterval {
        switch volume {
        case VolumeConstants.highVolume...: return AnimationConstants.durationHigh
        case VolumeConstants.mediumVolume...: return AnimationConstants.durationMedium
        case VolumeConstants.lowVolume...: return AnimationConstants.durationLow
        default: return AnimationConstants.durationLow
        }
    }
    
    private func startNewAnimation(_ params: AnimParams) {
        currentAnimParams = params
        
        let group = CAAnimationGroup()
        group.animations = createAnimationSequence(params)
        group.duration = params.duration
        group.delegate = self
        group.repeatCount = 1
        group.beginTime = CACurrentMediaTime()
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        scaleAnimator = group
        videoView?.layer.add(group, forKey: "sizeAnimation")
    }
    
    private func createAnimationSequence(_ params: AnimParams) -> [CAAnimation] {
        let quarterDuration = params.duration / 4
        
        let scaleDown = CABasicAnimation(keyPath: "transform.scale")
        scaleDown.fromValue = 1.0
        scaleDown.toValue = params.minScale
        scaleDown.duration = quarterDuration
        scaleDown.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let scaleUp1 = CABasicAnimation(keyPath: "transform.scale")
        scaleUp1.fromValue = params.minScale
        scaleUp1.toValue = params.minScale + AnimationConstants.bounceScale
        scaleUp1.duration = quarterDuration
        scaleUp1.beginTime = quarterDuration
        scaleUp1.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        let scaleDown2 = CABasicAnimation(keyPath: "transform.scale")
        scaleDown2.fromValue = params.minScale + AnimationConstants.bounceScale
        scaleDown2.toValue = params.minScale
        scaleDown2.duration = quarterDuration
        scaleDown2.beginTime = quarterDuration * 2
        scaleDown2.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let scaleUp2 = CABasicAnimation(keyPath: "transform.scale")
        scaleUp2.fromValue = params.minScale
        scaleUp2.toValue = 1.0
        scaleUp2.duration = quarterDuration
        scaleUp2.beginTime = quarterDuration * 3
        scaleUp2.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        return [scaleDown, scaleUp1, scaleDown2, scaleUp2]
    }
    
    private func updateParentScale(_ scale: Float) {
        if let parentView = videoView?.superview {
            parentView.transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        }
    }
    
    func releaseView() {
        rtcMediaPlayer?.stop()
        rtcEngine?.destroyMediaPlayer(rtcMediaPlayer)
        rtcMediaPlayer = nil
        
        scaleAnimator = nil
        videoView?.layer.removeAllAnimations()
        currentState = .idle
    }
}

extension AnimateView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            if (anim.value(forKey: "shouldStop") as? Bool) == true {
                videoView?.layer.removeAllAnimations()
                scaleAnimator = nil
                return
            }
            
            if currentState != .speaking {
                videoView?.layer.removeAllAnimations()
                scaleAnimator = nil
                return
            }
            
            if let params = pendingAnimParams {
                startNewAnimation(params)
                pendingAnimParams = nil
            } else {
                startNewAnimation(currentAnimParams)
            }
        }
    }
}

extension AnimateView: AgoraRtcMediaPlayerDelegate {
    func AgoraRtcMediaPlayer(_ playerKit: any AgoraRtcMediaPlayerProtocol, didPreloadEvent event: AgoraMediaPlayerPreloadEvent) {
        ConvoAILogger.info("onPreloadEvent : \(event)")
        if event == .error {
            delegate?.onError(error: ConvoAIError.unknownError(message: "video preload error: \(event)"))
        }
    }
    
    func AgoraRtcMediaPlayer(_ playerKit: any AgoraRtcMediaPlayerProtocol, didChangedTo state: AgoraMediaPlayerState, reason: AgoraMediaPlayerReason) {
        if state == .openCompleted {
            rtcMediaPlayer?.mute(true)
            rtcMediaPlayer?.setPlaybackSpeed(100)
            rtcMediaPlayer?.play()
            
            // Preload the second video
            if let filePath = Bundle.main.path(forResource: AnimationConstants.videoFileName, ofType: nil) {
                let source = AgoraMediaSource()
                source.url = filePath
                rtcMediaPlayer?.preloadSrc(filePath, startPos: 0)
            }
        } else if state == .playBackAllLoopsCompleted {
            // Switch to the second video
            if let filePath = Bundle.main.path(forResource: AnimationConstants.videoFileName, ofType: nil) {
                rtcMediaPlayer?.playPreloadedSrc(filePath)
                rtcMediaPlayer?.mute(true)
                rtcMediaPlayer?.setPlaybackSpeed(100)
                rtcMediaPlayer?.setLoopCount(-1)
            }
        } else if state == .failed {
            delegate?.onError(error: ConvoAIError.unknownError(message: "play video error: \(state)"))
        }
    }
}
