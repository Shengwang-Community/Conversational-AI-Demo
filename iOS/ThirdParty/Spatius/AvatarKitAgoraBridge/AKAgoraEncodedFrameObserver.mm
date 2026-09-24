#import "AvatarKitAgoraBridge.h"

#import <AgoraRtcKit/AgoraRtcEngineKit.h>
#import <AgoraRtcKit/IAgoraRtcEngine.h>
#import <AgoraRtcKit/IAgoraMediaEngine.h>
#import <AgoraRtcKit/AgoraMediaBase.h>

namespace {

class EncodedFrameRelay : public agora::media::IVideoEncodedFrameObserver {
public:
    explicit EncodedFrameRelay(AKAgoraEncodedFrameObserver *owner) : owner_(owner) {}

    // RTC 4.6.4 includes channelId in the native observer callback. The host owns
    // one channel; preserve the upstream UID/data forwarding behavior.
    bool onEncodedVideoFrameReceived(const char* channelId,
                                     agora::rtc::uid_t uid,
                                     const uint8_t *imageBuffer,
                                     size_t length,
                                     const agora::rtc::EncodedVideoFrameInfo &info) override {
        if (imageBuffer == nullptr || length == 0) return true;

        // Copy into NSData — the buffer is only valid for the duration of this call.
        NSData *data = [NSData dataWithBytes:imageBuffer length:length];
        AKAgoraEncodedFrameHandler handler = owner_.handler;
        if (handler) {
            handler(data, (NSUInteger)uid, (int64_t)info.captureTimeMs);
        }
        return true;
    }

private:
    __weak AKAgoraEncodedFrameObserver *owner_;
};

}  // namespace

@implementation AKAgoraEncodedFrameObserver {
    std::unique_ptr<EncodedFrameRelay> _relay;
    agora::media::IMediaEngine *_mediaEngine;
}

- (BOOL)attachToEngine:(AgoraRtcEngineKit *)engine {
    if (engine == nil) return NO;
    void *nativeHandle = [engine getNativeHandle];
    if (nativeHandle == nullptr) return NO;

    auto *rtcEngine = static_cast<agora::rtc::IRtcEngine *>(nativeHandle);
    agora::media::IMediaEngine *mediaEngine = nullptr;
    int rc = rtcEngine->queryInterface(agora::rtc::AGORA_IID_MEDIA_ENGINE,
                                       reinterpret_cast<void **>(&mediaEngine));
    if (rc != 0 || mediaEngine == nullptr) return NO;

    _relay = std::make_unique<EncodedFrameRelay>(self);
    _mediaEngine = mediaEngine;
    int regRc = mediaEngine->registerVideoEncodedFrameObserver(_relay.get());
    return regRc == 0;
}

- (void)detach {
    if (_mediaEngine && _relay) {
        _mediaEngine->registerVideoEncodedFrameObserver(nullptr);
    }
    _relay.reset();
    _mediaEngine = nullptr;
}

- (void)dealloc {
    [self detach];
}

@end
