package com.example.visaia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.text.DateFormat
import java.util.Date

/** Uses the actual Flutter KPI rendering, preserving its fonts, icons and colors. */
class DashboardWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, options: Bundle
    ) {
        render(context, manager, id)
    }

    companion object {
        private fun imageFile(context: Context) = File(context.filesDir, "dashboard_widget.png")

        fun save(context: Context, bytes: ByteArray) {
            // Private app storage survives app closure and launcher restarts.
            imageFile(context).writeBytes(bytes)
            refresh(context)
        }

        fun clear(context: Context) {
            imageFile(context).delete()
            refresh(context)
        }

        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, DashboardWidgetProvider::class.java))
                .forEach { render(context, manager, it) }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.dashboard_widget)
            val image = imageFile(context)
            val bitmap = if (image.exists()) BitmapFactory.decodeFile(image.path) else null
            views.setViewVisibility(R.id.widget_cards, if (bitmap != null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_empty, if (bitmap == null) View.VISIBLE else View.GONE)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_cards, bitmap)
                val updated = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)
                    .format(Date(image.lastModified()))
                views.setTextViewText(R.id.widget_updated, "Updated $updated · Tap to open")
            } else {
                views.setTextViewText(R.id.widget_updated, "Tap to open VISAIA")
            }
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
