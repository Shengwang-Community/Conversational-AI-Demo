import type { Metadata } from "next"
import { Inter } from "next/font/google"
import { type AbstractIntlMessages, NextIntlClientProvider } from "next-intl"
import { getLocale, getMessages } from "next-intl/server"
import { NuqsAdapter } from "nuqs/adapters/next/app"

import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/sonner"
import { MOTD } from "@/components/Layout/MOTD"

import "./globals.css"

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
})

export async function generateMetadata(): Promise<Metadata> {
  const messages = await getMessages()

  return {
    title: (messages?.metadata as AbstractIntlMessages)?.title || "ConvoAI",
    description:
      (messages?.metadata as AbstractIntlMessages)?.description || "ConvoAI",
  } as Metadata
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  const locale = await getLocale()
  const messages = await getMessages()

  return (
    <html lang={locale} suppressHydrationWarning>
      <body className={`${inter.variable} font-sans antialiased`}>
        <NextIntlClientProvider messages={messages}>
          <ThemeProvider
            attribute="class"
            forcedTheme="dark"
            defaultTheme="dark"
            enableSystem
            disableTransitionOnChange
          >
            <NuqsAdapter>{children}</NuqsAdapter>
            <Toaster
              richColors
              visibleToasts={1}
              closeButton
              position="top-center"
            />
          </ThemeProvider>
        </NextIntlClientProvider>
        <MOTD />
      </body>
    </html>
  )
}
