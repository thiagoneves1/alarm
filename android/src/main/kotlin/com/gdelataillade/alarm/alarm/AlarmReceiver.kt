package com.gdelataillade.alarm.alarm

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.Log

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ALARM_STOP = "com.gdelataillade.alarm.ACTION_STOP"
        const val ACTION_ALARM_SNOOZE = "com.gdelataillade.alarm.ACTION_SNOOZE"
        const val ACTION_ALARM_CONFIRM = "com.gdelataillade.alarm.ACTION_CONFIRM"
        const val EXTRA_ALARM_ACTION = "EXTRA_ALARM_ACTION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "onReceive action = ${intent.action}")
        val action = intent.action
        if (action == ACTION_ALARM_STOP) {
            intent.putExtra(EXTRA_ALARM_ACTION, "STOP_ALARM")
        }

        if (action == ACTION_ALARM_SNOOZE) {
            intent.putExtra(EXTRA_ALARM_ACTION, "SNOOZE_ALARM")
        }

        if (action == ACTION_ALARM_CONFIRM) {
            intent.putExtra(EXTRA_ALARM_ACTION, "CONFIRM_ALARM")
        }

        // Start Alarm Service
        val serviceIntent = Intent(context, AlarmService::class.java)
        serviceIntent.putExtras(intent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val pendingIntent = PendingIntent.getForegroundService(context, 1, serviceIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            pendingIntent.send()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}