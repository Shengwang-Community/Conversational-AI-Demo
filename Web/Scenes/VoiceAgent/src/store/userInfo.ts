import { create, type StateCreator } from 'zustand'
import { devtools } from 'zustand/middleware'
import type { UserAgentPreference } from '@/components/layout/user-info/schema'

type UserInfoSlice = {
  globalLoading: boolean
  accountUid: string
  accountType: string
  email: string
  // verifyPhone: string
  companyId: number
  profileId: number
  displayName: string
  companyName: string
  companyCountry: string
  updateAccountUid: (accountUid: string) => void
  updateAccountType: (accountType: string) => void
  updateEmail: (email: string) => void
  // updateVerifyPhone: (verifyPhone: string) => void
  updateCompanyId: (companyId: number) => void
  updateProfileId: (profileId: number) => void
  updateDisplayName: (displayName: string) => void
  updateCompanyName: (companyName: string) => void
  updateCompanyCountry: (companyCountry: string) => void
  updateUserInfo: (userInfo: UserInfoSlice) => void
  updateGlobalLoading: (globalLoading: boolean) => void
}

type UserAgentSlice = {
  userAgentPreference: UserAgentPreference
  updateUserAgentPreference: (preference: UserAgentPreference) => void
}

type UserInfoStore = UserInfoSlice &
  UserAgentSlice & {
    clearUserInfo: () => void
  }

const createUserInfoSlice: StateCreator<
  UserInfoStore,
  [['zustand/devtools', never]],
  [],
  UserInfoSlice
> = (set) => ({
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
  // updateVerifyPhone: (verifyPhone: string) => set({ verifyPhone }),
  updateCompanyId: (companyId: number) => set({ companyId }),
  updateProfileId: (profileId: number) => set({ profileId }),
  updateDisplayName: (displayName: string) => set({ displayName }),
  updateCompanyName: (companyName: string) => set({ companyName }),
  updateCompanyCountry: (companyCountry: string) => set({ companyCountry }),
  updateUserInfo: (userInfo: UserInfoSlice) => set(userInfo)
})

const createUserAgentSlice: StateCreator<
  UserInfoStore,
  [['zustand/devtools', never]],
  [],
  UserAgentSlice
> = (set) => ({
  userAgentPreference: {},
  updateUserAgentPreference: (preference: UserAgentPreference) =>
    set({ userAgentPreference: preference })
})

export const useUserInfoStore = create<UserInfoStore>()(
  devtools((...args) => ({
    ...createUserInfoSlice(...args),
    ...createUserAgentSlice(...args),
    clearUserInfo: () =>
      args[0]({
        accountUid: '',
        accountType: '',
        email: '',
        // verifyPhone: '',
        companyId: 0,
        profileId: 0,
        displayName: '',
        companyName: '',
        companyCountry: '',
        userAgentPreference: {}
      })
  }))
)
