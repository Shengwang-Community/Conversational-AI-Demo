import { Power } from 'lucide-react'
import { motion } from 'motion/react'
import Link from 'next/link'
import { useTranslations } from 'next-intl'
import { useState } from 'react'
import { toast } from 'sonner'
import {
  DropdownIcon,
  PrivacyPolicyIcon,
  UserAgreementIcon
} from '@/components/icon'
import { MyAgentContent } from '@/components/layout/user-info/my-agent'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from '@/components/ui/dialog'
import { POLICY_LINK, SSO_DELETE_ACCOUNT_URL, TERMS_LINK } from '@/constants'
import { cn, isCN } from '@/lib/utils'

export const User = (props: { className?: string }) => {
  const { className } = props

  return (
    <div className={cn(className, 'space-y-3')}>
      {isCN && <MyAgentContent />}
      <PrivacyContent />
      <DeleteAccountContent />
    </div>
  )
}

const DeleteAccountContent = () => {
  const t = useTranslations('userInfo')
  const [checked, setChecked] = useState(true)
  const [open, setOpen] = useState(false)

  return (
    <div className='space-y-3 rounded-md bg-block-5 px-2 py-3'>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogTrigger className='w-full'>
          <div className='flex items-center justify-between rounded-sm px-2 py-3 hover:bg-secondhover'>
            <div className='flex items-center gap-2'>
              <Power className='size-4 text-brand-white' />
              <span className='text-icontext'>{t('deleteAccount.button')}</span>
            </div>
            <DropdownIcon className='size-6 rotate-270' />
          </div>
        </DialogTrigger>
        <DialogContent className={`bg-block-2 sm:max-w-modal-max-width`}>
          <DialogHeader className='flex items-center'>
            <DialogTitle className='mb-3 font-bold text-base text-icontext'>
              {t('deleteAccount.title')}
            </DialogTitle>
            <DialogDescription className='text-icontext text-sm'>
              {t('deleteAccount.description')}
            </DialogDescription>
          </DialogHeader>
          <motion.div
            className='flex items-start gap-2'
            onClick={() => setChecked(!checked)}
          >
            <div className='flex h-5 items-center justify-center'>
              <Checkbox className='size-4 p-1 leading-5' checked={checked} />
            </div>

            <p className='text-icontext text-sm'>
              {t('deleteAccount.checkbox')}
            </p>
          </motion.div>
          <DialogFooter className='!justify-between flex w-full items-center'>
            <DialogClose asChild>
              <Button
                className='flex-1 bg-line-2 text-icontext-hover'
                variant='outline'
              >
                {t('deleteAccount.cancel')}
              </Button>
            </DialogClose>
            <Button
              onClick={() => {
                if (!checked) {
                  toast.warning(t('deleteAccount.uncheckWarning'))
                  return
                }

                window.open(SSO_DELETE_ACCOUNT_URL, '_blank')
                setOpen(false)
              }}
              className='flex-1 bg-brand-red-6 text-brand-white'
              variant='destructive'
            >
              {t('deleteAccount.confirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

const PrivacyContent = () => {
  const t = useTranslations('userInfo')
  return (
    <div className='space-y-3 rounded-md bg-block-5 px-2 py-3'>
      <Link
        href={TERMS_LINK}
        target='_blank'
        className='flex items-center justify-between rounded-sm px-2 py-3 hover:bg-secondhover'
      >
        <div className='flex items-center gap-2'>
          <UserAgreementIcon className='size-4' />
          <span className='text-icontext'>{t('privacy.userAgreement')}</span>
        </div>
        <DropdownIcon className='size-6 rotate-270' />
      </Link>
      <Link
        href={POLICY_LINK}
        target='_blank'
        className='flex items-center justify-between rounded-sm px-2 py-3 hover:bg-secondhover'
      >
        <div className='flex items-center gap-2'>
          <PrivacyPolicyIcon className='size-4' />
          <span className='text-icontext'>{t('privacy.privacyPolicy')}</span>
        </div>
        <DropdownIcon className='size-6 rotate-270' />
      </Link>
    </div>
  )
}
