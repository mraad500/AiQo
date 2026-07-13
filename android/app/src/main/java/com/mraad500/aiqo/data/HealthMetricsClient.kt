package com.mraad500.aiqo.data

import android.content.Context
import android.net.Uri

/**
 * قارئ مقاييس الجسم من تطبيق صحة Salam OS — القناة الرسمية الوحيدة للأرقام
 * الحقيقية (content://os.aiqo.health.metrics، بإذن توقيع). تطبيق الصحة يملك
 * الحسّاسات؛ AiQo يعرض. القيمة الغائبة تبقى null — الواجهة تعرض «—» لا رقمًا
 * مزيّفًا.
 */
object HealthMetricsClient {

    data class Metrics(
        val stepsToday: Int?,
        val sleepMinutes: Int?,
        val heartBpm: Int?,
        /** مصدر الخطوات كما يعلنه تطبيق الصحة (hardware_counter / accelerometer_foreground / none). */
        val stepsDetail: String?,
    )

    private val METRICS_URI: Uri = Uri.parse("content://os.aiqo.health.metrics")

    /** blocking — نادِها من خيط IO. `null` = تطبيق الصحة غير متاح. */
    fun read(context: Context): Metrics? = runCatching {
        context.contentResolver.query(METRICS_URI, null, null, null, null)?.use { cursor ->
            val keyIdx = cursor.getColumnIndex("key")
            val valueIdx = cursor.getColumnIndex("value")
            val detailIdx = cursor.getColumnIndex("detail")
            var steps: Int? = null
            var sleep: Int? = null
            var heart: Int? = null
            var stepsDetail: String? = null
            while (cursor.moveToNext()) {
                val value = cursor.getString(valueIdx).orEmpty()
                when (cursor.getString(keyIdx)) {
                    "steps_today" -> {
                        steps = value.toIntOrNull()
                        stepsDetail = cursor.getString(detailIdx)
                    }
                    "sleep_minutes" -> sleep = value.toIntOrNull()
                    "heart_bpm" -> heart = value.toIntOrNull()
                }
            }
            Metrics(steps, sleep, heart, stepsDetail)
        }
    }.getOrNull()
}
