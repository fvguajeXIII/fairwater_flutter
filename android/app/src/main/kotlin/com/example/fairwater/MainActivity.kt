package com.example.fairwater

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "fairwater/refill_geofence"
    private val preferencesName = "fairwater_refill_geofences"
    private val barsKey = "bars"
    private val cooldownKey = "cooldown_minutes"
    private lateinit var geofencingClient: GeofencingClient

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        geofencingClient = LocationServices.getGeofencingClient(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncGeofences" -> {
                        val bars = call.argument<List<Map<String, Any>>>("bars").orEmpty()
                        val cooldownMinutes = call.argument<Int>("cooldownMinutes") ?: 120
                        syncGeofences(bars, cooldownMinutes, result)
                    }
                    "clearGeofences" -> clearGeofences(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun syncGeofences(
        bars: List<Map<String, Any>>,
        cooldownMinutes: Int,
        result: MethodChannel.Result
    ) {
        if (!hasLocationPermission()) {
            result.success(false)
            return
        }

        val validBars = bars.take(100).mapNotNull { bar ->
            val id = bar["id"] as? String ?: return@mapNotNull null
            val name = bar["name"] as? String ?: return@mapNotNull null
            val latitude = (bar["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val longitude = (bar["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val radius = (bar["radiusMeters"] as? Number)?.toFloat() ?: return@mapNotNull null
            RefillGeofenceBar(id, name, latitude, longitude, radius)
        }

        saveBars(validBars, cooldownMinutes)

        val pendingIntent = geofencePendingIntent()
        geofencingClient.removeGeofences(pendingIntent).addOnCompleteListener {
            if (validBars.isEmpty()) {
                result.success(true)
                return@addOnCompleteListener
            }

            val geofences = validBars.map { bar ->
                Geofence.Builder()
                    .setRequestId(bar.id)
                    .setCircularRegion(bar.latitude, bar.longitude, bar.radiusMeters)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .build()
            }

            val request = GeofencingRequest.Builder()
                .addGeofences(geofences)
                .build()

            geofencingClient.addGeofences(request, pendingIntent)
                .addOnSuccessListener { result.success(true) }
                .addOnFailureListener { error ->
                    result.error("geofence_sync_failed", error.message, null)
                }
        }
    }

    private fun clearGeofences(result: MethodChannel.Result) {
        geofencingClient.removeGeofences(geofencePendingIntent())
            .addOnCompleteListener {
                getSharedPreferences(preferencesName, MODE_PRIVATE).edit().clear().apply()
                result.success(true)
            }
    }

    private fun hasLocationPermission(): Boolean {
        val fineGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val foregroundGranted = fineGranted || coarseGranted

        if (!foregroundGranted) {
            return false
        }

        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun saveBars(bars: List<RefillGeofenceBar>, cooldownMinutes: Int) {
        val serializedBars = bars.joinToString("\n") { bar ->
            listOf(
                bar.id.encodeForStorage(),
                bar.name.encodeForStorage(),
                bar.latitude.toString(),
                bar.longitude.toString(),
                bar.radiusMeters.toString()
            ).joinToString("|")
        }

        getSharedPreferences(preferencesName, MODE_PRIVATE).edit()
            .putString(barsKey, serializedBars)
            .putInt(cooldownKey, cooldownMinutes)
            .apply()
    }

    private fun geofencePendingIntent(): PendingIntent {
        val intent = Intent(this, RefillGeofenceReceiver::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(this, 0, intent, flags)
    }

    private fun String.encodeForStorage(): String =
        replace("%", "%25").replace("|", "%7C").replace("\n", "%0A")
}

data class RefillGeofenceBar(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Float
)
