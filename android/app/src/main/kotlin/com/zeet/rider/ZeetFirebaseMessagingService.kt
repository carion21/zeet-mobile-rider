package com.zeet.rider

import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * ZeetFirebaseMessagingService — intercepte les messages FCM AVANT que le plugin
 * Flutter ne les traite. Pour les events critiques `delivery.offer`, demarre
 * immediatement [IncomingRingService] (native, plein ecran, sonnerie en boucle).
 */
class ZeetFirebaseMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        private const val TAG = "ZeetMessagingService"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        // Le payload rider utilise `type_value` au top-level, avec `type`
        // comme alias dans metadata — on accepte les deux.
        val type = data["type_value"] ?: data["type"] ?: ""
        Log.d(TAG, "onMessageReceived type=$type")

        if (type.startsWith("delivery.offer") || type == "new_delivery") {
            if (!isAppInForeground()) {
                startRingService(data, message)
            } else {
                Log.d(TAG, "app in foreground, skipping native ring")
            }
        }

        super.onMessageReceived(message)
    }

    private fun startRingService(
        data: Map<String, String>,
        message: RemoteMessage,
    ) {
        val title = data["title"] ?: message.notification?.title ?: "Nouvelle livraison"
        val body = data["body"] ?: message.notification?.body ?: "Appuyez pour voir les details"
        val deliveryId = data["entity_id"] ?: data["delivery_id"] ?: ""

        val intent = Intent(this, IncomingRingService::class.java).apply {
            putExtra(IncomingRingService.EXTRA_DELIVERY_ID, deliveryId)
            putExtra(IncomingRingService.EXTRA_TITLE, title)
            putExtra(IncomingRingService.EXTRA_BODY, body)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForegroundService failed: $e")
        }
    }

    private fun isAppInForeground(): Boolean {
        return try {
            ProcessLifecycleOwner.get()
                .lifecycle
                .currentState
                .isAtLeast(Lifecycle.State.STARTED)
        } catch (e: Exception) {
            false
        }
    }
}
