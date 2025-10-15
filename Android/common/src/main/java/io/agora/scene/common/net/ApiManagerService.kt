package io.agora.scene.common.net;

import okhttp3.MultipartBody
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import okhttp3.RequestBody

interface ApiManagerService {

    companion object {
        const val requestUploadLog = "v1/convoai/upload/log"
    }

    @GET("v1/convoai/sso/userInfo")
    suspend fun ssoUserInfo(@Header("Authorization") token: String): BaseResponse<SSOUserInfo>

    @Multipart
    @POST("v1/convoai/upload/log")
    suspend fun requestUploadLog(
        @Header("Authorization") token: String,
        @Part("content") content: RequestBody,
        @Part file: MultipartBody.Part
    ): BaseResponse<Unit>

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

    @Multipart
    @POST("v1/convoai/upload/file")
    suspend fun uploadFile(
        @Header("Authorization") token: String,
        @Part("request_id") requestId: RequestBody,
        @Part("src") src: RequestBody,
        @Part("app_id") appId: RequestBody,
        @Part("channel_name") channelName: RequestBody,
        @Part file: MultipartBody.Part
    ): BaseResponse<UploadFile>

    @POST("v1/convoai/sso/user/update")
    suspend fun updateUserInfo(
        @Header("Authorization") token: String,
        @retrofit2.http.Body request: UpdateUserInfoRequest
    ): BaseResponse<Unit>
}
