import AgoraRTM, { type RTMClient, type SubscribeOptions } from 'agora-rtm'

import { NotFoundError } from '@/conversational-ai-api/type'
import { factoryFormatLog, logger } from  '../utils/logger'

const formatLog = factoryFormatLog({ tag: 'RTMHelper' })

/**
 * RTMHelper manages the Agora RTM (Real-Time Messaging) client lifecycle.
 *
 * Provides singleton access to an RTM client with methods for initialization,
 * authentication, channel subscription, and cleanup.
 *
 * @remarks
 * - Uses singleton pattern; access via {@link getInstance}
 * - Must call {@link initClient} before {@link login} and {@link join}
 */
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

  /**
   * Initializes the RTM client with the given app and user IDs.
   *
   * @param params - Initialization parameters
   * @param params.app_id - The Agora App ID
   * @param params.user_id - The user ID for this client
   * @returns The initialized RTM client
   */
  public initClient({
    app_id,
    user_id
  }: {
    app_id: string
    user_id: string
  }): RTMClient {
    if (this.client) {
      logger.warn(formatLog('initClient', 'Already initialized, skipping'))
      return this.client
    }
    this.client = new AgoraRTM.RTM(app_id, user_id)
    logger.info(
      formatLog(
        'initClient',
        `Initialized, app_id: ${app_id}, user_id: ${user_id}`
      )
    )
    return this.client
  }

  /**
   * Authenticates the RTM client with the provided token.
   *
   * @param token - The authentication token
   * @returns The authenticated RTM client
   * @throws {@link NotFoundError} When client is not initialized or token is missing
   */
  public async login(token?: string | null): Promise<RTMClient> {
    if (!this.client) {
      throw new NotFoundError('RTM client is not initialized')
    }
    if (!token) {
      throw new NotFoundError('Token is required for RTM login')
    }
    try {
      await this.client.login({ token })
      logger.info(formatLog('login', 'Logged in successfully'))
      return this.client
    } catch (error) {
      logger.error(formatLog('login', 'Login failed', error))
      throw error
    }
  }

  /**
   * Subscribes to an RTM channel.
   *
   * @param channel - The channel name to subscribe to
   * @param options - Optional subscription options
   * @throws {@link NotFoundError} When client is not initialized
   */
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
      logger.info(formatLog('join', `Joined channel: ${channel}`))
    } catch (error) {
      logger.error(formatLog('join', `Join channel failed: ${channel}`, error))
      throw error
    }
  }

  /**
   * Unsubscribes from the current channel, removes all event listeners,
   * and logs out the RTM client.
   */
  public async exitAndCleanup(): Promise<void> {
    if (!this.client) {
      logger.info(formatLog('exitAndCleanup', 'No RTM client, skipping'))
      return
    }
    try {
      if (this.channel) {
        await this.client.unsubscribe(this.channel)
        logger.debug(
          formatLog(
            'exitAndCleanup',
            `Unsubscribed from channel: ${this.channel}`
          )
        )
        this.channel = null
      }
      // Remove all event listeners before logout to prevent memory leaks
      this.client.removeAllListeners()
      await this.client.logout()
      logger.info(formatLog('exitAndCleanup', 'Logged out successfully'))
    } catch (error) {
      logger.error(formatLog('exitAndCleanup', 'Logout failed', error))
      throw error
    }
  }
}
