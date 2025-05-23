'use client'

import * as React from 'react'
import packageInfo from '../../../package.json'

const ASCII_ART = `

██████  ██████  ███    ██ ██    ██  ██████       █████  ██ 
██      ██    ██ ████   ██ ██    ██ ██    ██     ██   ██ ██ 
██      ██    ██ ██ ██  ██ ██    ██ ██    ██     ███████ ██ 
██      ██    ██ ██  ██ ██  ██  ██  ██    ██     ██   ██ ██ 
 ██████  ██████  ██   ████   ████    ██████      ██   ██ ██ 
                                                            
                                                                                           
`

const packageMetaList = [
  {
    name: 'Name',
    value: packageInfo.name,
  },
  {
    name: 'Version',
    value: packageInfo.version,
  },
]

const separator = '\n--------------------------------\n'

// Message of the Day
export const MOTD = () => {
  React.useEffect(() => {
    console.log(ASCII_ART)
    console.log(
      separator +
        packageMetaList
          .map((meta) => `${meta.name}: ${meta.value}`)
          .join('\n') +
        separator
    )
  }, [])

  return null
}
