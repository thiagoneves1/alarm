package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.NotificationOnKillService
import com.gdelataillade.alarm.models.AlarmSettings
import android.content.SharedPreferences

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.Log
import org.json.JSONObject

class AlarmPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private val alarmIds: MutableList<Int> = mutableListOf()
    private var notifOnKillEnabled: Boolean = false
    private var notificationOnKillTitle: String = "Your alarms may not ring"
    private var notificationOnKillBody: String = "You killed the app. Please reopen so your alarms can be rescheduled."

    companion object {
        @JvmStatic
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("AlarmPlugin", "Attached to engine")
        context = flutterPluginBinding.applicationContext

        // Receive method calls from Flutter
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/alarm")
        methodChannel.setMethodCallHandler(this)

        // Receive events from AlarmService and send them to Flutter
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }



    //TODO implement snooze and confirm methods
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d("AlarmPlugin", "Method call: ${call.method}")

        when (call.method) {
            "setAlarm" -> {
                setAlarm(call, result)
            }
            "getHistoryIntents" -> {
                getHistoryIntents()
                result.success(true)
            }
            "stopAlarm" -> {
                val id = call.argument<Int>("id")
                if (id == null) {
                    result.error("INVALID_ID", "Alarm ID is null", null)
                    return
                }

                stopAlarm(id, result)
            }

            "isRinging" -> {
                val id = call.argument<Int>("id")
                val ringingAlarmIds = AlarmService.ringingAlarmIds
                val isRinging = ringingAlarmIds.contains(id)
                result.success(isRinging)
            }
            "setWarningNotificationOnKill" -> {
                if (call.argument<String>("title") != null && call.argument<String>("body") != null) {
                    notificationOnKillTitle = call.argument<String>("title")!!
                    notificationOnKillBody = call.argument<String>("body")!!
                }
                result.success(true)
            }
            "disableWarningNotificationOnKill" -> {
                disableWarningNotificationOnKill(context)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun setAlarm(call: MethodCall, result: Result, customContext: Context? = null) {
        Log.d("AlarmPlugin", "Setting alarm")
        val alarmJsonMap = call.arguments as? Map<String, Any>
        val contextToUse = customContext ?: context

        if (alarmJsonMap != null) {
            val alarm = AlarmSettings.fromJson(alarmJsonMap)
            if (alarm != null) {
                val alarmIntent = createAlarmIntent(contextToUse, call, alarm.id)
                val delayInSeconds = (alarm.dateTime.time - System.currentTimeMillis()) / 1000

                if (delayInSeconds <= 5) {
                    handleImmediateAlarm(contextToUse, alarmIntent, delayInSeconds.toInt())
                } else {
                    handleDelayedAlarm(contextToUse, alarmIntent, delayInSeconds.toInt(), alarm.id, alarm.warningNotificationOnKill)
                }
                alarmIds.add(alarm.id)
                result.success(true)
            } else {
                result.error("INVALID_ALARM", "Failed to parse alarm JSON", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Invalid arguments provided for setAlarm", null)
        }
    }

    fun getHistoryIntents() {
        val sharedPreferences: SharedPreferences = context.getSharedPreferences("AlarmActions", Context.MODE_PRIVATE)
        val allEntries = sharedPreferences.all

        val editor = sharedPreferences.edit()
        for ((key, value) in allEntries) {
            Log.d("AlarmPlugin", "Key: $key, Value: $value")
            if (key.startsWith("action_")) {
                val id = key.removePrefix("action_").toInt()
                val action = value as String
                var map = mapOf("id" to id, "action" to action)


                //send to flutter
                eventSink?.success(map)
                //remove from shared preferences
                editor.remove(key)
                editor.apply()

            }
        }


    }

    fun stopAlarm(id: Int, result: Result? = null) {
        Log.d("AlarmPlugin", "Stopping alarm with ID: $id")
        if (AlarmService.ringingAlarmIds.contains(id)) {
            val stopIntent = Intent(context, AlarmService::class.java)
            stopIntent.action = "STOP_ALARM"
            stopIntent.putExtra("id", id)
            context.stopService(stopIntent)
        }

        // Intent to cancel the future alarm if it's set
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 
            id, 
            alarmIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Cancel the future alarm using AlarmManager
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)

        alarmIds.remove(id)
        if (alarmIds.isEmpty() && notifOnKillEnabled) {
            disableWarningNotificationOnKill(context)
        }

        if (result != null) {
            result.success(true)
        }
    }

    fun createAlarmIntent(context: Context, call: MethodCall, id: Int?): Intent {
        Log.d("AlarmPlugin", "Creating alarm intent with ID: $id")
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        setIntentExtras(alarmIntent, call, id)
        return alarmIntent
    }

    fun setIntentExtras(intent: Intent, call: MethodCall, id: Int?) {
        intent.putExtra("id", id)
        intent.putExtra("assetAudioPath", call.argument<String>("assetAudioPath"))
        intent.putExtra("loopAudio", call.argument<Boolean>("loopAudio"))
        intent.putExtra("vibrate", call.argument<Boolean>("vibrate"))
        intent.putExtra("volume", call.argument<Boolean>("volume"))
        intent.putExtra("fadeDuration", call.argument<Double>("fadeDuration"))
        intent.putExtra("fullScreenIntent", call.argument<Boolean>("fullScreenIntent"))

        val notificationSettingsMap = call.argument<Map<String, Any>>("notificationSettings")
        val notificationSettingsJson = JSONObject(notificationSettingsMap ?: emptyMap<String, Any>()).toString()
        intent.putExtra("notificationSettings", notificationSettingsJson)
    }

    fun handleImmediateAlarm(context: Context, intent: Intent, delayInSeconds: Int) {
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            context.sendBroadcast(intent)
        }, delayInSeconds * 1000L)
    }

    fun handleDelayedAlarm(context: Context, intent: Intent, delayInSeconds: Int, id: Int, warningNotificationOnKill: Boolean) {
        try {
            val triggerTime = System.currentTimeMillis() + delayInSeconds * 1000L
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: throw IllegalStateException("AlarmManager not available")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }

            if (warningNotificationOnKill && !notifOnKillEnabled) {
                setWarningNotificationOnKill(context)
            }
        } catch (e: ClassCastException) {
            Log.e("AlarmPlugin", "AlarmManager service type casting failed", e)
        } catch (e: IllegalStateException) {
            Log.e("AlarmPlugin", "AlarmManager service not available", e)
        } catch (e: Exception) {
            Log.e("AlarmPlugin", "Error in handling delayed alarm", e)
        }
    }

    fun setWarningNotificationOnKill(context: Context) {
        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        serviceIntent.putExtra("title", notificationOnKillTitle)
        serviceIntent.putExtra("body", notificationOnKillBody)

        context.startService(serviceIntent)
        notifOnKillEnabled = true
    }

    fun disableWarningNotificationOnKill(context: Context) {
        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        context.stopService(serviceIntent)
        notifOnKillEnabled = false
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}