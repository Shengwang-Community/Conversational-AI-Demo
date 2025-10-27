'use client'

import { zodResolver } from '@hookform/resolvers/zod'
import { compareAsc, subYears } from 'date-fns'

import NextImage from 'next/image'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { useForm } from 'react-hook-form'
import type { z } from 'zod'
import { CircleXIcon } from '@/components/icon'
import { UserAgentPreference } from '@/components/layout/user-info/schema'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import {
  CN_FIRST_NAMES,
  CN_LAST_NAMES,
  EN_NAMES,
  USER_INFO_IMAGE
} from '@/constants'
import { useDebounce } from '@/hooks/use-debounce'
import { cn, isCN } from '@/lib/utils'
import { updateUserInfo } from '@/services/agent'
import { useUserInfoStore } from '@/store'
import type { IUserInfoInput } from '@/type/agent'

export const USER_INFO_GENDER_IMAGE = {
  BG_IMG: isCN
    ? USER_INFO_IMAGE.USER_AGENT_BG_CN
    : USER_INFO_IMAGE.USER_AGENT_BG_EN,
  MALE_IMG: isCN
    ? USER_INFO_IMAGE.MALE_AVATAR_CN
    : USER_INFO_IMAGE.MALE_AVATAR_EN,
  FEMALE_IMG: isCN
    ? USER_INFO_IMAGE.FEMALE_AVATAR_CN
    : USER_INFO_IMAGE.FEMALE_AVATAR_EN
}

export const MyAgentContent = () => {
  const t = useTranslations('userInfo')
  const { userAgentPreference, updateUserAgentPreference, accountUid } =
    useUserInfoStore()
  const form = useForm<z.infer<typeof UserAgentPreference>>({
    resolver: zodResolver(UserAgentPreference),
    defaultValues: userAgentPreference
  })

  const [nickname, setNickname] = React.useState(userAgentPreference.nickname)
  const [bio, setBio] = React.useState(userAgentPreference.bio)

  const debouncedNickname = useDebounce(nickname, 500)
  const debouncedBio = useDebounce(bio, 500)

  // has account value but none of user info
  React.useEffect(() => {
    if (
      accountUid &&
      !userAgentPreference.nickname &&
      !userAgentPreference.gender &&
      !userAgentPreference.birthday &&
      !userAgentPreference.bio
    ) {
      const cnName =
        CN_FIRST_NAMES[Math.floor(Math.random() * CN_FIRST_NAMES.length)] +
        CN_LAST_NAMES[Math.floor(Math.random() * CN_LAST_NAMES.length)]
      const enName = EN_NAMES[Math.floor(Math.random() * EN_NAMES.length)]
      setNickname(isCN ? cnName : enName)
    }
  }, [userAgentPreference, accountUid])

  React.useEffect(() => {
    const subscription = form.watch((value, info) => {
      if (
        value[info.name as keyof UserAgentPreference] !==
        userAgentPreference[info.name as keyof UserAgentPreference]
      ) {
        console.log('setting userinfo, value: ', value, 'info: ', info)
        updateUserAgentPreference(value)
        updateUserInfo(value as IUserInfoInput)
      }
    })
    return () => {
      subscription.unsubscribe()
    }
  }, [form, updateUserAgentPreference, userAgentPreference])

  React.useEffect(() => {
    form.setValue('nickname', debouncedNickname)
  }, [debouncedNickname, form])

  React.useEffect(() => {
    form.setValue('bio', debouncedBio)
  }, [debouncedBio, form])

  const maxValidateDate = subYears(new Date(), 18)
    .toISOString()
    .substring(0, 10)

  return (
    <div className='flex flex-col gap-3 text-icontext'>
      <div
        className={cn(
          'rounded-md',
          'flex flex-col',
          'bg-[#568CFF]' // todo: add it to global css ai_bluepurple5
        )}
      >
        <div className={cn('flex items-center justify-between gap-2 px-4')}>
          <div>{t('my-agent')}</div>
          <NextImage alt='Male Avatar' {...USER_INFO_GENDER_IMAGE.BG_IMG} />
        </div>
        <div className='rounded-md bg-block-5 p-4'>
          <Form {...form}>
            <form className='space-y-5'>
              <FormField
                control={form.control}
                name='nickname'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className='font-normal'>
                      {t('nickname')}
                    </FormLabel>
                    <FormControl>
                      <div className='group relative'>
                        <Input
                          placeholder={t('nickname-placeholder')}
                          className='mt-3 h-11 rounded-sm bg-brand-white-1'
                          // {...field}
                          value={nickname}
                          onChange={(e) => {
                            setNickname(e.target.value)
                          }}
                        />
                        {!!nickname && (
                          <CircleXIcon
                            className='-translate-y-1/2 absolute top-1/2 right-2 h-5 w-5 fill-[#FFFFFF50] transition-colors duration-300 group-hover:fill-icontext'
                            onClick={() => {
                              setNickname('')
                            }}
                          />
                        )}
                      </div>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name='gender'
                render={({ field }) => (
                  <FormItem className='space-y-3'>
                    <FormLabel className='font-normal'>
                      {t('call-you')}
                    </FormLabel>
                    <FormControl>
                      <div className='mt-3 flex items-center gap-3'>
                        <Label
                          className={cn(
                            'flex items-center justify-between gap-1 rounded-sm bg-brand-white-1 p-3',
                            'h-11 flex-1/2 shadow-none',
                            'whitespace-nowrap outline-2 outline-transparent',
                            field.value === 'male' && 'outline-[#2B6DF6]'
                          )}
                          htmlFor={`gender-male`}
                        >
                          <Checkbox
                            id={`gender-male`}
                            checked={field.value === 'male'}
                            className='pointer-events-none data-[state=checked]:border-brand-main data-[state=checked]:bg-brand-main data-[state=checked]:text-white'
                            onCheckedChange={(checked: boolean) => {
                              if (checked) {
                                field.onChange('male')
                              }
                            }}
                          />
                          <div className='flex items-center gap-1'>
                            <span>{t('mr')}</span>
                            <NextImage
                              alt='Male Avatar'
                              {...USER_INFO_GENDER_IMAGE.MALE_IMG}
                            />
                          </div>
                        </Label>
                        <Label
                          className={cn(
                            'flex items-center justify-between gap-1 rounded-sm bg-brand-white-1 p-3',
                            'h-11 flex-1/2 shadow-none',
                            'whitespace-nowrap outline-2 outline-transparent',
                            field.value === 'female' && 'outline-[#2B6DF6]'
                          )}
                          htmlFor={`gender-female`}
                        >
                          <Checkbox
                            id={`gender-female`}
                            checked={field.value === 'female'}
                            className='pointer-events-none data-[state=checked]:border-brand-main data-[state=checked]:bg-brand-main data-[state=checked]:text-white'
                            onCheckedChange={(checked: boolean) => {
                              if (checked) {
                                field.onChange('female')
                              }
                            }}
                          />
                          <div className='flex items-center gap-1'>
                            <span>{t('ms')}</span>
                            <NextImage
                              alt='Female Avatar'
                              {...USER_INFO_GENDER_IMAGE.FEMALE_IMG}
                            />
                          </div>
                        </Label>
                      </div>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name='birthday'
                render={({ field }) => (
                  <FormItem className='flex items-center justify-between gap-3'>
                    <FormLabel className='m-0 whitespace-nowrap font-normal'>
                      {t('birthday')}
                    </FormLabel>
                    <FormControl>
                      <Input
                        type='date'
                        placeholder='birthday'
                        className='h-11 w-fit rounded-sm bg-brand-white-1'
                        max={maxValidateDate}
                        value={
                          field.value
                            ? new Date(field.value)
                              .toISOString()
                              .substring(0, 10)
                            : '1990-01-01'
                        }
                        onChange={(e) => {
                          const date = e.target.value
                            ? new Date(e.target.value)
                            : undefined

                          if (!date || compareAsc(date, maxValidateDate) > 0) {
                            return
                          }
                          field.onChange(date)
                        }}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name='bio'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className='font-normal'>{t('bio')}</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder={t('bio-placeholder')}
                        className='mt-3 min-h-35 rounded-sm bg-brand-white-1'
                        value={bio}
                        // {...field}
                        onChange={(e) => {
                          // max length 500
                          setBio(e.target.value.slice(0, 500))
                        }}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </form>
          </Form>
        </div>
      </div>
    </div>
  )
}
