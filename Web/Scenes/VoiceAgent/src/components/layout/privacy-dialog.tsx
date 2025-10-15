import { DialogOverlay } from '@radix-ui/react-dialog'
import NextLink from 'next/link'
import { useTranslations } from 'next-intl'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import { POLICY_LINK, TERMS_LINK } from '@/constants'
import { useGlobalStore } from '@/store'

export const PrivacyDialog = () => {
  const tAgent = useTranslations('agent')
  const {
    showPrivacyDialog,
    setShowLoginPanel,
    setShowPrivacyDialog,
    setIsPrivacyPolicyAccepted
  } = useGlobalStore()

  return (
    <Dialog
      key='privacy-dialog'
      open={showPrivacyDialog}
      onOpenChange={setShowPrivacyDialog}
    >
      <DialogOverlay>
        <DialogContent className={`bg-block-2 sm:max-w-modal-max-width`}>
          <DialogHeader className='flex flex-col items-center'>
            <DialogTitle className='mb-3 font-bold text-base text-icontext'>
              {tAgent('privacyDialog.title')}
            </DialogTitle>
            <DialogDescription className='text-icontext-hover text-sm'>
              {tAgent.rich('privacyDialog.description', {
                link: (chunks) => (
                  <NextLink
                    href={TERMS_LINK}
                    target='_blank'
                    className='font-extrabold text-icontext underline'
                  >
                    {chunks}
                  </NextLink>
                ),
                policyLink: (chunks) => (
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
          <DialogFooter className='flex gap-2'>
            <DialogClose asChild>
              <Button
                variant='outline'
                className='flex-1 bg-line-2'
                onClick={() => {
                  setShowLoginPanel(true)
                  setIsPrivacyPolicyAccepted(false)
                  setShowPrivacyDialog(false)
                }}
              >
                {tAgent('privacyDialog.cancel')}
              </Button>
            </DialogClose>
            <Button
              variant='default'
              className='flex-1 bg-brand-main'
              onClick={() => {
                setShowLoginPanel(true)
                setIsPrivacyPolicyAccepted(true)
                setShowPrivacyDialog(false)
              }}
            >
              {tAgent('privacyDialog.confirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </DialogOverlay>
    </Dialog>
  )
}
