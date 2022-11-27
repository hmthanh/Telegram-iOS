import Foundation
import UIKit
import ComponentFlow
import ActivityIndicatorComponent
import AccountContext
import AVKit
import MultilineTextComponent
import Display

import TelegramCore

typealias MediaStreamVideoComponent = _MediaStreamVideoComponent

final class _MediaStreamVideoComponent: Component {
    let call: PresentationGroupCallImpl
    let hasVideo: Bool
    let isVisible: Bool
    let isAdmin: Bool
    let peerTitle: String
    let activatePictureInPicture: ActionSlot<Action<Void>>
    let deactivatePictureInPicture: ActionSlot<Void>
    let bringBackControllerForPictureInPictureDeactivation: (@escaping () -> Void) -> Void
    let pictureInPictureClosed: () -> Void
    let peerImage: Any?
    let isFullscreen: Bool
    let onVideoSizeRetrieved: (CGSize) -> Void
    init(
        call: PresentationGroupCallImpl,
        hasVideo: Bool,
        isVisible: Bool,
        isAdmin: Bool,
        peerTitle: String,
        peerImage: Any?,
        isFullscreen: Bool,
        activatePictureInPicture: ActionSlot<Action<Void>>,
        deactivatePictureInPicture: ActionSlot<Void>,
        bringBackControllerForPictureInPictureDeactivation: @escaping (@escaping () -> Void) -> Void,
        pictureInPictureClosed: @escaping () -> Void,
        onVideoSizeRetrieved: @escaping (CGSize) -> Void
    ) {
        self.call = call
        self.hasVideo = hasVideo
        self.isVisible = isVisible
        self.isAdmin = isAdmin
        self.peerTitle = peerTitle
        self.activatePictureInPicture = activatePictureInPicture
        self.deactivatePictureInPicture = deactivatePictureInPicture
        self.bringBackControllerForPictureInPictureDeactivation = bringBackControllerForPictureInPictureDeactivation
        self.pictureInPictureClosed = pictureInPictureClosed
        
        self.peerImage = peerImage
        self.isFullscreen = isFullscreen
        self.onVideoSizeRetrieved = onVideoSizeRetrieved
    }
    
    public static func ==(lhs: _MediaStreamVideoComponent, rhs: _MediaStreamVideoComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.hasVideo != rhs.hasVideo {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.isAdmin != rhs.isAdmin {
            return false
        }
        if lhs.peerTitle != rhs.peerTitle {
            return false
        }
        
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        
        return true
    }
    
    public final class State: ComponentState {
        override init() {
            super.init()
        }
    }
    
    public func makeState() -> State {
        return State()
    }
    
    public final class View: UIView, AVPictureInPictureControllerDelegate, ComponentTaggedView {
        public final class Tag {
        }
        
        private let videoRenderingContext = VideoRenderingContext()
        private let blurTintView: UIView
        private var videoBlurView: VideoRenderingView?
        private var videoView: VideoRenderingView?
        private var activityIndicatorView: ComponentHostView<Empty>?
        private var loadingView: ComponentHostView<Empty>?
        
        private var videoPlaceholderView: UIView?
        private var noSignalView: ComponentHostView<Empty>?
        
        private var pictureInPictureController: AVPictureInPictureController?
        
        private var component: _MediaStreamVideoComponent?
        private var hadVideo: Bool = false
        
        private var requestedExpansion: Bool = false
        
        private var noSignalTimer: Timer?
        private var noSignalTimeout: Bool = false
        
        private weak var state: State?
        
        override init(frame: CGRect) {
            self.blurTintView = UIView()
            self.blurTintView.backgroundColor = UIColor(white: 0.0, alpha: 0.55)
            super.init(frame: frame)
            
//            self.backgroundColor = UIColor.green.withAlphaComponent(0.4)
            self.isUserInteractionEnabled = false
            self.clipsToBounds = true
            
            self.addSubview(self.blurTintView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        func expandFromPictureInPicture() {
            if let pictureInPictureController = self.pictureInPictureController, pictureInPictureController.isPictureInPictureActive {
                self.requestedExpansion = true
                self.pictureInPictureController?.stopPictureInPicture()
            }
        }
        let maskGradientLayer = CAGradientLayer()
        private var wasVisible = true
        
        func update(component: _MediaStreamVideoComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            self.state = state
            /*let groupPeer = component.call.accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.call.peerId))
            let _ = groupPeer.start(next: { peer in
                switch peer {
                case let .channel(channel):
                    let photo = channel.photo
                    photo[0].resource.
                    print(photo)
                default: break
                }
                let tileShimmer = VoiceChatTileShimmeringNode(account: component.call.account, peer: peer!._asPeer())
            })*/
            
            if component.hasVideo, self.videoView == nil {
//                self.addSubview(sheetBackdropView)
//                self.addSubview(sheetView)
                
                if let input = component.call.video(endpointId: "unified") {
                    if let videoBlurView = self.videoRenderingContext.makeView(input: input, blur: true) {
                        self.videoBlurView = videoBlurView
                        self.insertSubview(videoBlurView, belowSubview: self.blurTintView)
                        
                        self.maskGradientLayer.type = .radial
                        self.maskGradientLayer.colors = [UIColor(rgb: 0x000000, alpha: 0.5).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
                        self.maskGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
                        self.maskGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
//                        self.maskGradientLayer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0)
//                        self.maskGradientLayer.isHidden = true
                        
                    }

                    
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false, forceSampleBufferDisplayLayer: true) {
                        self.videoView = videoView
                        self.addSubview(videoView)
                        videoView.alpha = 1
                        if let sampleBufferVideoView = videoView as? SampleBufferVideoRenderingView {
                            if #available(iOS 13.0, *) {
                                sampleBufferVideoView.sampleBufferLayer.preventsDisplaySleepDuringVideoPlayback = true
                            }
//                            if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported() {
                                final class PlaybackDelegateImpl: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
                                    var onTransitionFinished: (() -> Void)?
                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
                                        
                                    }

                                    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
                                        return CMTimeRange(start: .zero, duration: .positiveInfinity)
                                    }

                                    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
                                        return false
                                    }

                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
                                        onTransitionFinished?()
                                        print("pip finished")
                                    }

                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
                                        completionHandler()
                                    }

                                    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
                                        return false
                                    }
                                }
                            var pictureInPictureController: AVPictureInPictureController? = nil
                            if #available(iOS 15.0, *) {
                                pictureInPictureController = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferVideoView.sampleBufferLayer, playbackDelegate: {
                                    let delegate = PlaybackDelegateImpl()
                                    delegate.onTransitionFinished = { [weak self] in
                                        if self?.videoView?.alpha == 0 {
//                                            self?.videoView?.alpha = 1
                                        }
                                    }
                                    return delegate
                                }()))
                            } else if AVPictureInPictureController.isPictureInPictureSupported() {
                                // TODO: support PiP for iOS < 15.0
                                // sampleBufferVideoView.sampleBufferLayer
                                pictureInPictureController = AVPictureInPictureController.init(playerLayer: AVPlayerLayer(player: AVPlayer()))
                            }
                                
                                pictureInPictureController?.delegate = self
                            if #available(iOS 14.2, *) {
                                pictureInPictureController?.canStartPictureInPictureAutomaticallyFromInline = true
                            }
                            if #available(iOS 14.0, *) {
                                pictureInPictureController?.requiresLinearPlayback = true
                            }
                                
                                self.pictureInPictureController = pictureInPictureController
//                            }
                        }
                        
                        videoView.setOnOrientationUpdated { [weak state] _, _ in
                            state?.updated(transition: .immediate)
                        }
                        videoView.setOnFirstFrameReceived { [weak self, weak state] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.hadVideo = true
                            
                            strongSelf.activityIndicatorView?.removeFromSuperview()
                            strongSelf.activityIndicatorView = nil
                            
                            strongSelf.noSignalTimer?.invalidate()
                            strongSelf.noSignalTimer = nil
                            strongSelf.noSignalTimeout = false
                            strongSelf.noSignalView?.removeFromSuperview()
                            strongSelf.noSignalView = nil
                            
                            state?.updated(transition: .immediate)
                        }
                    }
                }
            }
            
//            sheetView.frame = .init(x: 0, y: sheetTop, width: availableSize.width, height: sheetHeight)
           // var aspect = videoView.getAspect()
//                if aspect <= 0.01 {
            // let aspect = !component.isFullscreen ? 16.0 / 9.0 : // 3.0 / 4.0
//                }
            
            let videoInset: CGFloat
            if !component.isFullscreen {
                videoInset = 16
            } else {
                videoInset = 0
            }
            
            if let videoView = self.videoView {
                var aspect = videoView.getAspect()
                // saveAspect(aspect)
                if component.isFullscreen {
                    if aspect <= 0.01 {
                        aspect = 3.0 / 4.0
                    }
                } else {
                    aspect = 16.0 / 9
                }
                
                let videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
                let blurredVideoSize = videoSize.aspectFilled(availableSize)
                
                component.onVideoSizeRetrieved(videoSize)
                
                var isVideoVisible = component.isVisible
                
                if !wasVisible && component.isVisible {
                    videoView.layer.animateAlpha(from: 0, to: 1, duration: 0.2)
                } else if wasVisible && !component.isVisible {
                    videoView.layer.animateAlpha(from: 1, to: 0, duration: 0.2)
                }
                
                if let pictureInPictureController = self.pictureInPictureController {
                    if pictureInPictureController.isPictureInPictureActive {
                        isVideoVisible = true
                    }
                }
                
                videoView.updateIsEnabled(isVideoVisible)
                videoView.clipsToBounds = true
                videoView.layer.cornerRadius = component.isFullscreen ? 0 : 10
              //  var aspect = videoView.getAspect()
//                if aspect <= 0.01 {
                
                
                transition.withAnimation(.none).setFrame(view: videoView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize), completion: nil)
                
                if let videoBlurView = self.videoBlurView {
                    videoBlurView.updateIsEnabled(component.isVisible)
//                    videoBlurView.isHidden = component.isFullscreen
                    if component.isFullscreen {
                        transition.withAnimation(.none).setFrame(view: videoBlurView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - blurredVideoSize.width) / 2.0), y: floor((availableSize.height - blurredVideoSize.height) / 2.0)), size: blurredVideoSize), completion: nil)
                    } else {
                        videoBlurView.frame = videoView.frame.insetBy(dx: -69 * aspect, dy: -69)
                    }
                    
                    if !component.isFullscreen {
                        videoBlurView.layer.mask = maskGradientLayer
                    } else {
                        videoBlurView.layer.mask = nil
                    }
                    
                    self.maskGradientLayer.frame = videoBlurView.bounds// CGRect(x: videoBlurView.bounds.midX, y: videoBlurView.bounds.midY, width: videoBlurView.bounds.width, height: videoBlurView.bounds.height)
                }
            }
            
            if !self.hadVideo {
                // TODO: hide fullscreen button without video
                let aspect: CGFloat = 16.0 / 9
                let videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
                // loadingpreview.frame = .init(, videoSize)
                print(videoSize)
                // TODO: remove activity indicator
                var activityIndicatorTransition = transition
                let activityIndicatorView: ComponentHostView<Empty>
                if let current = self.activityIndicatorView {
                    activityIndicatorView = current
                } else {
                    activityIndicatorTransition = transition.withAnimation(.none)
                    activityIndicatorView = ComponentHostView<Empty>()
                    self.activityIndicatorView = activityIndicatorView
                    self.addSubview(activityIndicatorView)
                }
                
                let activityIndicatorSize = activityIndicatorView.update(
                    transition: transition,
                    component: AnyComponent(ActivityIndicatorComponent(color: .white)),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let activityIndicatorFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - activityIndicatorSize.width) / 2.0), y: floor((availableSize.height - activityIndicatorSize.height) / 2.0)), size: activityIndicatorSize)
                activityIndicatorTransition.setFrame(view: activityIndicatorView, frame: activityIndicatorFrame, completion: nil)
                
                if self.noSignalTimer == nil {
                    if #available(iOS 10.0, *) {
                        let noSignalTimer = Timer(timeInterval: 20.0, repeats: false, block: { [weak self] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.noSignalTimeout = true
                            strongSelf.state?.updated(transition: .immediate)
                        })
                        self.noSignalTimer = noSignalTimer
                        RunLoop.main.add(noSignalTimer, forMode: .common)
                    }
                }
                
                if self.noSignalTimeout {
                    var noSignalTransition = transition
                    let noSignalView: ComponentHostView<Empty>
                    if let current = self.noSignalView {
                        noSignalView = current
                    } else {
                        noSignalTransition = transition.withAnimation(.none)
                        noSignalView = ComponentHostView<Empty>()
                        self.noSignalView = noSignalView
                        self.addSubview(noSignalView)
                        noSignalView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    
                    let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with { $0 }
                    let noSignalSize = noSignalView.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: component.isAdmin ? presentationData.strings.LiveStream_NoSignalAdminText :  presentationData.strings.LiveStream_NoSignalUserText(component.peerTitle).string, font: Font.regular(16.0), textColor: .white, paragraphAlignment: .center)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 1000.0)
                    )
                    noSignalTransition.setFrame(view: noSignalView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - noSignalSize.width) / 2.0), y: activityIndicatorFrame.maxY + 24.0), size: noSignalSize), completion: nil)
                }
            }
            
            self.component = component
            
            component.activatePictureInPicture.connect { [weak self] completion in
                guard let strongSelf = self, let pictureInPictureController = strongSelf.pictureInPictureController else {
                    return
                }
                
                pictureInPictureController.startPictureInPicture()
                
                completion(Void())
            }
            
            component.deactivatePictureInPicture.connect { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.expandFromPictureInPicture()
            }
            
            return availableSize
        }
        
        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            guard let component = self.component else {
                completionHandler(false)
                return
            }

            component.bringBackControllerForPictureInPictureDeactivation {
                completionHandler(true)
            }
        }
        
        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            self.state?.updated(transition: .immediate)
        }
        
        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            if self.requestedExpansion {
                self.requestedExpansion = false
            } else {
                self.component?.pictureInPictureClosed()
            }
        }
        
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            self.state?.updated(transition: .immediate)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}
