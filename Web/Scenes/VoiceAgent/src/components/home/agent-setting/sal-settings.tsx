'use client'

import { ArrowRight, CircleCheckIcon, Mic, Triangle, XIcon } from 'lucide-react'
import { motion } from 'motion/react'
import NextImage from 'next/image'
import NextLink from 'next/link'
import { useFormatter, useTranslations } from 'next-intl'
import { Fragment, type RefObject, useEffect, useRef, useState } from 'react'
import { toast } from 'sonner'
import type z from 'zod'

import { SALSettingsWrapper } from '@/components/home/agent-setting/base'
import {
  LoadingSparkleIcon,
  RefreshIcon,
  VoiceIcon,
  VoicePrintIcon
} from '@/components/icon/agent'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from '@/components/ui/dialog'
import { Separator } from '@/components/ui/separator'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger
} from '@/components/ui/tooltip'
import { MAX_VALIDATE_TIME_MILLISECOND } from '@/constants'
import {
  POLICY_LINK,
  type publicAgentSettingSchema,
  SAL_BG_IMAGE
} from '@/constants/agent'
import { RTCHelper } from '@/conversational-ai-api/helper/rtc'
import { useIsDemoCalling } from '@/hooks/use-is-agent-calling'
import { encodePCM, encodeWAV } from '@/lib/pcm'
import { cn, isCN } from '@/lib/utils'
import { uploadFile } from '@/services/agent'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useRTCStore,
  useUserInfoStore
} from '@/store'
import { useAgentSalAudioStore } from '@/store/agent'
import { ESALSettingsMode } from '@/type/rtc'

const cn_record_material = [
  '君不见黄河之水天上来，',
  '奔流到海不复回。',
  '君不见高堂明镜悲白发，',
  '朝如青丝暮成雪。',
  '人生得意须尽欢，莫使金樽空对月。',
  '天生我材必有用，千金散尽还复来。'
] as const

const en_record_material = [
  'It was the best of times, it was the worst of times,',
  'it was the age of wisdom, it was the age of foolishness,',
  'it was the epoch of belief, it was the epoch of incredulity,'
] as const

const SALSettingsMode = [
  ESALSettingsMode.OFF,
  ESALSettingsMode.AUTO_LEARNING,
  ESALSettingsMode.MANUAL
]

export default function SALSettings() {
  const t = useTranslations('settings.advanced_features.enable_sal')

  const { settings } = useAgentSettingsStore()
  const { channel_name, remote_rtc_uid } = useRTCStore()
  const { accountUid } = useUserInfoStore()
  const { setShowSALSettingSidebar, showSALSettingSidebar } = useGlobalStore()
  const { updateSalAudioInfo, salAudioInfo } = useAgentSalAudioStore()
  const { onFormSetValue } = useAgentSettingsStore()
  const rtcHelper = RTCHelper.getInstance()
  const appId = rtcHelper.appId
  const formatter = useFormatter()

  const isDemoCalling = useIsDemoCalling()

  const uploadStatusRef = useRef<NodeJS.Timeout>(null)
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const ref = useRef<{
    chunks: Float32Array[]
    size: number
    recorder: ScriptProcessorNode
  }>(null)

  const [audioUrl, setAudioUrl] = useState<{
    file_url: string
    expired_ts: number
  } | null>(null)
  const [salMode, setSalMode] = useState<ESALSettingsMode>(
    settings.advanced_features.enable_sal
      ? settings.sal?.sample_urls?.[accountUid]
        ? ESALSettingsMode.MANUAL
        : ESALSettingsMode.AUTO_LEARNING
      : ESALSettingsMode.OFF
  )

  const [notRecordDialogOpen, setNotRecordDialogOpen] = useState(false)
  const [recordDialogOpen, setRecordDialogOpen] = useState<
    'record' | 'seamless' | null
  >(null)
  const [open, setOpen] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [uploadStatus, setUploadStatus] = useState<
    'idle' | 'succeed' | 'failed'
  >('idle')

  useEffect(() => {
    setSalMode(
      settings.advanced_features.enable_sal
        ? settings.sal?.sample_urls?.[remote_rtc_uid]
          ? ESALSettingsMode.MANUAL
          : ESALSettingsMode.AUTO_LEARNING
        : ESALSettingsMode.OFF
    )
  }, [showSALSettingSidebar])

  useEffect(() => {
    if (settings.advanced_features.enable_sal && !settings.sal) {
      setSalMode(ESALSettingsMode.AUTO_LEARNING)
    }
    if (!settings.advanced_features.enable_sal) {
      setSalMode(ESALSettingsMode.OFF)
    }
  }, [settings.advanced_features.enable_sal])

  // init audio url
  async function loadUrl(url: string, expired_ts: number) {
    const response = await fetch(url)
    const blob = await response.blob()
    const arrayBuffer = await blob.arrayBuffer()

    const wavDataview = encodeWAV(new DataView(arrayBuffer))
    const wavBlob = new Blob([wavDataview], { type: 'audio/wav' })
    const wavUrl = URL.createObjectURL(wavBlob)
    console.log('wavUrl', wavUrl)
    return { file_url: wavUrl, expired_ts }
  }

  useEffect(() => {
    const fileUrl = salAudioInfo?.[accountUid]?.file_url
    const expiredTs = salAudioInfo?.[accountUid]?.expired_ts
    if (
      !audioUrl &&
      fileUrl &&
      expiredTs &&
      expiredTs * 1000 > new Date().getTime()
    ) {
      loadUrl(fileUrl, expiredTs).then((v) => setAudioUrl(v))
    }
  }, [salAudioInfo?.[accountUid], audioUrl, accountUid])

  useEffect(() => {
    if (!audioRef.current) return
    if (isPlaying) {
      if (audioUrl) {
        audioRef.current.src = audioUrl.file_url
      }
      audioRef.current?.play()
    } else {
      audioRef.current?.pause()
    }
  }, [audioUrl, isPlaying])
  useEffect(() => {
    // 创建音频实例
    //
    const audio = new Audio()
    audioRef.current = audio

    // 添加事件监听
    // const handleTimeUpdate = () => {
    // 	const seconds = Math.floor(audio.currentTime);
    // 	const minutes = Math.floor(seconds / 60);
    // 	const remainingSeconds = seconds % 60;
    // };

    const handleEnded = () => {
      setIsPlaying(false)
      console.log('handleEnded')
    }

    const handleCanPlayThrough = () => {
      console.log('handleCanPlayThrough')
    }

    audio.addEventListener('canplaythrough', handleCanPlayThrough)
    // audio.addEventListener("timeupdate", handleTimeUpdate);
    audio.addEventListener('ended', handleEnded)

    return () => {
      // audio.removeEventListener("timeupdate", handleTimeUpdate);
      audio.removeEventListener('ended', handleEnded)
      audio.removeEventListener('canplaythrough', handleCanPlayThrough)
      audio.pause()
      audioRef.current = null
    }
  }, [])

  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone

  // uploading process
  useEffect(() => {
    if (isUploading) {
      if (
        ref.current?.chunks.length &&
        ref.current?.chunks.length > 0 &&
        ref.current?.size > 0 &&
        channel_name &&
        appId
      ) {
        // const blob = new Blob(, {type: 'audio/pcm'})
        const file = new File(
          [encodePCM(ref.current!.size, ref.current!.chunks)],
          'audio.pcm',
          { type: 'audio/pcm' }
        )

        setIsUploading(true)

        uploadFile(file, channel_name, appId)
          .then((data) => {
            console.log('fileUrl', data)
            const sal = {
              sal_mode: 'locking',
              sample_urls: {
                [remote_rtc_uid]: data.file_url
              }
            } as z.infer<typeof publicAgentSettingSchema>['sal']
            updateSalAudioInfo(data, accountUid)
            onFormSetValue?.('sal', sal)
            onFormSetValue?.('advanced_features.enable_sal', true)
            loadUrl(data.file_url, data.expired_ts).then((v) => setAudioUrl(v))
            setUploadStatus('succeed')
          })
          .catch((err) => {
            setUploadStatus('failed')
            console.log('uploadFile error', err)
          })
          .finally(() => {
            setIsUploading(false)
          })
      } else {
        console.log('uploadFile chunks is empty')
        setIsUploading(false)
        setUploadStatus('failed')
      }
    }
  }, [
    isUploading,
    accountUid,
    settings,
    updateSalAudioInfo,
    onFormSetValue,
    remote_rtc_uid,
    channel_name,
    appId
  ])

  useEffect(() => {
    if (uploadStatus === 'succeed') {
      uploadStatusRef.current = setTimeout(() => {
        setUploadStatus('idle')
        setOpen(false)
      }, 2000)
    }

    if (uploadStatusRef.current && uploadStatus === 'idle') {
      clearTimeout(uploadStatusRef.current)
      uploadStatusRef.current = null
    }

    return () => {
      if (uploadStatusRef.current) {
        clearTimeout(uploadStatusRef.current)
        uploadStatusRef.current = null
      }
    }
  }, [uploadStatus])

  return (
    <SALSettingsWrapper
      onClose={() => {
        if (isDemoCalling) {
          setShowSALSettingSidebar(false)
          return
        }
        if (
          uploadStatus === 'failed' ||
          (salMode === ESALSettingsMode.MANUAL && !audioUrl)
        ) {
          setNotRecordDialogOpen(true)
          return
        }
        setShowSALSettingSidebar(false)
      }}
    >
      <div className='rounded-xl border border-border bg-card'>
        {SALSettingsMode.map((mode, index) => (
          <Fragment key={mode}>
            <div
              className={cn(
                index === SALSettingsMode.length - 1 &&
                salMode === ESALSettingsMode.MANUAL &&
                'bg-bluepurple5'
              )}
            >
              <motion.div
                key={mode}
                className={cn(
                  'flex cursor-pointer items-center justify-between gap-4 rounded-xl bg-card p-4',
                  index === SALSettingsMode.length - 1 &&
                  'rounded-t-none rounded-b-xl border-border border-b-1'
                )}
                onClick={() => {
                  if (isDemoCalling) {
                    return
                  }
                  if (mode === ESALSettingsMode.AUTO_LEARNING) {
                    setRecordDialogOpen('seamless')
                    return
                  }
                  if (mode === ESALSettingsMode.OFF) {
                    onFormSetValue?.('advanced_features.enable_sal', false)
                    onFormSetValue?.('sal', undefined)
                  }

                  if (
                    mode === ESALSettingsMode.MANUAL &&
                    salAudioInfo?.[accountUid]?.file_url &&
                    salAudioInfo?.[accountUid]?.expired_ts * 1000 >
                    new Date().getTime()
                  ) {
                    onFormSetValue?.('advanced_features.enable_sal', true)
                    onFormSetValue?.('sal', {
                      sal_mode: 'locking',
                      sample_urls: {
                        [remote_rtc_uid]: salAudioInfo?.[accountUid]?.file_url
                      }
                    })
                  }
                  setSalMode(mode)
                }}
              >
                <div className='space-y-1.5'>
                  <div className='flex items-center gap-2'>
                    <span className='text-icontext'>{t(mode)}</span>
                    {mode === ESALSettingsMode.MANUAL &&
                      salMode !== ESALSettingsMode.MANUAL &&
                      audioUrl && (
                        <div className='flex items-center gap-1 break-all rounded-md bg-linear-270 from-[#659EFA] to-[#655FFF] p-1 px-1.5 py-0.5 font-semibold text-brand-white text-xs'>
                          <VoicePrintIcon className='size-4' />
                          {t(`has_voice_print`)}
                        </div>
                      )}
                  </div>
                  <p className='text-icontext-disabled text-xs'>
                    {t(`${mode}_description`)}
                  </p>
                </div>
                <Checkbox disabled={isDemoCalling} checked={salMode === mode} />
              </motion.div>
            </div>
            {index !== SALSettingsMode.length - 1 && <Separator />}
          </Fragment>
        ))}
        {salMode === ESALSettingsMode.MANUAL && (
          <div className='relative space-y-3 rounded-b-xl border-border border-b-1 bg-bluepurple5 p-4 pt-0'>
            <NextImage
              alt='sal-bg'
              {...SAL_BG_IMAGE}
              className='absolute left-0 w-full'
            />
            <div className='flex h-[56px] items-end gap-2'>
              <div
                className={cn(
                  'z-1 flex items-center gap-2',
                  audioUrl && 'items-start'
                )}
              >
                <VoiceIcon width={30} height={30} />
                <span className='text-brand-white text-sm'>
                  {audioUrl
                    ? t('voice_print_time', {
                      time: formatter.dateTime(
                        new Date(
                          (audioUrl?.expired_ts || 0) * 1000 -
                          MAX_VALIDATE_TIME_MILLISECOND
                        ),
                        {
                          dateStyle: 'full',
                          timeStyle: 'short',
                          timeZone
                        }
                      )
                    })
                    : t('create_sal_title')}
                </span>
              </div>
            </div>

            <div
              className={cn(
                'flex items-center justify-end',
                (isUploading || uploadStatus !== 'idle' || audioUrl) &&
                'ml-10 justify-between'
              )}
            >
              {isUploading ? (
                <div className='flex items-center gap-2 rounded-md bg-brand-white-1 px-2.5 py-1 text-xs'>
                  <LoadingSparkleIcon className='size-4' />
                  {t('uploading_hint')}
                </div>
              ) : uploadStatus === 'failed' ? (
                <motion.div
                  onClick={() => {
                    if (isDemoCalling) {
                      return
                    }
                    setIsUploading(true)
                  }}
                  className={cn(
                    'flex cursor-pointer items-center gap-2 text-xs text-yellow-6 transition-colors duration-300 hover:text-brand-white',
                    isDemoCalling && 'cursor-not-allowed'
                  )}
                >
                  {t('upload_failed')}
                  <RefreshIcon className='size-4' />
                </motion.div>
              ) : audioUrl ? (
                <motion.div
                  onClick={() => {
                    if (isDemoCalling) {
                      return
                    }
                    setIsPlaying(!isPlaying)
                  }}
                  className={cn(
                    'cursor-pointer rounded-sm bg-brand-white-1 px-4 py-1 transition-colors duration-300 hover:bg-brand-white-2',
                    isDemoCalling && 'cursor-not-allowed'
                  )}
                >
                  {isPlaying ? (
                    <PlayingIcon />
                  ) : (
                    <Triangle
                      fill='white'
                      strokeWidth={0}
                      className='size-4 rotate-90'
                    />
                  )}
                </motion.div>
              ) : null}

              <Dialog open={open} onOpenChange={setOpen}>
                <DialogTrigger asChild>
                  <motion.div
                    onClick={(e) => {
                      e.stopPropagation()
                      e.preventDefault()
                      if (isDemoCalling) {
                        return
                      }
                      setRecordDialogOpen('record')
                    }}
                    className={cn(
                      (uploadStatus === 'succeed' || uploadStatus === 'idle') &&
                        !isUploading
                        ? 'border border-brand-white-1 bg-brand-white-1 transition-colors duration-300 hover:bg-brand-white-2'
                        : '',
                      isDemoCalling ? 'cursor-not-allowed' : 'cursor-pointer',
                      'flex items-center gap-1 rounded-md px-4 py-1 text-brand-white text-xs'
                    )}
                  >
                    {uploadStatus === 'idle' && !audioUrl && !isUploading && (
                      <span>{t('create_sal_button')}</span>
                    )}
                    {audioUrl && !isUploading && (
                      <span>{t('recreate_sal_button')}</span>
                    )}
                    <ArrowRight className='size-4' />
                  </motion.div>
                </DialogTrigger>
                <DialogContent className='bg-card'>
                  <DialogHeader>
                    <DialogTitle className='flex items-center justify-end'>
                      <XIcon
                        className='size-4'
                        onClick={() => setOpen(false)}
                      />
                    </DialogTitle>
                  </DialogHeader>
                  <SALRecordDialogContent
                    ref={ref}
                    isUploading={isUploading}
                    uploadStatus={uploadStatus}
                    isPlaying={isPlaying}
                    setIsUploading={setIsUploading}
                    setUploadStatus={setUploadStatus}
                    setIsPlaying={setIsPlaying}
                    setAudioUrl={setAudioUrl}
                  />
                </DialogContent>
              </Dialog>
            </div>
          </div>
        )}
      </div>
      <Dialog open={notRecordDialogOpen} onOpenChange={setNotRecordDialogOpen}>
        <DialogContent className={`bg-block-2 sm:max-w-modal-max-width`}>
          <DialogHeader className='flex items-center'>
            <DialogTitle className='mb-3 font-bold text-base text-icontext'>
              {t('no_record_dialog_title')}
            </DialogTitle>
            <DialogDescription className='text-icontext text-sm'>
              {t('no_record_dialog_description')}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant='secondary'
              onClick={() => setNotRecordDialogOpen(false)}
              className='w-full bg-line-2'
            >
              {t('no_record_dialog_button_cancel')}
            </Button>
            <Button
              onClick={() => {
                setNotRecordDialogOpen(false)
                setShowSALSettingSidebar(false)
              }}
              className='w-full bg-brand-main'
            >
              {t('no_record_dialog_button_confirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={!!recordDialogOpen}>
        <DialogContent className={`bg-block-2 sm:max-w-modal-max-width`}>
          <DialogHeader className='flex items-center'>
            <DialogTitle className='mb-3 font-bold text-base text-icontext'>
              {t('record_dialog_title')}
            </DialogTitle>
            <DialogDescription className='text-icontext text-sm'>
              {t.rich('record_dialog_description', {
                link: (chunks) => (
                  <NextLink
                    href={POLICY_LINK}
                    target='_blank'
                    className='font-extrabold text-icontext underline'
                  >
                    {chunks}
                  </NextLink>
                )
              })}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant='secondary'
              onClick={() => setRecordDialogOpen(null)}
              className='w-full bg-line-2'
            >
              {t('record_dialog_button_cancel')}
            </Button>
            <Button
              onClick={() => {
                if (recordDialogOpen === 'record') {
                  setOpen(true)
                }
                if (recordDialogOpen === 'seamless') {
                  setSalMode(ESALSettingsMode.AUTO_LEARNING)
                  onFormSetValue?.('advanced_features.enable_sal', true)
                  onFormSetValue?.('sal', {
                    sal_mode: 'locking'
                  })
                }
                setRecordDialogOpen(null)
              }}
              className='w-full bg-brand-main'
            >
              {t('record_dialog_button_confirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </SALSettingsWrapper>
  )
}

const SALRecordDialogContent = ({
  ref,
  isUploading,
  uploadStatus,
  setUploadStatus,
  setIsPlaying,
  setIsUploading,
  setAudioUrl
}: {
  ref: RefObject<{
    // media: MediaRecorder
    size: number
    recorder: ScriptProcessorNode
    chunks: Float32Array[]
  } | null>
  isPlaying: boolean
  isUploading: boolean
  uploadStatus: 'idle' | 'succeed' | 'failed'
  setUploadStatus: (uploadStatus: 'idle' | 'succeed' | 'failed') => void
  setIsPlaying: (isPlaying: boolean) => void
  setIsUploading: (isUploading: boolean) => void
  setAudioUrl: (
    audioUrl: { file_url: string; expired_ts: number } | null
  ) => void
}) => {
  const MIN_RECORD_TIME = 10
  const MAX_RECORD_TIME = 20

  const { setIsRecordSupported, setShowCompatibilityDialog } = useGlobalStore()
  const t = useTranslations('settings.advanced_features.enable_sal')

  const recordTimeIntervalIdRef = useRef<NodeJS.Timeout>(null)
  const recordTimeRef = useRef(0)

  const [recordTime, setRecordTime] = useState(0)
  const [isRecording, setIsRecording] = useState(false)

  function reset() {
    if (recordTimeIntervalIdRef.current) {
      clearInterval(recordTimeIntervalIdRef.current)
      recordTimeIntervalIdRef.current = null
    }
    setAudioUrl(null)
    setRecordTime(0)
    recordTimeRef.current = 0
    setIsRecording(false)
    setIsPlaying(false)
    setIsUploading(false)
    setUploadStatus('idle')
    if (ref.current) {
      ref.current.recorder.disconnect()
      // ref.current.media.stop()
      // ref.current.media.removeEventListener(
      //   'dataavailable',
      //   handleDataAvailable
      // )
      // ref.current.media.removeEventListener('stop', handleStop)
      ref.current = null
    }
  }

  // function handleDataAvailable(event: BlobEvent) {
  //   console.log('handleDataAvailable', event)
  //   if (ref.current) {
  //     console.log('handleDataAvailable1', ref.current.chunks)
  //     // setChunks((prev: Blob[]) => [...prev, event.data as Blob] as Blob[]);
  //     // ref.current.chunks.push(event.data)
  //   }
  // }

  const handleStop = async () => {
    if (recordTimeIntervalIdRef.current) {
      clearInterval(recordTimeIntervalIdRef.current)
      recordTimeIntervalIdRef.current = null
    }
    // 符合条件触发上传
    if (recordTimeRef.current >= MIN_RECORD_TIME) {
      setIsRecording(false)
      setIsUploading(true)
    }
    ref.current?.recorder.disconnect()
  }

  const recordClick = async () => {
    console.log('recordClick', isRecording)
    // if has started recording, stop it
    if (ref.current && isRecording) {
      // ref.current.media.stop()
      handleStop()

      return
    }

    // check if getUserMedia is supported
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      reset()
      console.log('getUserMedia supported.')
      try {
        // reset
        setIsPlaying(false)

        // get user media
        const stream = await navigator.mediaDevices.getUserMedia(
          // constraints - only audio needed for this app
          {
            audio: true
          }
        )

        const context = new AudioContext({ sampleRate: 16000 })
        // 清空数据

        const recorder = context.createScriptProcessor(4096, 1, 1)
        ref.current = { size: 0, chunks: [], recorder }
        // 录音节点

        ref.current!.recorder.onaudioprocess = (e) => {
          // getChannelData返回Float32Array类型的pcm数据
          var data = e.inputBuffer.getChannelData(0)

          ref.current!.chunks.push(new Float32Array(data))
          ref.current!.size += data.length
        }
        const audioInput = context.createMediaStreamSource(stream)
        audioInput.connect(ref.current?.recorder as AudioNode)
        ref.current?.recorder.connect(context.destination)
        // const audioContext = new AudioContext({ sampleRate: 8000 });
        // const mediaStreamAudioSourceNode = new MediaStreamAudioSourceNode(audioContext, { mediaStream: stream });
        // const mediaStreamAudioDestinationNode = new MediaStreamAudioDestinationNode(audioContext);

        //   mediaStreamAudioSourceNode.connect(mediaStreamAudioDestinationNode);
        //   const mediaRecorder = new CustomMediaRecorder(mediaStreamAudioDestinationNode.stream, { mimeType: "audio/pcm"})
        //   ref.current = { media: mediaRecorder, chunks: [] }
        //   ref.current.media.start()
        //   ref.current.media.addEventListener('dataavailable', handleDataAvailable)
        //   ref.current.media.addEventListener('stop', handleStop)
        recordTimeIntervalIdRef.current = setInterval(() => {
          setRecordTime((prev) => prev + 1)
          recordTimeRef.current = recordTimeRef.current + 1
        }, 1000)
        console.log('CustomMediaRecorder start')
        setIsRecording(true)
        setUploadStatus('idle')

        // mediaRecorder.onerror = (err) => {
        //   console.log('CustomMediaRecorder onerror', err)
        // }
      } catch (err) {
        reset()
        setIsRecordSupported(false)
        setShowCompatibilityDialog(true)
        console.log('The following getUserMedia error occured: ' + err)
      }

      // Error callback
    } else {
      setIsRecordSupported(false)
      setShowCompatibilityDialog(true)
      console.log('getUserMedia not supported on your browser!')
    }
  }

  useEffect(() => {
    if (recordTime > MAX_RECORD_TIME) {
      if (recordTimeIntervalIdRef.current) {
        clearInterval(recordTimeIntervalIdRef.current)
        recordTimeIntervalIdRef.current = null
      }
      toast.warning(t('recording_warning_max'))
      recordClick()
    }
  }, [recordTime, t])

  const normalHint = [
    {
      key: 'normal_hint',
      component: <span key='normal_hint'>{t('hint')}</span>
    }
  ]
  const recordingHint = [
    {
      key: 'recording_time',
      component: (
        <span key='recording_time'>
          {t('recording_time', { time: recordTime })}
        </span>
      )
    },
    {
      key: 'recording_warning',
      component: <span key='recording_warning'>{t('recording_warning')}</span>
    }
  ]

  const uploadingHint = [
    {
      key: 'uploading_hint',
      component: (
        <div
          className='flex items-center gap-2 rounded-md bg-brand-white-1 px-2.5 py-1'
          key='uploading_hint'
        >
          <LoadingSparkleIcon className='size-4' /> {t('uploading_hint')}
        </div>
      )
    }
  ]
  const uploadSucceed = [
    {
      key: 'upload_succeed',
      component: (
        <div
          key='upload_succeed'
          className='flex items-center gap-2 rounded-md bg-brand-white-1 px-2.5 py-1'
        >
          <CircleCheckIcon className='size-4 rounded-full bg-green-600' />{' '}
          {t('upload_succeed')}
        </div>
      )
    }
  ]
  const uploadFailed = [
    {
      key: 'upload_failed',
      component: (
        <motion.span
          key='upload_failed'
          className='flex cursor-pointer items-center gap-2 text-yellow-6'
          onClick={() => setIsUploading(true)}
        >
          {t('upload_failed')}
          <RefreshIcon className='size-4' />
        </motion.span>
      )
    }
  ]

  const hint =
    !isRecording && !isUploading
      ? uploadStatus === 'succeed'
        ? uploadSucceed
        : uploadStatus === 'failed'
          ? uploadFailed
          : normalHint
      : isUploading
        ? uploadingHint
        : isRecording
          ? recordingHint
          : normalHint
  return (
    <div>
      <div className='flex w-full items-center justify-center'>
        <span className='text-icontext text-xl'>{t('record_title')}</span>
      </div>

      <p className='m-14 flex flex-col items-start overflow-y-auto max-md:max-h-[300px]'>
        {(isCN ? cn_record_material : en_record_material).map((item) => (
          <div key={item} className='text-icontext text-xl'>
            {item}
          </div>
        ))}
      </p>
      <div className='flex flex-col items-center gap-3'>
        {hint.map((item) => (
          <span className='text-icontext-disabled text-xs' key={item.key}>
            {item.component}
          </span>
        ))}
        <Button
          className='w-full bg-brand-main-6 font-bold text-brand-white text-sm'
          onClick={() => {
            console.log('recordClick', isRecording, recordTime)
            if (isRecording && recordTime < MIN_RECORD_TIME) {
              toast.warning(t('recording_warning_min'))
              reset()
              return
            }
            recordClick()
          }}
        >
          {!isRecording ? (
            <>
              <Mic />
              {t('record_button')}
            </>
          ) : (
            <AIRecordingIcon />
          )}
        </Button>
      </div>
    </div>
  )
}

const AIRecordingIcon = () => {
  const t = useTranslations('settings.advanced_features.enable_sal')
  const barCount = 20
  const shortestIndexes = [0, barCount - 1]
  const shorterIndex = [1, barCount - 2]
  const barHeight = 6

  const ref = useRef<NodeJS.Timeout>(null)
  const items = new Array(barCount).fill(0).map((_, index) => index)
  const [intervalIndex, setIntervalIndex] = useState(0)
  useEffect(() => {
    ref.current = setInterval(() => {
      setIntervalIndex((prev) => (prev + 1) % 3)
    }, 200)
    return () => {
      if (ref.current) {
        clearInterval(ref.current)
      }
      ref.current = null
    }
  }, [])
  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <div className='flex h-full w-full items-center justify-center gap-1'>
            {items.map((index) => {
              const height = shortestIndexes.includes(index)
                ? barHeight
                : shorterIndex.includes(index)
                  ? (intervalIndex % 3 > 1 ? 1 : 0) * 2 + barHeight
                  : (intervalIndex % 3) * 2 + barHeight
              return (
                <div
                  style={{
                    height: height
                  }}
                  key={index}
                  className={cn('h-2 w-1 rounded-full bg-brand-white')}
                />
              )
            })}
          </div>
        </TooltipTrigger>
        <TooltipContent className='max-w-xs'>
          <p>{t('recording_tooltip')}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}

const PlayingIcon = () => {
  const [bar, setBar] = useState([1, 2, 3, 1])
  const ref = useRef<NodeJS.Timeout>(null)

  useEffect(() => {
    ref.current = setInterval(() => {
      setBar((prev) => {
        return prev.map((i) => {
          return (i + 1) % 3
        })
      })
    }, 200)
    return () => {
      if (ref.current) {
        clearInterval(ref.current)
      }
      ref.current = null
    }
  }, [])
  return (
    <div className='flex h-4 w-full items-center justify-center gap-1'>
      {bar.map((item, index) => (
        <div
          key={index as any}
          style={{ height: item * 4 }}
          className='w-1 rounded-full bg-brand-white transition-height duration-300'
        />
      ))}
    </div>
  )
}
