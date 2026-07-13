package com.mraad500.aiqo.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color

val AiQoMint = Color(0xFFC4F0DB)
val AiQoMintDeep = Color(0xFF4CA77C)
val AiQoSand = Color(0xFFF8D6A3)
val AiQoGold = Color(0xFFFFDF63)
val AiQoGoldDeep = Color(0xFFE0B93A)
val AiQoLemon = Color(0xFFFFE68C)
val AiQoInk = Color(0xFF151B18)
val AiQoMuted = Color(0xFF64706A)
val AiQoCanvas = Color(0xFFFFFFFF) // iOS systemBackground (light) — أبيض نقي
val AiQoNight = Color(0xFF101615)

// قيم iOS الحرفية (HomeStatCard.tintColor + DailyAuraView + KernelAtomIcon).
val AiQoMintCard = Color(0xFFC4F0DB)  // (0.77, 0.94, 0.86)
val AiQoPeachCard = Color(0xFFF8D6A3) // (0.97, 0.84, 0.64)
val AiQoCardTitle = Color(0x8C000000) // black 55% — عناوين البطاقات في iOS
val AuraMint = Color(0xFFA3DBCF)      // (0.64, 0.86, 0.81)
val AuraGold = Color(0xFFE8C996)      // (0.91, 0.79, 0.59)
val AiQoDeepMint = Color(0xFF5ECDB7)  // (0.369, 0.804, 0.718)
val AiQoDeepGold = Color(0xFFE0BD74)  // (0.878, 0.741, 0.455)
val MintShadow = Color(0x598CCCB3)    // (0.55,0.80,0.70) @35% — ظل البطاقة النعناعية
val SandShadow = Color(0x59D9B373)    // (0.85,0.70,0.45) @35% — ظل البطاقة الرملية

private val LightColors = lightColorScheme(
    primary = AiQoMintDeep,
    onPrimary = Color.White,
    secondary = AiQoSand,
    onSecondary = AiQoInk,
    tertiary = AiQoGold,
    onTertiary = AiQoInk,
    background = AiQoCanvas,
    onBackground = AiQoInk,
    surface = Color.White,
    onSurface = AiQoInk,
    surfaceVariant = Color(0xFFEAF4EF),
    onSurfaceVariant = AiQoMuted,
)

private val DarkColors = darkColorScheme(
    primary = AiQoMint,
    onPrimary = AiQoNight,
    secondary = AiQoSand,
    onSecondary = AiQoNight,
    tertiary = AiQoGold,
    onTertiary = AiQoNight,
    background = AiQoNight,
    onBackground = Color(0xFFEAF4EF),
    surface = Color(0xFF18211F),
    onSurface = Color(0xFFEAF4EF),
    surfaceVariant = Color(0xFF26312E),
    onSurfaceVariant = Color(0xFFB8C4BE),
)

@Composable
fun AiQoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = AiQoTypography,
    ) {
        // كل نصٍّ عارٍ (بلا style صريح) يرث الخط الأساسي (Baloo المدوّر).
        CompositionLocalProvider(
            LocalTextStyle provides LocalTextStyle.current.copy(fontFamily = AiQoFont),
            content = content,
        )
    }
}
