package io.agora.agent

import io.agora.scene.common.DataProvider

class AppDataProvider : DataProvider {

    override fun rtcAppId(): String {
        return BuildConfig.AG_APP_ID
    }

    override fun rtcAppCert(): String {
        return BuildConfig.AG_APP_CERTIFICATE
    }

    override fun toolboxHost(): String {
        return BuildConfig.TOOLBOX_SERVER_HOST
    }

    override fun appVersionCode(): Int {
        return BuildConfig.VERSION_CODE
    }

    override fun appVersionName(): String {
        return BuildConfig.VERSION_NAME
    }

    override fun appBuildNo(): String {
        return BuildConfig.BUILD_TIMESTAMP
    }

    override fun envName(): String {
        return BuildConfig.BUILD_ENV
    }
}