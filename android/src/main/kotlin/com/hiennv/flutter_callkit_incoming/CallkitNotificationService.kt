package com.hiennv.flutter_callkit_incoming

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.content.ContextCompat

class CallkitNotificationService : Service() {

    companion object {

        private val ActionForeground = listOf(
            CallkitConstants.ACTION_CALL_START,
            CallkitConstants.ACTION_CALL_CONNECTED,
            CallkitConstants.ACTION_CALL_ACCEPT
        )


        fun startServiceWithAction(context: Context, action: String, data: Bundle?) {
            val intent = Intent(context, CallkitNotificationService::class.java).apply {
                this.action = action
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && intent.action in ActionForeground) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, CallkitNotificationService::class.java)
            context.stopService(intent)
        }

    }

    private val callkitNotificationManager: CallkitNotificationManager? = FlutterCallkitIncomingPlugin.getInstance().getCallkitNotificationManager()
    private val callkitSoundPlayerManager: CallkitSoundPlayerManager? = FlutterCallkitIncomingPlugin.getInstance().getCallkitSoundPlayerManager()



    override fun onCreate() {
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action === CallkitConstants.ACTION_CALL_START) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    FlutterCallkitIncomingPlugin.getInstance().getCallkitNotificationManager()?.createNotificationChanel(it)
                    showOngoingCallNotification(it, false)
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_CONNECTED) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let { showOngoingCallNotification(it, true) }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_ACCEPT) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    callkitNotificationManager?.clearIncomingNotification(it, true)
                    callkitSoundPlayerManager?.stop()
                    if (it.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW, true)) {
                        showOngoingCallNotification(it, false)
                    }
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_DECLINE) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    callkitNotificationManager?.clearIncomingNotification(it, false)
                    stopSelf()
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_ENDED) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    callkitNotificationManager?.clearIncomingNotification(it, false)
                    stopSelf()
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_TIMEOUT) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    callkitSoundPlayerManager?.stop()
                    if (it.getBoolean(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_SHOW, true)) {
                        callkitNotificationManager?.showMissCallNotification(it)
                    }
                    stopSelf()
                }
        }
        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun showOngoingCallNotification(bundle: Bundle, isConnected: Boolean? = false) {


        val callkitNotification =
            this.callkitNotificationManager?.getOnGoingCallNotification(bundle, isConnected)
        if (callkitNotification != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    callkitNotification.id,
                    callkitNotification.notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
                )
            } else {
                startForeground(callkitNotification.id, callkitNotification.notification)
            }
        }
    }


    override fun onDestroy() {
        super.onDestroy()
        callkitNotificationManager?.destroy()
        callkitSoundPlayerManager?.destroy()
    }


    override fun onBind(p0: Intent?): IBinder? {
        return null;
    }


}

