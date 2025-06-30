import AgoraRTC, {
  IAgoraRTCClient,
  IMicrophoneAudioTrack,
  UID,
  type NetworkQuality,
  type IAgoraRTCRemoteUser,
  type ConnectionState,
  DeviceInfo,
} from "agora-rtc-sdk-ng";
import {
  AIDenoiserExtension,
  AIDenoiserProcessorLevel,
  type IAIDenoiserProcessor,
} from "agora-conversational-ai-denoiser";

import { getAgentToken } from "@/services/agent";
import {
  IUserTracks,
  NotFoundError,
  ERTCEvents,
  ERTCCustomEvents,
  IHelperRTCEvents,
} from "@/conversational-ai-api/type";
import { EventHelper } from "@/conversational-ai-api/utils/event";

export class RTCHelper extends EventHelper<
  IHelperRTCEvents & {
    [ERTCCustomEvents.MICROPHONE_CHANGED]: (info: DeviceInfo) => void;
    [ERTCCustomEvents.REMOTE_USER_CHANGED]: (user: IAgoraRTCRemoteUser) => void;
    [ERTCCustomEvents.REMOTE_USER_JOINED]: (user: { userId: UID }) => void;
    [ERTCCustomEvents.REMOTE_USER_LEFT]: (user: {
      userId: UID;
      reason?: string;
    }) => void;
    [ERTCCustomEvents.LOCAL_TRACKS_CHANGED]: (tracks: {
      audioTrack?: IMicrophoneAudioTrack;
    }) => void;
  }
> {
  static NAME = "RTCHelper";
  static VERSION = "1.0.0";
  private static _instance: RTCHelper;

  public client: IAgoraRTCClient;
  private joined: boolean = false;
  public agoraRTC: typeof AgoraRTC;
  public localTracks: IUserTracks = {};
  public appId: string | null = null;
  public token: string | null = null;
  public channelName: string | null = null;
  public userId: string | null = null;
  private processor: IAIDenoiserProcessor | null = null;
  private _messageServiceMode: "default" | "legacy" = "default";

  constructor() {
    super();

    this.agoraRTC = AgoraRTC;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (AgoraRTC as any).setParameter("ENABLE_AUDIO_PTS_METADATA", true);
    // // eslint-disable-next-line @typescript-eslint/no-explicit-any
    // ;(AgoraRTC as any).setParameter('ENABLE_AUDIO_RED', true)
    // // eslint-disable-next-line @typescript-eslint/no-explicit-any
    // ;(AgoraRTC as any).setParameter('EXPERIMENTS', { enableChorusMode: true })

    AgoraRTC.enableLogUpload();
    this.client = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });
  }

  public static getInstance(): RTCHelper {
    if (!RTCHelper._instance) {
      RTCHelper._instance = new RTCHelper();
    }
    return RTCHelper._instance;
  }

  public async retrieveToken(
    userId: string | number,
    channel?: string,
    force?: boolean,
    options?: { devMode?: boolean }
  ) {
    if (!force && this.appId && this.token) {
      return;
    }
    // get appId and token from server
    console.log({ channel, userId }, "Retrieving token");
    try {
      const resData = await getAgentToken(`${userId}`, channel, options);
      this.appId = resData.data.appId;
      this.token = resData.data.token;
      this.channelName = channel ?? null;
    } catch (error) {
      console.error("Failed to retrieve token", error);
      throw new Error("Failed to retrieve token");
    }
  }

  public async join({
    channel,
    userId,
    options,
  }: {
    channel: string;
    userId: number;
    options?: { devMode?: boolean };
  }) {
    if (this.joined) {
      console.log({ channel, userId }, "Already initialized");
      return;
    }
    this.bindRtcEvents();
    this.channelName = channel;
    if (!this.appId || !this.token) {
      await this.retrieveToken(userId, undefined, false, options);
    }
    // // set client role as host
    // this.client.setClientRole('host')
    // join the channel
    await this.client.join(
      this.appId as string,
      channel,
      this.token as string,
      userId
    );
    console.log({ channel, userId }, "Joined channel");
    this.joined = true;
  }

  public async initDenoiserProcessor(
    assetsPath = "/denoiser/external"
  ): Promise<void> {
    if (this.processor) {
      console.log("[DenoiserProcessor]", "Already initialized");
      return;
    }
    console.log("[DenoiserProcessor]", "Initializing");
    const denoiser = new AIDenoiserExtension({
      assetsPath,
    });
    // Check compatibility
    if (!denoiser.checkCompatibility()) {
      // Current browser may not support AI denoiser plugin, stop further execution
      console.error("[DenoiserProcessor]", "Does not support AI Denoiser!");
    } else {
      // Register plugin
      this.agoraRTC.registerExtensions([denoiser]);
      // Listen for Wasm file loading failure events, possible reasons include incorrect Wasm file path
      denoiser.onloaderror = async () => {
        // If Wasm file fails to load, you can disable the plugin, for example:
        // openDenoiserButton.enabled = false;
        console.error("[DenoiserProcessor]", "Failed to load AI Denoiser!");
        try {
          await this.processor?.disable();
        } catch (error) {
          console.error(
            "[DenoiserProcessor]",
            "Failed to disable AI Denoiser!",
            error
          );
        }
      };
      // Create IAIDenoiserProcessor instance
      const processor = denoiser.createProcessor();
      this.processor = processor;
      // Enable plugin by default
      await this.processor.enable();
      console.log("[DenoiserProcessor]", "Initialized");
    }
  }

  // must be called after pipe processor
  public async setDenoiserProcessorLevel(
    level: AIDenoiserProcessorLevel = "AGGRESSIVE"
  ) {
    try {
      console.log("[DenoiserProcessor]", "setLevel", level);
      if (this.processor) {
        await this.processor.setLevel(level);
        console.log("[DenoiserProcessor]", "setLevel", level, "success");
      }
    } catch (error) {
      console.error(
        "[DenoiserProcessor]",
        error,
        "Failed to set denoise level"
      );
    }
  }

  public async enableDenoiserProcessor() {
    console.log("[DenoiserProcessor]", "prev", this.processor?.enabled);
    if (this.processor && !this.processor.enabled) {
      await this.processor.enable();
      console.log("[DenoiserProcessor]", "enable success");
    }
  }

  public async disableDenoiserProcessor() {
    console.log("[DenoiserProcessor]", "prev", this.processor?.enabled);
    if (this.processor && this.processor.enabled) {
      await this.processor.disable();
    }
  }

  public async createTracks() {
    try {
      const audioTrack = await AgoraRTC.createMicrophoneAudioTrack({
        AEC: true,
        ANS: false,
        AGC: true,
      });
      if (this.processor) {
        console.log(
          "[createTracks]",
          "[DenoiserProcessor]",
          "pipe processor",
          !!this.processor
        );
        audioTrack.pipe(this.processor).pipe(audioTrack.processorDestination);
        // // close ains.agc
        // // eslint-disable-next-line @typescript-eslint/no-explicit-any
        // ;(this.processor as any).setParameter({ agcConfig: { enabled: false } })
      }
      this.localTracks.audioTrack = audioTrack;
      // must be called after pipe processor
      await this.setDenoiserProcessorLevel();
    } catch (error) {
      console.error(error, "Failed to create tracks");
      // console.error( JSON.stringify(error), 'Failed to create tracks')
    } finally {
      this.emit(ERTCCustomEvents.LOCAL_TRACKS_CHANGED, this.localTracks);
      return this.localTracks;
    }
  }

  public async publishTracks() {
    if (!this.client) {
      throw new NotFoundError("RTC client is not initialized");
    }
    const tracks = [];
    if (this.localTracks.audioTrack) {
      tracks.push(this.localTracks.audioTrack);
    }
    if (tracks.length) {
      await this.client.publish(tracks);
    }
  }

  public resetMicVolume() {
    this.localTracks.audioTrack?.setVolume(0);
    console.log("Reset mic volume");
  }

  public async exitAndCleanup() {
    try {
      this.localTracks?.audioTrack?.close();
    } catch (error) {
      console.error(error, "Failed to destroy tracks");
    }
    //console.log('Leaving channel')
    this.localTracks = {};
    this.joined = false;
    try {
      await this.client?.leave();
    } catch (error) {
      console.error(error, "Failed to leave channel");
    }
  }

  private bindRtcEvents() {
    // microphone changed
    this.agoraRTC.onMicrophoneChanged = async (info: DeviceInfo) => {
      console.log("cjtest RTC event onMicrophoneChanged", info);
      this.emit(ERTCCustomEvents.MICROPHONE_CHANGED, info);
      await this._eHandleMicrophoneChanged(info);
    };
    // audio metadata (pts)
    this.client.on(
      ERTCEvents.AUDIO_METADATA,
      this._eHandleAudioMetadata.bind(this)
    );
    // rtc network quality
    this.client.on(
      ERTCEvents.NETWORK_QUALITY,
      this._eHandleNetworkQuality.bind(this)
    );
    // user published
    this.client.on(
      ERTCEvents.USER_PUBLISHED,
      this._eHandleUserPublished.bind(this)
    );
    // user unpublished
    this.client.on(
      ERTCEvents.USER_UNPUBLISHED,
      this._eHandleUserUnpublished.bind(this)
    );
    // stream data
    this.client.on(
      ERTCEvents.STREAM_MESSAGE,
      this._eHandleStreamMessage.bind(this)
    );
    // user joined
    this.client.on(ERTCEvents.USER_JOINED, this._eHandleUserJoined.bind(this));
    // user left
    this.client.on(ERTCEvents.USER_LEFT, this._eHandleUserLeft.bind(this));
    // connection state change
    this.client.on(
      ERTCEvents.CONNECTION_STATE_CHANGE,
      this._eHandleConnectionStateChange.bind(this)
    );
  }

  private async _eHandleMicrophoneChanged(changedDevice: DeviceInfo) {
    console.log("[microphone-changed]", changedDevice);
    const microphoneTrack = this.localTracks.audioTrack;
    console.log(
      "cjtest microphoneTrack has microphoneTrack:",
      !!microphoneTrack,
      "changedDevice",
      changedDevice
    );
    if (!microphoneTrack) {
      return;
    }
    if (changedDevice.state === "ACTIVE") {
      microphoneTrack.setDevice(changedDevice.device.deviceId);
      return;
    }
    console.log(
      "cjtest microphoneTrack.getTrackLabel()",
      changedDevice.device.label,
      microphoneTrack.getTrackLabel()
    );
    const oldMicrophones = await this.agoraRTC.getMicrophones();
    if (oldMicrophones[0]) {
      microphoneTrack.setDevice(oldMicrophones[0].deviceId);
    }
  }

  private _eHandleAudioMetadata(metadata: Uint8Array) {
    // console.log('[audio-metadata]', metadata)
    // try {
    //   const pts64 = Number(new DataView(metadata.buffer).getBigUint64(0, true))
    //   console.log('[audio-metadata]', pts64)
    //   this.subtitle.setPts(pts64)
    // } catch (error) {
    //   console.error('[audio-metadata]', error, 'Failed to parse audio metadata')
    // }
    this.emit(ERTCEvents.AUDIO_METADATA, metadata);
  }

  private async _eHandleNetworkQuality(quality: NetworkQuality) {
    console.log("[network-quality]", quality);
    this.emit(ERTCEvents.NETWORK_QUALITY, quality);
  }

  private async _eHandleUserPublished(
    user: IAgoraRTCRemoteUser,
    mediaType: "audio" | "video"
  ) {
    console.log(
      {
        userId: user.uid,
        mediaType,
      },
      "[user-published] subscribing to user"
    );
    await this.client.subscribe(user, mediaType);
    if (
      mediaType === "audio" &&
      user.audioTrack &&
      !user.audioTrack.isPlaying
    ) {
      console.log(
        {
          userId: user.uid,
        },
        "[user-published] remote mediaType audio"
      );
      // user.audioTrack?.setVolume(80)
      user.audioTrack.play();
    }
    // emit event
    this.emit(ERTCCustomEvents.REMOTE_USER_CHANGED, user);
  }

  private async _eHandleUserUnpublished(
    user: IAgoraRTCRemoteUser,
    mediaType: "audio" | "video"
  ) {
    console.log(
      {
        userId: user.uid,
        mediaType,
      },
      "[user-unpublished] unsubscribing from user"
    );
    // !SPECIAL CASE[unsubscribe]
    // when remote agent joined, it will frequently unsubscribe and resubscribe in short time
    // so we don't unsubscribe it
    // await this.client.unsubscribe(user, mediaType)
    // this.emit(ERTCServicesEvents.REMOTE_USER_CHANGED, {
    //   userId: user.uid,
    //   audioTrack: user.audioTrack,
    // })
  }

  private _eHandleStreamMessage(
    user: IAgoraRTCRemoteUser,
    message: string | Uint8Array
  ) {
    console.log(
      {
        user: user,
        message,
      },
      "[stream-message] received message"
    );
    this.emit(ERTCEvents.STREAM_MESSAGE, user, message);
  }

  private _eHandleUserJoined(user: IAgoraRTCRemoteUser) {
    console.log(
      {
        userId: user.uid,
      },
      "user joined"
    );
    this.emit(ERTCCustomEvents.REMOTE_USER_JOINED, {
      userId: user.uid,
    });
  }

  private _eHandleUserLeft(user: IAgoraRTCRemoteUser, reason?: string) {
    console.log(
      {
        userId: user.uid,
        reason,
      },
      "user left"
    );
    this.emit(ERTCCustomEvents.REMOTE_USER_LEFT, {
      userId: user.uid,
      reason,
    });
  }

  private _eHandleConnectionStateChange(
    curState: ConnectionState,
    revState: ConnectionState,
    reason: string
  ) {
    const curChannelName = this.client.channelName;
    console.log(
      "connection state change",
      curState,
      revState,
      reason,
      curChannelName
    );
    this.emit(ERTCEvents.CONNECTION_STATE_CHANGE, {
      curState,
      revState,
      reason,
      channel: curChannelName,
    });
  }
}
