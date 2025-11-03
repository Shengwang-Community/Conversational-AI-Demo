'use client'

import NextImage from 'next/image'
import { useTranslations } from 'next-intl'
import { useEffect, useMemo, useState } from 'react'

import type z from 'zod'
import { CircleXIcon, DropdownIcon, SipCallOutIcon } from '@/components/icon'
import { Button } from '@/components/ui/button'
import {
    Command,
    CommandEmpty,
    CommandGroup,
    CommandInput,
    CommandItem,
    CommandList
} from '@/components/ui/command'
import {
    Dialog,
    DialogContent,
    DialogFooter,
    DialogHeader,
    DialogTitle
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import {
    Popover,
    PopoverContent,
    PopoverTrigger
} from '@/components/ui/popover'
import { SparklesCore } from '@/components/ui/sparkles'
import {
    type agentPresetSchema,
    type agentPresetSipSchema,
    SIP_REGION_NOT_FOUND_IMAGE
} from '@/constants'
import { useIsMobile } from '@/hooks/use-mobile'
import { cn, formatPhoneNumber, isCN, validatePhoneNumber } from '@/lib/utils'
import { useSipStore } from '@/store/sip'

export const AgentSipDisplay = ({
    sips
}: {
    sips: z.infer<typeof agentPresetSipSchema>[]
}) => {
    const t = useTranslations()
    return (
        <div className=''>
            <div className='mx-auto flex w-fit flex-wrap gap-2'>
                {sips.map((sip) => (
                    <div
                        key={sip.region_code}
                        className='flex items-center gap-2 rounded-md p-2'
                    >
                        {!isCN && <span className='text-3xl'>{sip.flag_emoji}</span>}
                        <div className='font-black text-3xl text-icontext'>
                            {isCN
                                ? sip.phone_number?.replace(/^d{3}d{4}d{4}/g, '$1 $2 $3')
                                : `${sip.region_code}-${sip.phone_number?.replace(sip.region_code, '')}`}
                        </div>
                    </div>
                ))}
            </div>
            <div className='relative w-fit'>
                <div className='absolute inset-x-[15%] top-0 h-[2px] w-3/4 bg-gradient-to-r from-transparent via-indigo-500 to-transparent blur-sm' />
                <div className='absolute inset-x-[15%] top-0 h-px w-3/4 bg-gradient-to-r from-transparent via-indigo-500 to-transparent' />
                <div className='absolute inset-x-[40%] top-0 h-[5px] w-1/4 bg-gradient-to-r from-transparent via-sky-500 to-transparent blur-sm' />
                <div className='absolute inset-x-[40%] top-0 h-px w-1/4 bg-gradient-to-r from-transparent via-sky-500 to-transparent' />
                {isCN && (
                    <div className='flex w-full items-center justify-center pt-2 text-icontext-disabled text-xs'>
                        <span>{t('sip.inbound_hint')}</span>
                    </div>
                )}
                <SparklesCore
                    id='sparkles-core'
                    background='transparent'
                    minSize={0.6}
                    maxSize={1.4}
                    particleDensity={100}
                    className='h-9 w-full overflow-hidden'
                    particleColor='#FFFFFF'
                    speed={1}
                />
            </div>
        </div>
    )
}

export const AgentSipCallOut = ({
    presets,
    onClick
}: {
    presets: z.infer<typeof agentPresetSchema>['presets']
    onClick: () => void
}) => {
    const { updatePreset, updateCallee } = useSipStore()
    const [phoneNumber, setPhoneNumber] = useState('')
    const [regionName, setRegionName] = useState<string>()
    const [popoverOpen, setPopoverOpen] = useState(false)
    const [isValidPhoneNumber, setIsValidPhoneNumber] = useState(true)
    const [dialogOpen, setDialogOpen] = useState(false)
    const t = useTranslations()
    const isMobile = useIsMobile()

    const regions = useMemo(() => {
        return (presets || [])
            .flatMap((preset) =>
                preset.sip_vendor_callee_numbers?.map((sip) => ({
                    preset: preset,
                    key: sip.region_code,
                    value: sip.region_name,
                    label: t(`sip.${sip.region_name}`),
                    flag_emoji: sip.flag_emoji
                }))
            )
            .filter(Boolean)
            .map((v) => v as NonNullable<typeof v>)
    }, [presets, t])

    const region = useMemo(() => {
        return regions.find((region) => region.value === regionName)
    }, [regions, regionName])

    // init
    useEffect(() => {
        if (!regionName && regions) {
            setRegionName(regions[0].value)
            updatePreset({
                preset_type: regions[0].preset.preset_type,
                preset_name: regions[0].preset.name
            })
        }
    }, [regions, regionName, updatePreset])

    useEffect(() => {
        const prefix = isCN ? '' : region?.key || ''
        updateCallee(prefix + phoneNumber.replaceAll(' ', ''))
    }, [phoneNumber, region, updateCallee])

    const callOutButton = (
        <Button
            className={cn(
                'ag-sip-call-out-button h-full w-16 rounded-full px-5 py-3',
                !isCN && isMobile && 'mt-2 h-fit w-full'
            )}
            disabled={!isValidPhoneNumber}
            onClick={() => {
                const isValid = validatePhoneNumber(phoneNumber)
                setIsValidPhoneNumber(isValid)
                if (isValid) {
                    if (isCN) {
                        setDialogOpen(true)
                    } else {
                        onClick?.()
                    }
                }
            }}
            variant={'action'}
        >
            <SipCallOutIcon />
        </Button>
    )

    return (
        <div>
            <div className='flex h-15 items-center gap-2 rounded-full border border-line bg-brand-white-1 p-1.5'>
                {!isCN && (
                    <div className='flex h-full items-center gap-2'>
                        <Popover onOpenChange={setPopoverOpen}>
                            <PopoverTrigger asChild>
                                <Button
                                    variant='outline'
                                    role='combobox'
                                    className='h-full w-fit gap-2 rounded-full bg-brand-white-1 px-5 py-3 text-2xl text-icontext'
                                >
                                    <span className='text-2xl'>{region?.flag_emoji}</span>
                                    <span className='text-2xl'>{region?.key}</span>
                                    <DropdownIcon
                                        className={cn(
                                            'size-4 opacity-50 transition-transform duration-300',
                                            {
                                                'rotate-180': popoverOpen
                                            }
                                        )}
                                    />
                                </Button>
                            </PopoverTrigger>
                            <PopoverContent className='w-[300px] p-0'>
                                <Command
                                    className='bg-block-2'
                                    filter={(value, search) => {
                                        const region = regions.find(
                                            (region) => region.value === value
                                        )
                                        return region
                                            ? region.value
                                                .toLowerCase()
                                                .includes(search.toLowerCase()) ||
                                                region.key
                                                    .toLowerCase()
                                                    .includes(search.toLowerCase()) ||
                                                region.label
                                                    .toLowerCase()
                                                    .includes(search.toLowerCase())
                                                ? 1
                                                : 0
                                            : 0
                                    }}
                                >
                                    <CommandInput
                                        placeholder={t('sip.region_placeholder')}
                                        className='h-9'
                                    />
                                    <CommandList>
                                        <CommandEmpty className='pt-3 pb-10'>
                                            <NextImage
                                                className='mx-auto'
                                                {...SIP_REGION_NOT_FOUND_IMAGE}
                                            ></NextImage>
                                        </CommandEmpty>
                                        <CommandGroup>
                                            {regions.map((regionItem) => (
                                                <CommandItem
                                                    className='flex items-center justify-start gap-2'
                                                    key={regionItem.key}
                                                    value={regionItem.value}
                                                    onSelect={(currentValue) => {
                                                        setRegionName(currentValue)
                                                    }}
                                                >
                                                    <span className=''>{regionItem.flag_emoji}</span>
                                                    <span className='font-semibold text-icontext'>
                                                        {regionItem.label}
                                                    </span>
                                                    <span className='text-icontext'>
                                                        {regionItem.key}
                                                    </span>
                                                </CommandItem>
                                            ))}
                                        </CommandGroup>
                                    </CommandList>
                                </Command>
                            </PopoverContent>
                        </Popover>
                    </div>
                )}
                <div className='group flex items-center gap-2'>
                    <Input
                        value={phoneNumber}
                        onChange={(e) => {
                            setIsValidPhoneNumber(true)
                            const value = e.target.value
                            const targetValue = value.replaceAll(' ', '')
                            if (targetValue.match(/^[0-9]*$/g) && targetValue.length <= 14) {
                                setPhoneNumber(formatPhoneNumber(targetValue))
                            }
                        }}
                        placeholder={t('sip.phone_number_placeholder')}
                        className={cn(
                            isValidPhoneNumber ? 'text-icontext' : 'text-brand-red-6',
                            '!text-2xl min-w-50 border-0 border-none bg-transparent font-semibold placeholder:relative placeholder:top-[-4px] placeholder:text-sm focus-visible:ring-0'
                        )}
                    />
                    {!!phoneNumber && (
                        <CircleXIcon
                            className='h-5 w-5 fill-[#FFFFFF50] transition-colors duration-300 group-hover:fill-icontext'
                            onClick={() => {
                                setPhoneNumber('')
                                setIsValidPhoneNumber(true)
                            }}
                        />
                    )}
                </div>
                {(isCN || !isMobile) && callOutButton}
            </div>
            {!isCN && isMobile && callOutButton}
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
                <DialogContent className='bg-card'>
                    <DialogHeader>
                        <DialogTitle className='mb-3 font-bold text-base text-icontext'>
                            {t('sip.dialog.title')}
                        </DialogTitle>
                    </DialogHeader>
                    <DialogFooter className='flex items-center justify-between gap-2'>
                        <Button
                            variant='secondary'
                            className='w-full bg-line-2'
                            onClick={() => setDialogOpen(false)}
                        >
                            {t('sip.dialog.cancel')}
                        </Button>
                        <Button
                            className='w-full bg-brand-main'
                            onClick={() => onClick?.()}
                        >
                            {t('sip.dialog.confirm')}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            <div className='mt-3 flex h-4 items-center justify-center'>
                {!isValidPhoneNumber && (
                    <span className='text-brand-red-6 text-sm'>
                        {t('sip.invalid_phone_number')}
                    </span>
                )}
            </div>
        </div>
    )
}
