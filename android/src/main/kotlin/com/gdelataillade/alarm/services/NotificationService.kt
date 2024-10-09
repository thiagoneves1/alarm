package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.models.NotificationSettings
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class NotificationHandler(private val context: Context) {
    companion object {
        private const val CHANNEL_ID = "alarm_plugin_channel"
        private const val CHANNEL_NAME = "Alarm Notification"
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun buildNotification(
        notificationSettings: NotificationSettings,
        fullScreen: Boolean,
        pendingIntent: PendingIntent,
        alarmId: Int
    ): Notification {
        val defaultIconResId = context.packageManager.getApplicationInfo(context.packageName, 0).icon

        val iconResId = if (notificationSettings.icon != null) {
            val resId = context.resources.getIdentifier(notificationSettings.icon, "drawable", context.packageName)
            if (resId != 0) resId else defaultIconResId
        } else {
            defaultIconResId
        }

        val stopIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_STOP
            putExtra("id", alarmId)
        }

        val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_SNOOZE
            putExtra("id", alarmId)
        }

        val confirmIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_CONFIRM
            putExtra("id", alarmId)
        }


        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val confirmPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            confirmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            2,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconResId)
            .setContentTitle(notificationSettings.title)
            .setContentText(notificationSettings.body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setSound(null)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (fullScreen) {
            notificationBuilder.setFullScreenIntent(pendingIntent, true)
        }

        notificationSettings.let {
            if (it.stopButton != null) {
                notificationBuilder.addAction(0, it.stopButton, stopPendingIntent)
            }

            if (it.confirmButton != null) {
                notificationBuilder.addAction(1, it.confirmButton, confirmPendingIntent)
            }

            if (it.snoozeButton != null) {
                notificationBuilder.addAction(2, it.snoozeButton, snoozePendingIntent)
            }
        }

        return notificationBuilder.build()
    }
}