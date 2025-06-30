import AgoraRTM, { type RTMClient, type SubscribeOptions } from 'agora-rtm'

import { NotFoundError } from '@/conversational-ai-api/type'

export class RTMHelper {
  static NAME = 'RTMHelper'
  static VERSION = '1.0.0'
  private static _instance: RTMHelper

  private channel: string | null = null

  public client: RTMClient | null = null

  public static getInstance(): RTMHelper {
    if (!RTMHelper._instance) {
      RTMHelper._instance = new RTMHelper()
    }
    return RTMHelper._instance
  }

  private constructor() {}

  public initClient({
    app_id,
    user_id,
  }: {
    app_id: string
    user_id: string
  }): RTMClient {
    if (this.client) {
      console.warn(
        `${RTMHelper.NAME} already initialized, skipping re-initialization`
      )
      return this.client
    }
    this.client = new AgoraRTM.RTM(app_id, user_id)
    return this.client
  }

  public async login(token?: string | null): Promise<RTMClient> {
    if (!this.client) {
      throw new NotFoundError('RTM client is not initialized')
    }
    if (!token) {
      throw new NotFoundError('Token is required for RTM login')
    }
    try {
      await this.client.login({ token })
      console.log(`${RTMHelper.NAME} logged in successfully`)
      return this.client
    } catch (error) {
      console.error(`${RTMHelper.NAME} login failed:`, error)
      throw error
    }
  }

  public async join(
    channel: string,
    options?: SubscribeOptions
  ): Promise<void> {
    if (!this.client) {
      throw new NotFoundError('RTM client is not initialized')
    }
    try {
      await this.client.subscribe(channel, options)
      this.channel = channel
      console.log(`${RTMHelper.NAME} joined channel: ${channel}`)
    } catch (error) {
      console.error(`${RTMHelper.NAME} join channel failed:`, error)
      throw error
    }
  }

  public async exitAndCleanup(): Promise<void> {
    if (!this.client) {
      throw new NotFoundError('RTM client is not initialized')
    }
    if (!this.channel) {
      throw new NotFoundError('No channel to unsubscribe from')
    }
    try {
      await this.client.unsubscribe(this.channel)
      this.channel = null
      await this.client.logout()
      console.log(`${RTMHelper.NAME} logged out successfully`)
    } catch (error) {
      console.error(`${RTMHelper.NAME} logout failed:`, error)
      throw error
    }
  }
}
