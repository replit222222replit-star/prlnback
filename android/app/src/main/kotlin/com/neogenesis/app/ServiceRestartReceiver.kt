package com.anvy4ik.neogenesis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ServiceRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Перезапускаем foreground service при убийстве или после перезагрузки
        NeoForegroundService.start(context)
    }
}
