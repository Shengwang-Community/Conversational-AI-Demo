package io.agora.scene.common.net;

import okhttp3.MultipartBody
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Query
import okhttp3.RequestBody

interface ApiManagerService {

    companion object{
        const val requestUploadLog = "v1/convoai/upload/log"
        const val ssoUserInfo = "v1/convoai/sso/userInfo"
    }

    @GET(ssoUserInfo)
    suspend fun ssoUserInfo(@Header("Authorization") token: String): BaseResponse<SSOUserInfo>

    @Multipart
    @POST("v1/convoai/upload/log")
    suspend fun requestUploadLog(
        @Header("Authorization") token: String,
        @Part("content") content: RequestBody,
        @Part file: MultipartBody.Part
    ): BaseResponse<Unit>

    /**
     * Uploads a base64 encoded image to CDN and returns the CDN URL.
     * @param token Authorization token
     * @param body JSON body containing base64 image string
     * @return CDN URL in response
     */
    @Multipart
    @POST("v1/convoai/upload/image")
    suspend fun uploadImage(
        @Header("Authorization") token: String,
        @Part("request_id") requestId: RequestBody,
        @Part("src") src: RequestBody,
        @Part("app_id") appId: RequestBody,
        @Part("channel_name") channelName: RequestBody,
        @Part image: MultipartBody.Part
    ): BaseResponse<UploadImage>
}
