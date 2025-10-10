package io.agora.scene.common.net

import com.google.gson.annotations.SerializedName
import java.io.Serializable

open class BaseResponse<T> : Serializable {
    @SerializedName("errorCode", alternate = ["code"])
    var code: Int? = null

    @SerializedName("message", alternate = ["msg"])
    var message: String? = ""

    @SerializedName(value = "obj", alternate = ["result", "data"])
    var data: T? = null

    val isSuccess: Boolean get() = 0 == code
}

data class SSOUserInfo constructor(
    val accountUid: String,
    val accountType: String = "",
    val email: String = "",
    val verifyPhone: String = "",
    val companyId: Int = 0,
    val profileId: Int = 0,
    var displayName: String = "",
    val companyName: String = "",
    val companyCountry: String = "",
    val nickname: String? = "",
    val gender: String? = "",
    val birthday: String? = "",
    val bio: String? = "",
) : BaseResponse<SSOUserInfo>()

data class UploadImage constructor(
    val img_url: String
) : BaseResponse<UploadImage>()

data class UploadFile constructor(
    val file_url: String,
    val expired_ts: Long,
) : BaseResponse<UploadFile>()

data class UpdateUserInfoRequest constructor(
    val nickname: String,
    val gender: String,
    val birthday: String,
    val bio: String
) : Serializable