package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.AudioService
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.services.VibrationService
import com.gdelataillade.alarm.services.VolumeService
import com.gdelataillade.alarm.models.NotificationSettings

import android.app.Service
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.ForegroundServiceStartNotAllowedException
import android.content.Intent
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.PowerManager
import android.os.Build
import io.flutter.Log
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.FlutterEngine
import org.json.JSONObject
import android.content.SharedPreferences

class AlarmService : Service() {
    private var audioService: AudioService? = null
    private var vibrationService: VibrationService? = null
    private var volumeService: VolumeService? = null
    private var showSystemUI: Boolean = true

    companion object {
        @JvmStatic
        var ringingAlarmIds: List<Int> = listOf()
    }

    override fun onCreate() {
        super.onCreate()

        audioService = AudioService(this)
        vibrationService = VibrationService(this)
        volumeService = VolumeService(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent.getIntExtra("id", 0)
        val action = intent.getStringExtra(AlarmReceiver.EXTRA_ALARM_ACTION)

        Log.d("AlarmService", "ringing alarms: $ringingAlarmIds action $action id $id")
        if (ringingAlarmIds.isNotEmpty() && !ringingAlarmIds.contains(id)) {
            Log.d("AlarmService", "An alarm is already ringing. Ignoring new alarm with id: $id")
            unsaveAlarm(this, id, "ignore")
            return START_NOT_STICKY
        }

        if (action == "STOP_ALARM" && id != 0) {
            unsaveAlarm(this, id, "stop")
            return START_NOT_STICKY
        }

        //TODO implement snooze here on Android side and keep the same alarm id, and we can recovery that in flutter side
        //TODO we can call the alarmPlugin method to snooze the alarm?, otherwise, we need create the alarm like alarmPlugin does
        if (action == "SNOOZE_ALARM" && id != 0) {
            unsaveAlarm(this, id, "snooze")
            return START_NOT_STICKY
        }

        if (action == "CONFIRM_ALARM" && id != 0) {
            unsaveAlarm(this, id, "confirm")
            return START_NOT_STICKY
        }

        val assetAudioPath = intent.getStringExtra("assetAudioPath") ?: return START_NOT_STICKY // Fallback if null
        val loopAudio = intent.getBooleanExtra("loopAudio", true)
        val vibrate = intent.getBooleanExtra("vibrate", true)
        val volume = intent.getDoubleExtra("volume", -1.0)
        val fadeDuration = intent.getDoubleExtra("fadeDuration", 0.0)
        val fullScreenIntent = intent.getBooleanExtra("fullScreenIntent", true)

        val notificationSettingsJson = intent.getStringExtra("notificationSettings")
        val jsonObject = JSONObject(notificationSettingsJson)
        val map: MutableMap<String, Any> = mutableMapOf()
        jsonObject.keys().forEach { key ->
            map[key] = jsonObject.get(key)
        }
        val notificationSettings = NotificationSettings.fromJson(map)

        // Handling notification
        val notificationHandler = NotificationHandler(this)
        val appIntent = applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
        val pendingIntent = PendingIntent.getActivity(this, id, appIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = notificationHandler.buildNotification(notificationSettings, fullScreenIntent, pendingIntent, id)

        // Starting foreground service safely
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(id, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(id, notification)
            }
        } catch (e: ForegroundServiceStartNotAllowedException) {
            Log.e("AlarmService", "Foreground service start not allowed", e)
            return START_NOT_STICKY // Return if cannot start foreground service
        } catch (e: SecurityException) {
            Log.e("AlarmService", "Security exception in starting foreground service", e)
            return START_NOT_STICKY // Return on security exception
        }

        AlarmPlugin.eventSink?.success(mapOf(
            "id" to id,
            "method" to "ring"
        ))

        if (volume >= 0.0 && volume <= 1.0) {
            volumeService?.setVolume(volume, showSystemUI)
        }

        volumeService?.requestAudioFocus()

        audioService?.setOnAudioCompleteListener {
            if (!loopAudio!!) {
                vibrationService?.stopVibrating()
                volumeService?.restorePreviousVolume(showSystemUI)
                volumeService?.abandonAudioFocus()
            }
        }

        audioService?.playAudio(id, assetAudioPath!!, loopAudio!!, fadeDuration!!)

        ringingAlarmIds = audioService?.getPlayingMediaPlayersIds()!!

        if (vibrate!!) {
            vibrationService?.startVibrating(longArrayOf(0, 500, 500), 1)
        }

        // Wake up the device
        val wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "app:AlarmWakelockTag")
        wakeLock.acquire(5 * 60 * 1000L) // 5 minutes

        return START_STICKY
    }

    fun unsaveAlarm(context: Context, id: Int, method: String) {
        Log.d("AlarmService", "Un-saving alarm with id: $id and method: $method")
        AlarmStorage(this).unsaveAlarm(id)
        AlarmPlugin.eventSink?.success(mapOf(
            "id" to id,
            "method" to method
        ))
        storePendingAction(context, method, id)
        stopAlarm(id)
    }

    //case the app is killed, store the pending action and restore it when the app is opened
    fun storePendingAction(context: Context, action: String, id: Int) {
        val sharedPreferences: SharedPreferences = context.getSharedPreferences("AlarmActions", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putString("action_$id", action)
        editor.apply()
    }


    fun stopAlarm(id: Int) {
        try {
            val playingIds = audioService?.getPlayingMediaPlayersIds() ?: listOf()
            ringingAlarmIds = playingIds

            // Safely call methods on 'volumeService' and 'audioService'
            volumeService?.restorePreviousVolume(showSystemUI)
            volumeService?.abandonAudioFocus()

            audioService?.stopAudio(id)

            // Check if media player is empty safely
            if (audioService?.isMediaPlayerEmpty() == true) {
                vibrationService?.stopVibrating()
                stopSelf()
            }

            stopForeground(true)
        } catch (e: IllegalStateException) {
            Log.e("AlarmService", "Illegal State: ${e.message}", e)
        } catch (e: Exception) {
            Log.e("AlarmService", "Error in stopping alarm: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        ringingAlarmIds = listOf()

        audioService?.cleanUp()
        vibrationService?.stopVibrating()
        volumeService?.restorePreviousVolume(showSystemUI)
        volumeService?.abandonAudioFocus()

        stopForeground(true)

        // Call the superclass method
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
