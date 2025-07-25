import { create } from 'zustand'

export type UserInfoStore = {
  globalLoading: boolean
  accountUid: string
  accountType: string
  email: string
  companyId: number
  profileId: number
  displayName: string
  companyName: string
  companyCountry: string
}

export interface IUserInfoStore extends UserInfoStore {
  updateAccountUid: (accountUid: string) => void
  updateAccountType: (accountType: string) => void
  updateEmail: (email: string) => void
  updateCompanyId: (companyId: number) => void
  updateProfileId: (profileId: number) => void
  updateDisplayName: (displayName: string) => void
  updateCompanyName: (companyName: string) => void
  updateCompanyCountry: (companyCountry: string) => void
  updateUserInfo: (userInfo: UserInfoStore) => void
  clearUserInfo: () => void
  updateGlobalLoading: (globalLoading: boolean) => void
}

export const useUserInfoStore = create<IUserInfoStore>((set) => ({
  globalLoading: false,
  updateGlobalLoading: (globalLoading: boolean) => set({ globalLoading }),
  accountUid: '',
  accountType: '',
  email: '',
  verifyPhone: '',
  companyId: 0,
  profileId: 0,
  displayName: '',
  companyName: '',
  companyCountry: '',
  updateAccountUid: (accountUid: string) => set({ accountUid }),
  updateAccountType: (accountType: string) => set({ accountType }),
  updateEmail: (email: string) => set({ email }),
  updateCompanyId: (companyId: number) => set({ companyId }),
  updateProfileId: (profileId: number) => set({ profileId }),
  updateDisplayName: (displayName: string) => set({ displayName }),
  updateCompanyName: (companyName: string) => set({ companyName }),
  updateCompanyCountry: (companyCountry: string) => set({ companyCountry }),
  updateUserInfo: (userInfo: UserInfoStore) => set(userInfo),
  clearUserInfo: () =>
    set({
      accountUid: '',
      accountType: '',
      email: '',
      companyId: 0,
      profileId: 0,
      displayName: '',
      companyName: '',
      companyCountry: ''
    })
}))
