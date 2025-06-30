import { NextRequest, NextResponse } from "next/server"

import { inputSchema, genAgoraToken } from "./utils"
import { REMOTE_TOKEN_GENERATE } from "@/constants"
import { getEndpointFromNextRequest } from "@/app/api/_utils"

import { logger } from "@/lib/logger"

export async function POST(request: NextRequest) {
  const { tokenServer, agentServer, appId, devMode, endpoint, appCert } =
    getEndpointFromNextRequest(request)

  const url = `${tokenServer}${REMOTE_TOKEN_GENERATE}`

  logger.info(
    { tokenServer, agentServer, appId, devMode, endpoint, url, appCert },
    "getEndpointFromNextRequest"
  )

  try {
    const body = await request.json()
    logger.info({ body }, "request body")
    const { uid } = inputSchema.parse(body)

    const resData = await genAgoraToken(
      {
        appId,
        appCertificate: appCert,
        uid: `${uid}`,
        channelName: "*",
        expire: 86400,
        types: [1, 2, 3],
        src: "web",
      },
      url
    )
    return NextResponse.json({
      code: resData.code,
      data: {
        token: resData.data.token,
        appId: appId,
      },
    })
  } catch (error) {
    console.error({ error }, "error")
    return NextResponse.json(
      { code: 1, msg: "Invalid request", error },
      { status: 400 }
    )
  }
}
