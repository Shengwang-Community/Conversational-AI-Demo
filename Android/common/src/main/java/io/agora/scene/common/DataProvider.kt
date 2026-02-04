package io.agora.scene.common

interface DataProvider {
    fun rtcAppId(): String
    fun rtcAppCert(): String
    fun toolboxHost(): String
    fun appBuildNo(): String
    fun appVersionCode(): Int
    fun appVersionName(): String
}