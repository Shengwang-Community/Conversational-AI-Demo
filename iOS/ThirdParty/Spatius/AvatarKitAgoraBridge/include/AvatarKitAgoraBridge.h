#import <Foundation/Foundation.h>

@class AgoraRtcEngineKit;

NS_ASSUME_NONNULL_BEGIN

/// Callback fired on Agora's encoded-frame thread for every received encoded
/// video frame. `nalData` is the raw H.264/H.265 bitstream bytes coming off the
/// network — the caller is responsible for slicing NAL units and extracting
/// SEI payloads.
/// @param captureTimeMs when the server produced the frame, from Agora's
///   encoded-frame info. Advances with the send order, which is what lets a
///   genuinely-final idle packet be told from one that merely arrived late.
typedef void (^AKAgoraEncodedFrameHandler)(NSData *nalData, NSUInteger uid, int64_t captureTimeMs);

/// ObjC wrapper that owns a C++ IVideoEncodedFrameObserver and forwards every
/// received encoded frame to a Swift block.
///
/// Agora iOS 4.6.x does not expose an Objective-C delegate for received H.264
/// SEI. The only public path that surfaces the raw encoded bitstream is the
/// C++ `IVideoEncodedFrameObserver`, registered via
/// `IMediaEngine::registerVideoEncodedFrameObserver`. This wrapper bridges
/// that into something Swift can consume.
@interface AKAgoraEncodedFrameObserver : NSObject

/// Block invoked for every received encoded frame. Runs on Agora's internal
/// thread — hop to your queue before doing work.
@property (nonatomic, copy, nullable) AKAgoraEncodedFrameHandler handler;

/// Register the underlying C++ observer with the given engine.
/// Returns YES on success.
- (BOOL)attachToEngine:(AgoraRtcEngineKit *)engine;

/// Unregister and tear down the observer.
- (void)detach;

@end

NS_ASSUME_NONNULL_END
