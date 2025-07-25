'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import { LoadingSpinner } from '@/components/icon'
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
import { useGlobalStore } from '@/store/global'

export function GlobalConfirmDialog() {
  const [isLoading, setIsLoading] = React.useState(false)

  const { confirmDialog, setConfirmDialog } = useGlobalStore()

  const t = useTranslations('dialog')

  const handleConfirm = async () => {
    setIsLoading(true)
    try {
      if (confirmDialog?.onConfirm) {
        await confirmDialog.onConfirm()
      }
    } catch (error) {
      console.error('[GlobalConfirmDialog] handleConfirm error:', error)
    } finally {
      setIsLoading(false)
      setConfirmDialog(undefined)
    }
  }

  const handleCancel = () => {
    if (confirmDialog?.onCancel) {
      confirmDialog.onCancel()
    }
    setConfirmDialog(undefined)
  }

  if (!confirmDialog) {
    return null // If no dialog is set, return null to avoid rendering
  }

  return (
    <Dialog open={true}>
      <DialogContent className='max-w-md border-line bg-block-2 text-icontext sm:max-w-sm'>
        <DialogHeader>
          <DialogTitle className='mx-auto'>
            {confirmDialog.title || t('title')}
          </DialogTitle>
          {confirmDialog.description && (
            <DialogDescription>{confirmDialog.description}</DialogDescription>
          )}
        </DialogHeader>
        <div className=''>{confirmDialog.content}</div>
        <DialogFooter className='flex items-center justify-between gap-2'>
          {confirmDialog.onCancel && (
            <DialogClose asChild>
              <Button
                variant='secondary'
                onClick={handleCancel}
                disabled={isLoading}
                className='flex-1/2 text-icontext-hover'
              >
                {confirmDialog.cancelText || t('cancel')}
              </Button>
            </DialogClose>
          )}
          {confirmDialog.onConfirm && (
            <Button
              type='submit'
              variant='default'
              onClick={handleConfirm}
              disabled={isLoading}
              className='flex-1/2 bg-brand-main text-icontext'
            >
              {isLoading && (
                <LoadingSpinner className='mr-2 h-4 w-4 animate-spin' />
              )}
              {confirmDialog.confirmText || t('confirm')}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
