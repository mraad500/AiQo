package com.mraad500.aiqo.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.mraad500.aiqo.R

/**
 * Baloo Bhaijaan 2 — خطٌّ عربيٌّ **مدوّر** (variable، محور الوزن) هو الأقرب لمظهر AiQo
 * على iOS (SF Arabic Rounded). نشتقّ الأوزان من الملف المتغيّر الواحد. minSdk 26 يدعم
 * FontVariation. (Tajawal يبقى احتياطًا.)
 */
@OptIn(ExperimentalTextApi::class)
val Baloo = FontFamily(
    Font(R.font.baloo_bhaijaan_2, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.baloo_bhaijaan_2, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
    Font(R.font.baloo_bhaijaan_2, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.baloo_bhaijaan_2, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
    Font(R.font.baloo_bhaijaan_2, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
    Font(R.font.baloo_bhaijaan_2, FontWeight.Black, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
)

/** Tajawal (احتياطي/بديل هندسي). */
val Tajawal = FontFamily(
    Font(R.font.tajawal_regular, FontWeight.Normal),
    Font(R.font.tajawal_medium, FontWeight.Medium),
    Font(R.font.tajawal_bold, FontWeight.Bold),
    Font(R.font.tajawal_extrabold, FontWeight.ExtraBold),
)

/** الخط الأساسي للتطبيق. */
val AiQoFont = Baloo

private val base = Typography()

/** كل أنماط Typography تلبس الخط الأساسي (لمكوّنات Material). */
val AiQoTypography = Typography(
    displayLarge = base.displayLarge.copy(fontFamily = AiQoFont),
    displayMedium = base.displayMedium.copy(fontFamily = AiQoFont),
    displaySmall = base.displaySmall.copy(fontFamily = AiQoFont),
    headlineLarge = base.headlineLarge.copy(fontFamily = AiQoFont),
    headlineMedium = base.headlineMedium.copy(fontFamily = AiQoFont),
    headlineSmall = base.headlineSmall.copy(fontFamily = AiQoFont),
    titleLarge = base.titleLarge.copy(fontFamily = AiQoFont),
    titleMedium = base.titleMedium.copy(fontFamily = AiQoFont),
    titleSmall = base.titleSmall.copy(fontFamily = AiQoFont),
    bodyLarge = base.bodyLarge.copy(fontFamily = AiQoFont),
    bodyMedium = base.bodyMedium.copy(fontFamily = AiQoFont),
    bodySmall = base.bodySmall.copy(fontFamily = AiQoFont),
    labelLarge = base.labelLarge.copy(fontFamily = AiQoFont),
    labelMedium = base.labelMedium.copy(fontFamily = AiQoFont),
    labelSmall = base.labelSmall.copy(fontFamily = AiQoFont),
)
