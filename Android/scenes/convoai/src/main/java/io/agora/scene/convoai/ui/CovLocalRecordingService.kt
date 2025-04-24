package io.agora.scene.convoai.ui

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import io.agora.scene.common.R
import io.agora.scene.convoai.CovLogger

class CovLocalRecordingService : android.app.Service() {
    companion object {
        private const val NOTIFICATION_ID = 1234567888
        private const val CHANNEL_ID = "CovLocalRecordingService"
        private const val TAG = "CovLocalRecordingService"
    }

    override fun onCreate() {
        super.onCreate()
        val notification: Notification = this.defaultNotification

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                this.startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                this.startForeground(NOTIFICATION_ID, notification)
            }
        } catch (ex: Exception) {
            CovLogger.e(TAG, message = "${ex.message}")
        }
    }

    override fun onBind(intent: Intent?): android.os.IBinder? {
        return null
    }

    private val defaultNotification: Notification
        get() {
            val appInfo: android.content.pm.ApplicationInfo = this.applicationContext.applicationInfo
            val name: String = this.applicationContext.packageManager.getApplicationLabel(appInfo).toString()
            var icon: Int = appInfo.icon

            try {
                val iconBitMap: android.graphics.Bitmap? =
                    android.graphics.BitmapFactory.decodeResource(this.applicationContext.resources, icon)
                if (iconBitMap == null || iconBitMap.getByteCount() == 0) {
                    CovLogger.e(TAG, "Couldn't load icon from icon of applicationInfo, use android default")
                    icon = R.mipmap.ic_launcher
                }
            } catch (ex: Exception) {
                CovLogger.e(TAG, "Couldn't load icon from icon of applicationInfo, use android default")
                icon = R.mipmap.ic_launcher
            }

            val intent = Intent(this, CovLivingActivity::class.java)
            intent.setAction("io.agora.api.example.ACTION_NOTIFICATION_CLICK")
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val requestCode = System.currentTimeMillis().toInt()

            val activityPendingIntent = PendingIntent.getActivity(
                this, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val builder: Notification.Builder?
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val mChannel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT)
                val mNotificationManager = this.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                mNotificationManager.createNotificationChannel(mChannel)
                builder = Notification.Builder(this, CHANNEL_ID)
            } else {
                builder = Notification.Builder(this)
            }

            builder.setContentTitle(getString(io.agora.scene.convoai.R.string.cov_detail_agent_title))
                .setContentText(getString(io.agora.scene.convoai.R.string.cov_notification_content))
                .setContentIntent(activityPendingIntent)
                .setAutoCancel(true)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .setSmallIcon(icon)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setWhen(System.currentTimeMillis())
            return builder.build()
        }
}