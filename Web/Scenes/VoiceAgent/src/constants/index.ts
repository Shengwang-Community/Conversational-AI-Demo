export * from '@/constants/agent'
export * from '@/constants/api'

export const DEV_MODE_QUERY_KEY = 'dev'

export const SSO_TOKEN = 'code'
export const SSO_LOGIN_ID = 'loginId'
export const SSO_STATE = 'state'

export const MOBILE_BREAKPOINT = 768

export const MAX_VALIDATE_TIME_MILLISECOND = 1000 * 60 * 60 * 24 * 3 - 1 // 3 days

export const USER_INFO_IMAGE = {
  USER_AGENT_BG_EN: {
    src: '/img/user-info/bg-create-en.png',
    width: 143,
    height: 46.5
  },
  USER_AGENT_BG_CN: {
    src: '/img/user-info/bg-create-cn.png',
    width: 143,
    height: 46.5
  },
  MALE_AVATAR_EN: {
    src: '/img/user-info/male-en.png',
    width: 56,
    height: 44
  },
  MALE_AVATAR_CN: {
    src: '/img/user-info/male-cn.png',
    width: 56,
    height: 44
  },
  FEMALE_AVATAR_EN: {
    src: '/img/user-info/female-en.png',
    width: 56,
    height: 44
  },
  FEMALE_AVATAR_CN: {
    src: '/img/user-info/female-cn.png',
    width: 56,
    height: 44
  }
}

export const ICP_IMAGE = {
  src: '/img/icp.png',
  width: 21,
  height: 20,
  alt: 'icp'
}

export const NET_ICP_URL =
  'https://beian.mps.gov.cn/#/query/webSearch?code=31011002006829'

export const ICP_URL = 'https://beian.miit.gov.cn/#/Integrated/recordQuery'

export const CN_FIRST_NAMES = [
  '暖',
  '柔',
  '轻',
  '淡',
  '微',
  '浅',
  '软',
  '绵',
  '净',
  '纯',
  '空',
  '寂',
  '默',
  '幻',
  '谜',
  '韵',
  '绪',
  '念',
  '思',
  '忆',
  '春',
  '夏',
  '秋',
  '冬',
  '昼',
  '夜',
  '晨',
  '昏',
  '岁',
  '月'
]

export const CN_LAST_NAMES = [
  '春',
  '夏',
  '秋',
  '冬',
  '昼',
  '夜',
  '晨',
  '昏',
  '岁',
  '月'
]

export const EN_NAMES = [
  'Ezra',
  'Pledge',
  'Bonnie',
  'Seeds',
  'Shannon',
  'Red-Haired',
  'Montague',
  'Primavera',
  'Tess'
]
