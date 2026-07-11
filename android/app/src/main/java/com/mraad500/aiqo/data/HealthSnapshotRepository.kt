package com.mraad500.aiqo.data

data class AndroidHealthSnapshot(
    val steps: String,
    val stepsGoal: String,
    val hydration: String,
    val hydrationRemaining: String,
    val sleep: String,
    val sleepQuality: String,
    val aura: String,
    val auraLabel: String,
    val sourceLabel: String,
)

object HealthSnapshotRepository {
    fun currentSnapshot(): AndroidHealthSnapshot =
        AndroidHealthSnapshot(
            steps = "4,962",
            stepsGoal = "هدف اليوم 8,000",
            hydration = "1.4L",
            hydrationRemaining = "بعدك 0.8L",
            sleep = "6h 40m",
            sleepQuality = "تعافي متوسط",
            aura = "78",
            auraLabel = "مزاج مستقر",
            sourceLabel = "Mock data. Health Connect يجي بالمرحلة الجاية.",
        )
}
