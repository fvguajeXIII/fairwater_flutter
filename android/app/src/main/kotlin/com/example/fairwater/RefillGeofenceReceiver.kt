package com.example.fairwater

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class RefillGeofenceReceiver : BroadcastReceiver() {
    private val preferencesName = "fairwater_refill_geofences"
    private val barsKey = "bars"
    private val cooldownKey = "cooldown_minutes"
    private val lastSentPrefix = "refill_notified_"
    private val channelId = "nearby_refill_channel"
    private val channelName = "Refill vicini"
    private val channelDescription = "Avvisi quando sei vicino a un punto refill."

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent)
        if (event == null || event.hasError()) {
            return
        }
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) {
            return
        }

        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val barsById = loadBars(preferences.getString(barsKey, null))
        val cooldownMillis = preferences.getInt(cooldownKey, 120) * 60_000L
        val now = System.currentTimeMillis()

        event.triggeringGeofences.orEmpty().forEach { geofence ->
            val bar = barsById[geofence.requestId] ?: return@forEach
            val lastSentKey = "$lastSentPrefix${bar.id}"
            val lastSentAt = preferences.getLong(lastSentKey, 0L)
            if (now - lastSentAt < cooldownMillis) {
                return@forEach
            }

            showNotification(context, bar)
            preferences.edit().putLong(lastSentKey, now).apply()
        }
    }

    private fun showNotification(context: Context, bar: StoredRefillBar) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelDescription
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("Punto refill vicino")
            .setContentText("${bar.name} e vicino a te. Passa per un refill nelle vicinanze.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(bar.id.hashCode() and Int.MAX_VALUE, notification)
    }

    private fun loadBars(rawValue: String?): Map<String, StoredRefillBar> {
        if (rawValue.isNullOrBlank()) {
            return emptyMap()
        }

        return rawValue.lineSequence().mapNotNull { line ->
            val parts = line.split("|")
            if (parts.size < 5) {
                return@mapNotNull null
            }

            val id = parts[0].decodeFromStorage()
            StoredRefillBar(id, parts[1].decodeFromStorage())
        }.associateBy { it.id }
    }

    private fun String.decodeFromStorage(): String =
        replace("%0A", "\n").replace("%7C", "|").replace("%25", "%")
}

data class StoredRefillBar(
    val id: String,
    val name: String
)
