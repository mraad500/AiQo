package com.mraad500.aiqo.ui

import android.speech.tts.TextToSpeech
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Article
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.CenterFocusStrong
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.GppGood
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.RestaurantMenu
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Kitchen
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.MonitorWeight
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.SupportAgent
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.AccessibilityNew
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import androidx.compose.ui.unit.sp
import com.mraad500.aiqo.R
import com.mraad500.aiqo.data.HealthMetricsClient
import com.mraad500.aiqo.ui.theme.AiQoCanvas
import com.mraad500.aiqo.ui.theme.AiQoDeepGold
import com.mraad500.aiqo.ui.theme.AiQoDeepMint
import com.mraad500.aiqo.ui.theme.AiQoGold
import com.mraad500.aiqo.ui.theme.AiQoGoldDeep
import com.mraad500.aiqo.ui.theme.AiQoInk
import com.mraad500.aiqo.ui.theme.AiQoLemon
import com.mraad500.aiqo.ui.theme.AiQoMint
import com.mraad500.aiqo.ui.theme.AiQoMintCard
import com.mraad500.aiqo.ui.theme.AiQoMuted
import com.mraad500.aiqo.ui.theme.AiQoPeachCard
import com.mraad500.aiqo.ui.theme.AiQoSand
import com.mraad500.aiqo.ui.theme.AiQoTheme
import com.mraad500.aiqo.ui.theme.AuraGold
import com.mraad500.aiqo.ui.theme.AuraMint
import com.mraad500.aiqo.ui.theme.MintShadow
import com.mraad500.aiqo.ui.theme.SandShadow
import java.util.Calendar
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlinx.coroutines.delay

// ═══════════════════════════════════════════════════════════════════════════
//  AiQo Android — port of the iOS app UI (Arabic-first, RTL), faithful to the
//  live iOS app (via iPhone Mirroring) + real brand assets. Baloo font.
//  All 4 tabs built: Home · Gym (النادي) · Kitchen (المطبخ) · RoQo (المساعد الذكي).
// ═══════════════════════════════════════════════════════════════════════════

private enum class AiQoTab(val labelAr: String) {
    Home("الرئيسية"),
    Gym("النادي"),
    Kitchen("المطبخ"),
    Captain("Rafiqo"),
    ;

    // أيقونات مطابقة لرموز iOS: house.fill / figure.strengthtraining / fork.knife / wand.and.stars
    val icon: ImageVector
        get() = when (this) {
            Home -> Icons.Filled.Home
            Gym -> GymFigureIcon
            Kitchen -> Icons.Filled.Restaurant
            Captain -> Icons.Filled.AutoFixHigh
        }
}

@Composable
fun AiQoAndroidApp() {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        AiQoTheme(darkTheme = false) {
            var tab by rememberSaveable { mutableStateOf(AiQoTab.Home) }
            var liveWorkout by remember { mutableStateOf<String?>(null) }
            var showProfile by rememberSaveable { mutableStateOf(false) }
            // محادثة الكابتن تعيش هنا كي لا تضيع عند التنقل بين التبويبات.
            val captainChat = remember { mutableStateListOf(CaptainMsg(captainGreeting(), isUser = false)) }
            Box(Modifier.fillMaxSize().background(AiQoCanvas)) {
                when (tab) {
                    AiQoTab.Home -> HomeScreen(onOpenProfile = { showProfile = true })
                    AiQoTab.Gym -> GymScreen(onStartWorkout = { liveWorkout = it }, onOpenProfile = { showProfile = true })
                    AiQoTab.Kitchen -> KitchenScreen(onOpenProfile = { showProfile = true })
                    AiQoTab.Captain -> CaptainScreen(chat = captainChat, onOpenProfile = { showProfile = true })
                }
                AiQoBottomNav(
                    selected = tab,
                    onSelect = { tab = it },
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
                if (showProfile) ProfileScreen(onClose = { showProfile = false })
                liveWorkout?.let { LiveWorkoutScreen(it, onClose = { liveWorkout = null }) }
            }
        }
    }
}

// ── Home — منقولة حرفيًّا من HomeView/DailyAuraView/HomeStatCard/KernelAtomIcon ──

private data class Metric(
    val title: String,
    val value: String,
    val unit: String,
    val icon: ImageVector,
    val sand: Boolean,
)

// أهداف اليوم — نفس هدف تطبيق الصحة (٦٠٠٠ خطوة) وهدف سعرات نشطة هادئ.
private const val STEPS_GOAL = 6_000f
private const val ACTIVE_KCAL_GOAL = 300f

/**
 * صفوف الشبكة بترتيب iOS (خطوات، سعرات، نوم، ماء، وقوف، مسافة — الرملي: النوم والماء).
 * الحقيقي من تطبيق الصحة: الخطوات (والمسافة/السعرات مشتقتان تقديريًّا منها) والنوم
 * (تقدير سلوكي). الغائب يُعرض «—» بصدق؛ الماء/الوقوف بلا مصدر بعد فيبقيان صفرًا.
 */
private fun homeMetrics(m: HealthMetricsClient.Metrics?): List<Metric> {
    val steps = m?.stepsToday
    return listOf(
        Metric("الخطوات", steps?.toString() ?: "—", "", Icons.AutoMirrored.Filled.DirectionsWalk, sand = false),
        Metric("السعرات", steps?.let { (it * 0.04f).toInt().toString() } ?: "—", "kcal", Icons.Filled.LocalFireDepartment, sand = false),
        Metric("النوم", m?.sleepMinutes?.let { "%.1f".format(it / 60f) } ?: "—", "h", Icons.Filled.Bedtime, sand = true),
        Metric("الماء", "0", "L", Icons.Filled.WaterDrop, sand = true),
        Metric("الوقوف", "0", "%", Icons.Outlined.AccessibilityNew, sand = false),
        Metric("المسافة", steps?.let { "%.2f".format(it * 0.75f / 1000f) } ?: "—", "km", Icons.AutoMirrored.Filled.DirectionsRun, sand = false),
    )
}

@Composable
private fun HomeScreen(onOpenProfile: () -> Unit = {}) {
    val context = LocalContext.current
    // الأرقام الحقيقية من تطبيق الصحة — تُقرأ عند الدخول ثم كل ٥ ثوانٍ والشاشة ظاهرة.
    var metrics by remember { mutableStateOf<HealthMetricsClient.Metrics?>(null) }
    LaunchedEffect(Unit) {
        while (true) {
            metrics = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                HealthMetricsClient.read(context)
            }
            delay(5_000)
        }
    }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        // الرأس كما iOS (يفرض LTR): زر Vibe يسارًا، صورة الملف يمينًا. في RTL نضع الأفاتار أولًا.
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Image(
                painter = painterResource(R.drawable.aiqo_profile), contentDescription = "الملف الشخصي",
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(44.dp).clip(CircleShape)
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onOpenProfile() },
            )
            Spacer(Modifier.weight(1f))
            Image(
                painter = painterResource(R.drawable.vibe_icon), contentDescription = "الأجواء",
                modifier = Modifier.size(58.dp)
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                        Toast.makeText(context, "الأجواء — قريباً", Toast.LENGTH_SHORT).show()
                    },
            )
        }
        val steps = metrics?.stepsToday ?: 0
        DailyAura(
            stepsProgress = (steps / STEPS_GOAL).coerceIn(0f, 1f),
            caloriesProgress = (steps * 0.04f / ACTIVE_KCAL_GOAL).coerceIn(0f, 1f),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
        Column(Modifier.padding(horizontal = 14.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
            homeMetrics(metrics).chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    row.forEach { m -> MetricCard(m, Modifier.weight(1f)) }
                }
            }
        }
        Spacer(Modifier.height(26.dp))
        KernelMark()
        Spacer(Modifier.weight(1f))
    }
}

// هالة اليوم (DailyAuraView): 19 قوسًا — الأخضر يتكشّف مع الخطوات والرملي مع السعرات.
private data class AuraSeg(
    val ratio: Float, val start: Float, val end: Float, val width: Float,
    val stage: Int, val green: Boolean, val bucketOrder: Int, val bucketSize: Int,
)

private val AURA_SEGS: List<AuraSeg> = run {
    data class D(val r: Float, val s: Float, val e: Float, val w: Float, val st: Int, val g: Boolean)
    val defs = listOf(
        D(0.14f, 208f, 244f, 3.2f, 0, true), D(0.14f, 262f, 301f, 3.2f, 0, true),
        D(0.14f, 334f, 24f, 3.2f, 0, true), D(0.14f, 45f, 86f, 3.2f, 0, true),
        D(0.14f, 112f, 154f, 3.2f, 0, true), D(0.14f, 174f, 195f, 3.2f, 0, true),
        D(0.21f, 196f, 252f, 3.6f, 1, true), D(0.21f, 272f, 324f, 3.6f, 1, true),
        D(0.21f, 352f, 26f, 3.6f, 1, true), D(0.21f, 66f, 125f, 3.6f, 1, true),
        D(0.21f, 146f, 170f, 3.6f, 1, true),
        D(0.29f, 182f, 350f, 4.2f, 2, true), D(0.29f, 20f, 112f, 4.2f, 2, true),
        D(0.36f, 212f, 9f, 5f, 2, true), D(0.36f, 36f, 164f, 5f, 2, true),
        D(0.43f, 150f, 231f, 6.5f, 3, false), D(0.43f, 283f, 72f, 6.5f, 3, false),
        D(0.52f, 32f, 126f, 6.5f, 3, false), D(0.52f, 166f, 320f, 6.5f, 3, false),
    )
    val sizes = IntArray(4)
    defs.forEach { sizes[it.st]++ }
    val offsets = IntArray(4)
    defs.map { d -> AuraSeg(d.r, d.s, d.e, d.w, d.st, d.g, offsets[d.st]++, maxOf(sizes[d.st], 1)) }
}

/** smoothstep iOS: يكشف أقواس كل مرحلة بالترتيب داخل ربعها من التقدم. */
private fun auraReveal(s: AuraSeg, progress: Float): Float {
    val stageStart = (s.stage + 1) * 0.25f - 0.25f
    val stageProgress = ((progress - stageStart) / 0.25f).coerceIn(0f, 1f)
    val smooth = stageProgress * stageProgress * (3f - 2f * stageProgress)
    return ((smooth * s.bucketSize) - s.bucketOrder).coerceIn(0f, 1f)
}

@Composable
private fun DailyAura(stepsProgress: Float, caloriesProgress: Float, modifier: Modifier = Modifier) {
    // كما iOS: يتكشّف من الصفر عند الدخول (easeInOut ثانية وخمس).
    var revealed by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { revealed = true }
    val sp by animateFloatAsState(if (revealed) stepsProgress else 0f, tween(1_200, easing = FastOutSlowInEasing), label = "خطوات")
    val cp by animateFloatAsState(if (revealed) caloriesProgress else 0f, tween(1_200, easing = FastOutSlowInEasing), label = "سعرات")
    val breath = rememberInfiniteTransition(label = "نبض المركز")
    val centerScale by breath.animateFloat(0.994f, 1.006f, infiniteRepeatable(tween(2_400, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "مقياس")
    val percent = ((stepsProgress + caloriesProgress) / 2f * 100f).roundToInt()

    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Canvas(Modifier.size(172.dp)) {
            val m = size.minDimension
            val c = center
            fun seg(s: AuraSeg, color: Color, fraction: Float) {
                val sweep = ((if (s.end < s.start) s.end + 360f else s.end) - s.start) * fraction
                val r = m * s.ratio
                drawArc(
                    color = color, startAngle = s.start - 90f, sweepAngle = sweep, useCenter = false,
                    topLeft = Offset(c.x - r, c.y - r), size = Size(2 * r, 2 * r),
                    style = Stroke(width = s.width.dp.toPx(), cap = StrokeCap.Round),
                )
            }
            AURA_SEGS.forEach { s -> seg(s, if (s.green) AuraMint.copy(alpha = 0.30f) else AuraGold.copy(alpha = 0.35f), 1f) }
            AURA_SEGS.forEach { s ->
                val reveal = auraReveal(s, if (s.green) sp else cp)
                if (reveal > 0f) seg(s, if (s.green) AuraMint else AuraGold, reveal)
            }
            // المركز المتنفس: قرص خافت + حلقة نعناعية.
            drawCircle(Color(0xFFB8E6DB).copy(alpha = 0.26f), radius = 6.dp.toPx() * centerScale, center = c)
            drawCircle(
                Color(0xFF9EDECF).copy(alpha = 0.58f), radius = 10.dp.toPx() * centerScale, center = c,
                style = Stroke(width = 3.dp.toPx()),
            )
        }
        Text("$percent%", color = AiQoMuted, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
    }
}

@Composable
private fun MetricCard(m: Metric, modifier: Modifier = Modifier) {
    val fill = if (m.sand) AiQoPeachCard else AiQoMintCard
    val shadowTint = if (m.sand) SandShadow else MintShadow
    // تعويمٌ سحابيّ كما iOS: -6dp خلال 5 ثوانٍ بتأخيرٍ عشوائي لكل بطاقة.
    val floatAnim = rememberInfiniteTransition(label = "عوم")
    val delay = remember { (0..2_000).random() }
    val dy by floatAnim.animateFloat(
        0f, -6f,
        infiniteRepeatable(tween(5_000, easing = FastOutSlowInEasing), RepeatMode.Reverse, initialStartOffset = StartOffset(delay)),
        label = "dy",
    )
    Column(
        modifier.offset(y = dy.dp)
            .shadow(10.dp, RoundedCornerShape(24.dp), spotColor = shadowTint, ambientColor = shadowTint)
            .background(Brush.verticalGradient(listOf(fill, fill.copy(alpha = 0.85f))), RoundedCornerShape(24.dp))
            .height(84.dp)
            .padding(horizontal = 16.dp, vertical = 11.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Text(m.title, color = Color.Black.copy(alpha = 0.55f), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(28.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.5f)), contentAlignment = Alignment.Center) {
                Icon(m.icon, contentDescription = null, tint = Color.Black.copy(alpha = 0.4f), modifier = Modifier.size(15.dp))
            }
        }
        Spacer(Modifier.weight(1f))
        // القيمة بأسفل يسار البطاقة (iOS: محاذاة trailing = يسار في RTL) بوحدة صغيرة قبلها.
        Row(
            Modifier.align(Alignment.End).padding(start = 4.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            if (m.unit.isNotEmpty()) {
                Text(m.unit, color = Color.Black.copy(alpha = 0.5f), fontWeight = FontWeight.Medium, fontSize = 13.sp, modifier = Modifier.padding(bottom = 3.dp))
                Spacer(Modifier.width(6.dp))
            }
            Text(m.value, color = Color.Black.copy(alpha = 0.85f), fontWeight = FontWeight.Bold, fontSize = 26.sp, lineHeight = 28.sp)
        }
    }
}

/** «النواة» (KernelAtomIcon): ٣ مدارات مائلة 0/60/120 وإلكترونات تدور ببطء حقيقي. */
@Composable
private fun KernelMark() {
    val orbitAnim = rememberInfiniteTransition(label = "مدارات")
    val a0 by orbitAnim.animateFloat(0f, 360f, infiniteRepeatable(tween(58_000, easing = LinearEasing)), label = "م1")
    val a1 by orbitAnim.animateFloat(0f, 360f, infiniteRepeatable(tween(74_000, easing = LinearEasing)), label = "م2")
    val a2 by orbitAnim.animateFloat(0f, 360f, infiniteRepeatable(tween(50_000, easing = LinearEasing)), label = "م3")
    val dy by orbitAnim.animateFloat(0f, -4f, infiniteRepeatable(tween(2_000, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "عوم")

    Column(
        Modifier.fillMaxWidth().offset(y = dy.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Canvas(Modifier.size(112.dp)) {
            val w = size.minDimension
            val c = center
            val rx = w * 0.42f
            val ry = w * 0.16f
            val lw = w * 0.045f
            data class Orbit(val tilt: Float, val ring: Color, val electron: Color, val angle: Float)
            val orbits = listOf(
                Orbit(0f, AuraMint, AiQoDeepMint, a0),
                Orbit(60f, AuraGold, AiQoDeepGold, a1),
                Orbit(120f, AuraMint, AiQoDeepMint, a2),
            )
            orbits.forEach { o ->
                rotate(o.tilt, pivot = c) {
                    drawOval(
                        color = o.ring.copy(alpha = 0.9f),
                        topLeft = Offset(c.x - rx, c.y - ry), size = Size(2 * rx, 2 * ry),
                        style = Stroke(width = lw, cap = StrokeCap.Round),
                    )
                }
            }
            // توهّج + نواة لؤلؤية.
            val glowR = w * 0.17f
            drawCircle(Brush.radialGradient(listOf(AuraMint.copy(alpha = 0.5f), Color.Transparent), center = c, radius = glowR), glowR, c)
            val coreR = w * 0.095f
            drawCircle(
                Brush.radialGradient(
                    listOf(Color(0xFFEBFDF5), AiQoDeepMint),
                    center = Offset(c.x - coreR * 0.3f, c.y - coreR * 0.3f), radius = coreR * 1.4f,
                ),
                coreR, c,
            )
            // الإلكترونات الراكبة على مداراتها.
            orbits.forEach { o ->
                val a = o.angle * (PI.toFloat() / 180f)
                val ex = rx * cos(a)
                val ey = ry * sin(a)
                val rot = o.tilt * (PI.toFloat() / 180f)
                val p = Offset(c.x + ex * cos(rot) - ey * sin(rot), c.y + ex * sin(rot) + ey * cos(rot))
                drawCircle(o.electron, w * 0.05f, p)
            }
        }
        Text("النواة", color = AiQoMuted, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, letterSpacing = 0.5.sp)
    }
}

// ── Gym (النادي) ─────────────────────────────────────────────────────────────

private enum class GymTab(val ar: String) { Body("الجسم"), Plan("الخطة"), Peaks("قِمَم"), Battle("معركة"), Trace("الأثر") }

private data class Workout(val name: String, val subtitle: String?, val icon: ImageVector, val peach: Boolean)

private val CARDIO_WORKOUTS = listOf(
    Workout("كارديو ويا Rafiqo", "نبض Zone 2 لحرق دهون أذكى", Icons.AutoMirrored.Filled.DirectionsRun, peach = false),
    Workout("الجري بالخارج", null, Icons.Filled.Map, peach = true),
    Workout("الجري", null, Icons.AutoMirrored.Filled.DirectionsRun, peach = false),
    Workout("المشي", null, Icons.AutoMirrored.Filled.DirectionsWalk, peach = true),
    Workout("الدراجات", null, Icons.AutoMirrored.Filled.DirectionsBike, peach = false),
    Workout("السباحة", null, Icons.Filled.Pool, peach = true),
)

@Composable
private fun GymScreen(onStartWorkout: (String) -> Unit = {}, onOpenProfile: () -> Unit = {}) {
    var tab by rememberSaveable { mutableStateOf(GymTab.Body) }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Spacer(Modifier.height(6.dp))
        // كما iOS (topHeaderBar): التبويبات تملأ العرض والأفاتار يمينًا.
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Image(
                painter = painterResource(R.drawable.aiqo_profile), contentDescription = "الملف الشخصي",
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(46.dp).clip(CircleShape)
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onOpenProfile() },
            )
            Spacer(Modifier.width(10.dp))
            GymTabBar(tab, onSelect = { tab = it }, Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        when (tab) {
            GymTab.Body -> GymBody(onStartWorkout)
            GymTab.Plan -> Box(Modifier.padding(horizontal = 14.dp)) { GymPlan() }
            GymTab.Battle -> Box(Modifier.padding(horizontal = 14.dp)) { GymBattle() }
            GymTab.Trace -> Box(Modifier.padding(horizontal = 14.dp)) { GymTrace() }
            GymTab.Peaks -> Box(Modifier.padding(horizontal = 14.dp)) { GymPeaks() }
        }
    }
}

/** شريط iOS المقسّم: خلفية systemGray6 وفقاعة صفراء F9E697 وخانات متساوية العرض. */
@Composable
private fun GymTabBar(selected: GymTab, onSelect: (GymTab) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier.height(50.dp).clip(RoundedCornerShape(25.dp)).background(Color(0xE6F2F2F7)).padding(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GymTab.entries.forEach { t ->
            val active = t == selected
            Box(
                Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(22.dp))
                    .background(if (active) Color(0xFFF9E697) else Color.Transparent)
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onSelect(t) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    t.ar, color = if (active) Color(0xFF1A1A1A) else AiQoInk,
                    fontWeight = if (active) FontWeight.Bold else FontWeight.Medium, fontSize = 13.sp,
                )
            }
        }
    }
}

@Composable
private fun GymBody(onStartWorkout: (String) -> Unit) {
    // كما iOS: المصفّي الجانبي عمود مستقل (68dp) والبطاقات تجاوره — لا تراكب.
    Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.Top) {
        Box(Modifier.width(68.dp).padding(top = 120.dp), contentAlignment = Alignment.TopCenter) { GymRail() }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState())
                .padding(start = 8.dp, end = 16.dp, top = 14.dp, bottom = 110.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            CARDIO_WORKOUTS.forEachIndexed { i, w ->
                WorkoutCard(w, index = i, featured = i == 0, onClick = { onStartWorkout(w.name) })
            }
        }
    }
}

/** بطاقة ClubWorkoutCard: عنوان 20 ثقيل يمينًا + دائرة أيقونة 48 يسارًا + دخول متدرّج. */
@Composable
private fun WorkoutCard(w: Workout, index: Int, featured: Boolean, onClick: () -> Unit = {}) {
    // دخول iOS: خفوت + صعود 22 + تقارب 0.96 بتعاقب 50ms لكل بطاقة.
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(50L * index)
        visible = true
    }
    val appear by animateFloatAsState(if (visible) 1f else 0f, spring(dampingRatio = 0.84f, stiffness = 180f), label = "دخول")
    val fill = if (w.peach) AiQoPeachCard else AiQoMintCard
    Row(
        Modifier.fillMaxWidth()
            .offset(y = (22 * (1f - appear)).dp)
            .scale(0.96f + 0.04f * appear)
            .alpha(appear.coerceIn(0.001f, 1f))
            .heightIn(min = if (featured) 120.dp else 100.dp)
            .shadow(2.dp, RoundedCornerShape(26.dp), spotColor = Color(0x14000000), ambientColor = Color(0x0A000000))
            .background(Brush.verticalGradient(listOf(fill, fill.copy(alpha = 0.85f))), RoundedCornerShape(26.dp))
            .clip(RoundedCornerShape(26.dp))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onClick() }
            .padding(horizontal = 20.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // في RTL: العنوان أولًا فيمينًا، ودائرة الأيقونة أخيرًا فيسارًا.
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(w.name, color = Color(0xFF1A1A1A), fontWeight = FontWeight.Black, fontSize = 20.sp, lineHeight = 26.sp)
            if (featured && w.subtitle != null) {
                Text(w.subtitle, color = Color(0xFF6E6E73), fontWeight = FontWeight.Medium, fontSize = 13.sp)
            }
        }
        Spacer(Modifier.width(12.dp))
        Box(
            Modifier.size(48.dp).shadow(1.dp, CircleShape, spotColor = Color(0x0F000000)).clip(CircleShape)
                .background(Color.White.copy(alpha = 0.7f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(w.icon, contentDescription = null, tint = Color(0xFF1A1A1A), modifier = Modifier.size(23.dp))
        }
    }
}

/** المصفّي الجانبي: حاوية F5F5F5 بزوايا 25 وخانات 56×62 — النشطة كبسولة FFE68C. */
@Composable
private fun GymRail(modifier: Modifier = Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(25.dp)).background(Color(0xFFF5F5F5)).padding(4.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        RailItem("كارديو", active = true)
        RailItem("قوة", active = false)
        RailItem("صفاء", active = false)
    }
}

@Composable
private fun RailItem(text: String, active: Boolean) {
    Box(
        Modifier.width(56.dp).height(62.dp).clip(RoundedCornerShape(50))
            .background(if (active) AiQoLemon else Color.Transparent),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text, color = if (active) Color(0xFF1A1A1A) else Color(0xFFAAAAAA),
            fontWeight = if (active) FontWeight.Black else FontWeight.Medium, fontSize = 12.sp,
        )
    }
}

@Composable
private fun GymComingSoon(name: String) {
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(name, color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 26.sp)
        Spacer(Modifier.height(8.dp))
        Text("قريباً", color = AiQoGoldDeep, fontWeight = FontWeight.Bold, fontSize = 14.sp)
    }
}

// ── الخطة (Plan) — IMG_2613 ──────────────────────────────────────────────────

@Composable
private fun GymPlan() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
        Text("خطة اليوم", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 30.sp, modifier = Modifier.padding(top = 8.dp, bottom = 16.dp))
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(AiQoPeachCard).padding(horizontal = 16.dp, vertical = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("خطة التمرين 🏋", color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.height(4.dp))
                Text("بلمسة وحدة، ابدي خطة تدريب يومية ويّا Rafiqo.", color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 13.sp)
            }
            Spacer(Modifier.width(12.dp))
            Box(Modifier.size(46.dp).clip(CircleShape).background(Color(0xFF2E2A26)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.ChevronLeft, contentDescription = null, tint = Color.White, modifier = Modifier.size(28.dp))
            }
        }
    }
}

// ── معركة (Battle) — IMG_2614 (أوسمة حقيقية) ─────────────────────────────────

private data class Badge(val res: Int, val title: String, val sub: String, val status: String, val progress: Float, val done: Boolean)

private val STAGE1_BADGES = listOf(
    Badge(R.drawable.badge_1_1, "شرارة الخير (مكافأة)", "مركز 1", "مركز 1 / 1", 1f, true),          // نجمة ذهبية
    Badge(R.drawable.badge_learning, "شرارة التعلم", "مركز 1", "غير مكتمل · 0 / 1", 0f, false),      // كتاب + مصباح
    Badge(R.drawable.badge_1_4, "نبض زون 2 (تراكمي)", "40د / 30د / 20د", "غير مكتمل · 0د / 20د", 0f, false), // نبض القلب
    Badge(R.drawable.badge_1_3, "عرش التعافي (يومي)", "8س / 7.5س / 7س", "غير مكتمل · 0س / 7س", 0f, false),  // هلال (نوم)
    Badge(R.drawable.badge_1_2, "نبع الماء (يومي)", "", "", 0f, false),                              // قطرة ماء
)

@Composable
private fun GymBattle() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
        Text("المرحلة 1", color = AiQoMuted, fontWeight = FontWeight.Bold, fontSize = 14.sp, modifier = Modifier.padding(top = 8.dp))
        Text("الاستيقاظ", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 30.sp, modifier = Modifier.padding(bottom = 14.dp))
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            STAGE1_BADGES.forEach { BadgeCard(it) }
        }
    }
}

@Composable
private fun BadgeCard(b: Badge) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(AiQoMintCard.copy(alpha = 0.65f)).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // الوسام على اليمين (الطفل الأول في RTL)، والنصّ يمينيّ المحاذاة يساره.
        Image(painterResource(b.res), contentDescription = b.title, modifier = Modifier.size(76.dp))
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(b.title, color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            if (b.sub.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(b.sub, color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 13.sp)
            }
            if (b.status.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Text(b.status, color = AiQoInk, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
                Spacer(Modifier.height(6.dp))
                ThinBar(b.progress, if (b.done) Color(0xFF6C6CE0) else AiQoMuted.copy(alpha = 0.25f), Modifier.fillMaxWidth())
            }
        }
    }
}

// ── الأثر (History) — IMG_2615 ───────────────────────────────────────────────

private data class HistoryEntry(val date: String, val name: String, val time: String, val kcal: Int, val progress: Float)

private val HISTORY = listOf(
    HistoryEntry("10 يوليو 2026", "الجري", "53:06", 253, 0.72f),
    HistoryEntry("9 يوليو 2026", "الجري", "41:08", 228, 0.58f),
    HistoryEntry("8 يوليو 2026", "الجري", "56:13", 314, 0.8f),
    HistoryEntry("2 يوليو 2026", "الجري", "45:47", 317, 0.78f),
)

@Composable
private fun GymTrace() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
        Text("السجل", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 30.sp, modifier = Modifier.padding(top = 8.dp))
        Text("متابعة نشاطك عبر الصحة.", color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 14.sp, modifier = Modifier.padding(top = 2.dp, bottom = 14.dp))
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            HISTORY.forEach { HistoryCard(it) }
        }
    }
}

@Composable
private fun HistoryCard(e: HistoryEntry) {
    Column {
        Box(Modifier.clip(RoundedCornerShape(14.dp)).background(Color(0xFFEDEBEF)).padding(horizontal = 12.dp, vertical = 6.dp)) {
            Text(e.date, color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        }
        Spacer(Modifier.height(8.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(AiQoMintCard.copy(alpha = 0.5f)).padding(16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    Column {
                        Text(e.time, color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 20.sp)
                        Text("${e.kcal} kcal", color = AiQoMuted, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    }
                }
                Spacer(Modifier.weight(1f))
                Column {
                    Text(e.name, color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    Text("AiQo", color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 12.sp)
                }
                Spacer(Modifier.width(12.dp))
                Box(Modifier.size(44.dp).clip(CircleShape).background(AiQoGold.copy(alpha = 0.32f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Filled.DirectionsRun, contentDescription = null, tint = AiQoGoldDeep, modifier = Modifier.size(24.dp))
                }
            }
            Spacer(Modifier.height(12.dp))
            ThinBar(e.progress, AiQoGold, Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun ThinBar(progress: Float, color: Color, modifier: Modifier = Modifier) {
    Box(modifier.height(7.dp).clip(RoundedCornerShape(50)).background(Color(0x18000000))) {
        Box(Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).fillMaxHeight().clip(RoundedCornerShape(50)).background(color))
    }
}

// ── قِمَم (Peaks) — أرقامك القياسية، أعلى ما بلغت ─────────────────────────────

private data class Peak(val emoji: String, val title: String, val value: String, val unit: String, val whenAr: String, val tint: Color)

private val PEAKS = listOf(
    Peak("🏃", "أطول جري", "12.4", "كم", "10 يوليو 2026", Color(0xFFF0603F)),
    Peak("👟", "أعلى خطوات بيوم", "14,860", "خطوة", "3 يوليو 2026", AiQoGoldDeep),
    Peak("🔥", "أعلى حرق بجلسة", "642", "سعرة", "8 يوليو 2026", Color(0xFFEF6C4D)),
    Peak("💓", "أطول تركيز — زون 2", "58", "دقيقة", "5 يوليو 2026", Color(0xFFEF4D5E)),
    Peak("✨", "أطول سلسلة نشاط", "18", "يوم", "مستمرة الآن", Color(0xFF6C6CE0)),
)

@Composable
private fun GymPeaks() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
        Text("قِمَم", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 30.sp, modifier = Modifier.padding(top = 8.dp))
        Text(
            "أرقامك القياسية — أعلى ما بلغت ✦",
            color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 14.sp,
            modifier = Modifier.padding(top = 2.dp, bottom = 16.dp),
        )
        PeakHero(PEAKS.first())
        Spacer(Modifier.height(18.dp))
        Text("كل القِمَم", color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.padding(bottom = 12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            PEAKS.drop(1).forEach { PeakCard(it) }
        }
    }
}

/** قمة الشهر — بطاقة بارزة بلون خوخيّ دافئ. */
@Composable
private fun PeakHero(p: Peak) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(AiQoPeachCard).padding(20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(64.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
            Text("🏔️", fontSize = 32.sp)
        }
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f)) {
            Text("قمة الشهر", color = AiQoGoldDeep, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Text(p.title, color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Text(p.whenAr, color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 12.sp)
        }
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(p.value, color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 30.sp)
                Spacer(Modifier.width(4.dp))
                Text(p.unit, color = AiQoMuted, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(bottom = 5.dp))
            }
        }
    }
}

/** بطاقة قِمّة واحدة — أيقونة ملوّنة يمينًا، والرقم القياسي يسارًا (LTR كي تقرأ الأرقام صح). */
@Composable
private fun PeakCard(p: Peak) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(AiQoMintCard.copy(alpha = 0.5f)).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(52.dp).clip(CircleShape).background(p.tint.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
            Text(p.emoji, fontSize = 24.sp)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(p.title, color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text(p.whenAr, color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 12.sp)
        }
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(p.value, color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 22.sp)
                Spacer(Modifier.width(3.dp))
                Text(p.unit, color = p.tint, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, modifier = Modifier.padding(bottom = 3.dp))
            }
        }
    }
}

// ── شاشة التمرين الحيّة (IMG_2607) ───────────────────────────────────────────

private data class LiveStat(val label: String, val value: String, val sub: String, val icon: ImageVector, val tint: Color, val peach: Boolean)

@Composable
private fun LiveWorkoutScreen(name: String, onClose: () -> Unit) {
    // ترتيب iOS البصري: سعرة يسارًا وBPM يمينًا، ثم مباشر يسارًا وكم يمينًا (الأول في RTL = يمين).
    val stats = listOf(
        LiveStat("BPM", "140", "معدل ضربات القلب", Icons.Filled.Favorite, Color(0xFFEF4D5E), peach = true),
        LiveStat("سعرة", "252", "الطاقة النشطة", Icons.Filled.LocalFireDepartment, Color(0xFFF0603F), peach = true),
        LiveStat("كم", "4.12", "المسافة", Icons.AutoMirrored.Filled.DirectionsRun, Color(0xFFF0603F), peach = false),
        LiveStat("مباشر", "نشط", "الحالة", Icons.Filled.MonitorHeart, Color(0xFFEF4D5E), peach = false),
    )
    Box(Modifier.fillMaxSize().background(Color(0xFF131318)).statusBarsPadding().navigationBarsPadding().padding(horizontal = 18.dp)) {
        Column(Modifier.fillMaxSize()) {
            // مقبض الورقة كما iOS (الشاشة تُعرض sheet هناك).
            Box(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.width(44.dp).height(5.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.22f)))
            }
            Spacer(Modifier.height(10.dp))
            Box(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                // في RTL: CenterEnd = يسار — زر الإغلاق يسارًا كما iOS.
                Box(
                    Modifier.align(Alignment.CenterEnd).size(40.dp).clip(CircleShape).background(Color(0xFF3A3A41))
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onClose() },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.Close, contentDescription = "إغلاق", tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(20.dp)) }
                Text(name, Modifier.align(Alignment.Center), color = Color(0xFFF2E0B8), fontWeight = FontWeight.Bold, fontSize = 19.sp)
            }
            Spacer(Modifier.height(16.dp))
            // مؤقّت متوهّج: كبسولة رملية يشعّ حولها هالة دافئة.
            Box(
                Modifier.fillMaxWidth()
                    .shadow(26.dp, RoundedCornerShape(50), spotColor = Color(0xCCF3DCA8), ambientColor = Color(0x66F3DCA8))
                    .clip(RoundedCornerShape(50))
                    .background(Brush.verticalGradient(listOf(Color(0xFFFAE3BC), Color(0xFFF5D9A6))))
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("53:01", color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 58.sp)
            }
            Spacer(Modifier.height(18.dp))
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                stats.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        row.forEach { LiveStatCard(it, Modifier.weight(1f)) }
                    }
                }
            }
            Spacer(Modifier.height(18.dp))
            MusicCard()
            Spacer(Modifier.weight(1f))
            // «الساعة متصلة»: أيقونة الساعة يمينًا وعلامة الصح بدائرة داكنة يسارًا.
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(Color(0xFFC9F0DC)).padding(horizontal = 18.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Watch, null, tint = Color(0xFF17171B), modifier = Modifier.size(22.dp))
                Spacer(Modifier.weight(1f))
                Text("الساعة متصلة", color = Color(0xFF17171B), fontWeight = FontWeight.Bold, fontSize = 17.sp)
                Spacer(Modifier.weight(1f))
                Box(Modifier.size(26.dp).clip(CircleShape).background(Color(0xFF17171B)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(15.dp))
                }
            }
            Spacer(Modifier.height(14.dp))
            // في RTL: كبسولة الإيقاف المؤقت أولًا (يمين) وزر الإنهاء الأحمر أخيرًا (يسار) كما iOS.
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Row(
                    Modifier.weight(1f).height(84.dp).clip(RoundedCornerShape(50)).background(Color(0xFFC9F0DC))
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {},
                    horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Pause, null, tint = Color(0xFF17171B), modifier = Modifier.size(24.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("إيقاف مؤقت", color = Color(0xFF17171B), fontWeight = FontWeight.Bold, fontSize = 19.sp)
                }
                Box(
                    Modifier.size(84.dp)
                        .shadow(18.dp, CircleShape, spotColor = Color(0x80F26D6D), ambientColor = Color(0x40F26D6D))
                        .clip(CircleShape).background(Color(0xFFF26D6D))
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onClose() },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(Modifier.size(26.dp).clip(RoundedCornerShape(7.dp)).background(Color.White))
                }
            }
            Spacer(Modifier.height(14.dp))
        }
    }
}

@Composable
private fun LiveStatCard(s: LiveStat, modifier: Modifier) {
    Column(
        modifier.height(150.dp).clip(RoundedCornerShape(26.dp))
            .background(if (s.peach) Color(0xFFF8DCB0) else Color(0xFFC9F0DC))
            .padding(16.dp),
    ) {
        // في RTL: الأيقونة أولًا (يمين) والوسم يسارًا — كما IMG_2607 حرفيًّا.
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Icon(s.icon, null, tint = s.tint, modifier = Modifier.size(22.dp))
            Spacer(Modifier.weight(1f))
            Text(s.label, color = Color(0xFF6B655A), fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        }
        Spacer(Modifier.weight(1f))
        Text(s.value, color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 32.sp)
        Text(s.sub, color = Color(0xFF6B655A), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

@Composable
private fun MusicCard() {
    // مشغّل سبوتيفاي المصغّر: أزرار التنقل يسارًا والنص + بلاطة الموجة يمينًا (LTR كما iOS).
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(Color(0xFF1E1E24)).padding(horizontal = 12.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.SkipPrevious, null, tint = Color.White.copy(alpha = 0.75f), modifier = Modifier.size(28.dp))
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(48.dp).clip(CircleShape).background(Color(0xFF1FDF64)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.PlayArrow, null, tint = Color(0xFF17171B), modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.width(8.dp))
            Icon(Icons.Filled.SkipNext, null, tint = Color.White.copy(alpha = 0.75f), modifier = Modifier.size(28.dp))
            Spacer(Modifier.width(10.dp))
            Icon(Icons.Filled.ExpandLess, null, tint = Color.White.copy(alpha = 0.45f), modifier = Modifier.size(20.dp))
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Text("Not Playing", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1)
                Text("Spotify App", color = Color.White.copy(alpha = 0.55f), fontWeight = FontWeight.Medium, fontSize = 12.sp, maxLines = 1)
            }
            Spacer(Modifier.width(10.dp))
            Column(
                Modifier.clip(RoundedCornerShape(16.dp)).background(Color(0xFF2A2A31)).padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Filled.GraphicEq, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(20.dp))
                Spacer(Modifier.height(4.dp))
                Box(Modifier.width(18.dp).height(3.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.35f)))
            }
        }
    }
}

// ── المطبخ (Kitchen — IMG_2616) والثلاجة (IMG_2619) ──────────────────────────

private data class Meal(val section: String, val name: String, val kcal: Int, val emojis: List<String>)

private val MEALS = listOf(
    Meal("الفطور", "فول مدمس مع خبز", 360, listOf("🫘", "🥚", "🍌")),
    Meal("الغداء", "كباب مع رز", 610, listOf("🍗", "🍚", "🥦")),
    Meal("العشاء", "بيض مسلوق مع خضار", 260, listOf("🥚", "🥗", "🐟")),
)

@Composable
private fun KitchenScreen(onOpenProfile: () -> Unit) {
    var showFridge by rememberSaveable { mutableStateOf(false) }
    if (showFridge) {
        BackHandler { showFridge = false }
        FridgeScreen(onBack = { showFridge = false })
        return
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(8.dp))
        // كما iOS: العنوان والتاريخ في أقصى اليسار والأفاتار يمينًا (من لقطة IMG_2616).
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Image(
                painterResource(R.drawable.aiqo_profile), contentDescription = "الملف الشخصي", contentScale = ContentScale.Crop,
                modifier = Modifier.size(50.dp).clip(CircleShape)
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onOpenProfile() },
            )
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Text("المطبخ", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 28.sp)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("11/7", color = AiQoMuted, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    Spacer(Modifier.width(4.dp))
                    Icon(Icons.Filled.CalendarMonth, null, tint = AiQoMuted, modifier = Modifier.size(14.dp))
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        // في RTL: الأول يمين — الثلاجة يمينًا والنظام الغذائي يسارًا (مطابقة IMG_2616).
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            KitchenTile("الثلاجة", Icons.Filled.Kitchen, Modifier.weight(1f)) { showFridge = true }
            KitchenTile("النظام الغذائي", Icons.Filled.Restaurant, Modifier.weight(1f)) {}
        }
        Spacer(Modifier.height(10.dp))
        MEALS.forEach { MealCard(it) }
        Spacer(Modifier.height(10.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(AiQoMintCard.copy(alpha = 0.5f)).padding(16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("التغذية اليومية", color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Spacer(Modifier.weight(1f))
                Text("0 / 2200 سعرة", color = AiQoMuted, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
            Spacer(Modifier.height(10.dp))
            ThinBar(0f, AiQoGold, Modifier.fillMaxWidth())
        }
        Spacer(Modifier.height(120.dp))
    }
}

@Composable
private fun KitchenTile(title: String, icon: ImageVector, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.height(168.dp).clip(RoundedCornerShape(34.dp)).background(AiQoPeachCard.copy(alpha = 0.92f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onClick() }
            .padding(18.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Box(Modifier.size(46.dp).clip(CircleShape).background(Color(0xFFF7F1E4).copy(alpha = 0.85f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color(0xFF4A443A), modifier = Modifier.size(24.dp))
        }
        Text(title, color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 19.sp)
    }
}

@Composable
private fun MealCard(m: Meal) {
    Column {
        // العنوان في أقصى اليسار كما اللقطة (محاذاة End في RTL = يسار).
        Text(
            m.section, color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 24.sp,
            modifier = Modifier.align(Alignment.End).padding(vertical = 10.dp),
        )
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(30.dp)).background(AiQoMintCard.copy(alpha = 0.72f)).padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // الصحن أولًا (يمين في RTL) ثم النص يساره.
            MealPlate(m.emojis)
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(m.name, color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 20.sp)
                Spacer(Modifier.height(4.dp))
                Text("${m.kcal} سعرة حرارية", color = Color(0xFF5C665F), fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

/** صحن ثلاثي الأبعاد مبسّط: حلقتان بيضاوان وظل ناعم وعناصر الوجبة فوقه. */
@Composable
private fun MealPlate(emojis: List<String>) {
    Box(
        Modifier.size(112.dp).shadow(8.dp, CircleShape, spotColor = Color(0x22000000)).clip(CircleShape).background(Color.White),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(88.dp).clip(CircleShape).background(Color(0xFFF2F1EE)))
        Box(Modifier.size(78.dp).clip(CircleShape).background(Color.White))
        val offsets = listOf(Offset(-20f, 8f), Offset(16f, -14f), Offset(14f, 16f))
        emojis.forEachIndexed { i, e ->
            val o = offsets.getOrElse(i) { Offset.Zero }
            Text(e, fontSize = 22.sp, modifier = Modifier.offset(x = o.x.dp, y = o.y.dp))
        }
    }
}

// ── الثلاجة — صورة iOS الحقيقية + عدّاد وعناصر تُضاف على الرفوف ───────────────

private data class FridgeSuggestion(val name: String, val emoji: String)

private val FRIDGE_SUGGESTIONS = listOf(
    FridgeSuggestion("خبز أسمر", "🍞"),
    FridgeSuggestion("ذرة", "🌽"),
    FridgeSuggestion("رز", "🍚"),
)

// مواقع الرفوف داخل صورة الثلاجة (كسور من العرض/الارتفاع) — تُملأ بالتتابع.
private val FRIDGE_SLOTS = listOf(
    0.26f to 0.315f, 0.46f to 0.315f, 0.66f to 0.315f,
    0.30f to 0.435f, 0.52f to 0.435f, 0.72f to 0.435f,
    0.26f to 0.555f, 0.48f to 0.555f, 0.68f to 0.555f,
    0.34f to 0.665f, 0.56f to 0.665f, 0.74f to 0.665f,
)

@Composable
private fun FridgeScreen(onBack: () -> Unit) {
    val items = remember { mutableStateListOf<FridgeSuggestion>() }
    val context = LocalContext.current
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 14.dp)) {
        Spacer(Modifier.height(6.dp))
        Box(Modifier.fillMaxWidth().height(56.dp)) {
            // زر الرجوع يمينًا (سهم لليمين كما iOS RTL).
            Box(
                Modifier.align(Alignment.CenterStart).size(48.dp)
                    .shadow(6.dp, CircleShape, spotColor = Color(0x14000000)).clip(CircleShape).background(Color.White)
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onBack() },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.ChevronRight, null, tint = Color(0xFF17171B), modifier = Modifier.size(24.dp)) }
            Text("الثلاجة", Modifier.align(Alignment.Center), color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 24.sp)
            // كبسولة الأزرار الذهبية يسارًا: مسح بالكاميرا + تصفية.
            Row(
                Modifier.align(Alignment.CenterEnd)
                    .shadow(6.dp, RoundedCornerShape(50), spotColor = Color(0x14000000))
                    .clip(RoundedCornerShape(50)).background(Color.White).padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Filled.Tune, "تصفية", tint = AiQoGoldDeep,
                    modifier = Modifier.size(22.dp).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                        Toast.makeText(context, "التصفية — قريباً", Toast.LENGTH_SHORT).show()
                    },
                )
                Icon(
                    Icons.Filled.CenterFocusStrong, "مسح", tint = AiQoGoldDeep,
                    modifier = Modifier.size(22.dp).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                        Toast.makeText(context, "مسح الأطعمة بالكاميرا — قريباً", Toast.LENGTH_SHORT).show()
                    },
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        BoxWithConstraints(
            Modifier.weight(1f).fillMaxWidth()
                .shadow(14.dp, RoundedCornerShape(38.dp), spotColor = Color(0x22000000))
                .clip(RoundedCornerShape(38.dp)),
        ) {
            val w = maxWidth
            val h = maxHeight
            Image(
                painterResource(R.drawable.fridge_interior), contentDescription = "الثلاجة",
                contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize(),
            )
            // عدّاد العناصر — أعلى اليسار كما اللقطة.
            Box(
                Modifier.align(Alignment.TopEnd).padding(14.dp).clip(RoundedCornerShape(50))
                    .background(Color(0xCCDFF2E6)).padding(horizontal = 14.dp, vertical = 6.dp),
            ) {
                Text("${items.size} عنصر", color = Color(0xFF3E6B52), fontWeight = FontWeight.Bold, fontSize = 13.sp)
            }
            // العناصر المضافة تجلس على الرفوف — اضغط عنصرًا لإخراجه.
            // صندوق LTR داخلي: في RTL نقطةُ انطلاق absoluteOffset هي الزاوية اليمنى
            // فتهرب العناصر خارج الشاشة (فخ موثّق) — التثبيت من اليسار يحلّها.
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                Box(Modifier.fillMaxSize()) {
                    items.forEachIndexed { i, item ->
                        val slot = FRIDGE_SLOTS.getOrNull(i) ?: return@forEachIndexed
                        Text(
                            item.emoji, fontSize = 30.sp,
                            modifier = Modifier.absoluteOffset(x = w * slot.first - 16.dp, y = h * slot.second - 16.dp)
                                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { items.removeAt(i) },
                        )
                    }
                }
            }
            // لوحة «إضافة إلى الثلاجة» الزجاجية أسفل الصورة.
            Column(
                Modifier.align(Alignment.BottomCenter).padding(10.dp).clip(RoundedCornerShape(28.dp))
                    .background(Color(0xE0ECEEF1)).padding(14.dp),
            ) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("إضافة إلى الثلاجة", color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 19.sp)
                    Spacer(Modifier.weight(1f))
                    Text("اضغط على أي عنصر", color = Color(0xFF8A9097), fontWeight = FontWeight.Medium, fontSize = 12.sp)
                }
                Spacer(Modifier.height(12.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FRIDGE_SUGGESTIONS.forEach { s ->
                        Column(
                            Modifier.weight(1f).clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.85f)).padding(vertical = 12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Box(Modifier.size(52.dp).clip(CircleShape).background(Color(0xFFF3F1EC)), contentAlignment = Alignment.Center) {
                                Text(s.emoji, fontSize = 26.sp)
                            }
                            Spacer(Modifier.height(8.dp))
                            Text(s.name, color = Color(0xFF17171B), fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Spacer(Modifier.height(8.dp))
                            Box(
                                Modifier.clip(RoundedCornerShape(12.dp)).background(Color(0xFFD8E7FA))
                                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                                        if (items.size < FRIDGE_SLOTS.size) items.add(s)
                                    }
                                    .padding(horizontal = 18.dp, vertical = 5.dp),
                            ) {
                                Text("أضف", color = Color(0xFF1D6FE0), fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(96.dp))
    }
}

// ── الملف الشخصي (Profile — IMG_2621/2622) ───────────────────────────────────

private data class BodyStat(val label: String, val value: String, val icon: ImageVector)
private data class SettingItem(val title: String, val sub: String, val icon: ImageVector, val peach: Boolean, val darkTile: Boolean)

@Composable
private fun ProfileScreen(onClose: () -> Unit) {
    // ورقة الملف في iOS مرسومة LTR كما هي (العناوين والأيقونات يسارًا والسهم يمينًا) —
    // ننسخ السلوك حرفيًّا لمطابقة IMG_2621/2622.
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(
            Modifier.fillMaxSize().background(AiQoCanvas).verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 16.dp),
        ) {
            Box(Modifier.fillMaxWidth().padding(vertical = 10.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.width(44.dp).height(5.dp).clip(RoundedCornerShape(50)).background(Color(0x33000000)).clickable { onClose() })
            }
            ProfileHeaderCard()
            Spacer(Modifier.height(22.dp))
            Text("بيانات جسمك", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 22.sp)
            Spacer(Modifier.height(12.dp))
            val body = listOf(
                BodyStat("الطول", "175 سم", Icons.Filled.Straighten),
                BodyStat("العمر", "24 سنة", Icons.Filled.CalendarMonth),
                BodyStat("الجنس", "ذكر", Icons.Filled.Person),
                BodyStat("الوزن", "95 كغم", Icons.Filled.FitnessCenter),
            )
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                body.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) { row.forEach { BodyCard(it, Modifier.weight(1f)) } }
                }
            }
            Spacer(Modifier.height(22.dp))
            Text("الاشتراك", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 22.sp)
            Spacer(Modifier.height(12.dp))
            SubscriptionCard()
            Spacer(Modifier.height(22.dp))
            Text("تطبيق AiQo", color = AiQoInk, fontWeight = FontWeight.Black, fontSize = 22.sp)
            Spacer(Modifier.height(12.dp))
            val settings = listOf(
                SettingItem("إعدادات التطبيق", "الإشعارات، الوحدات، اللغة", Icons.Filled.Settings, peach = false, darkTile = false),
                SettingItem("تقرير الأسبوع", "ملخص نشاطك الأسبوعي", Icons.AutoMirrored.Filled.Article, peach = true, darkTile = true),
                SettingItem("صور التقدم", "تابع تحولك الجسدي", Icons.Filled.CenterFocusStrong, peach = false, darkTile = false),
                SettingItem("النواة", "اقفل التطبيقات، وافتحها بالحركة", Icons.Filled.Lock, peach = false, darkTile = false),
                SettingItem("تواصل مع الدعم", "إحنا وياك نساعدك", Icons.Filled.ChatBubble, peach = true, darkTile = false),
            )
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) { settings.forEach { SettingRow(it) } }
            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun ProfileHeaderCard() {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(34.dp))
            .background(Brush.verticalGradient(listOf(Color(0xFFF6E2BB), Color(0xFFEFD29B)))).padding(18.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            // الأفاتار يسارًا: دائرة شفافة بشارة كاميرا — المستخدم بلا صورة كما iOS.
            Box(Modifier.padding(top = 4.dp)) {
                Box(
                    Modifier.size(104.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.34f)),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.Person, null, tint = Color(0xFF17171B), modifier = Modifier.size(46.dp)) }
                Box(
                    Modifier.align(Alignment.BottomStart).size(32.dp).clip(RoundedCornerShape(11.dp)).background(Color.White.copy(alpha = 0.85f)),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.PhotoCamera, null, tint = Color(0xFF17171B), modifier = Modifier.size(16.dp)) }
            }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Box(Modifier.clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.45f)).padding(horizontal = 14.dp, vertical = 7.dp)) {
                    Text("الملف الشخصي", color = Color(0xFF17171B).copy(alpha = 0.75f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                }
                Spacer(Modifier.height(10.dp))
                Text("محمد رعد", color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 30.sp)
            }
        }
        Spacer(Modifier.height(14.dp))
        // لوح زجاجي داخلي يضم البطاقتين وشريط التقدم — كما IMG_2621.
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(Color.White.copy(alpha = 0.32f)).padding(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                InfoPill("المستوى", "24", Icons.Filled.GppGood, Modifier.weight(1f))
                InfoPill("رصيدك", "112,850", Icons.AutoMirrored.Filled.ShowChart, Modifier.weight(1f))
            }
            Spacer(Modifier.height(14.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("29%", color = Color(0xFF17171B), fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Spacer(Modifier.weight(1f))
                Text("التقدم للمستوى القادم", color = Color(0xFF17171B).copy(alpha = 0.65f), fontWeight = FontWeight.Medium, fontSize = 14.sp)
            }
            Spacer(Modifier.height(8.dp))
            LevelProgressBar(0.29f)
        }
    }
}

/** شريط تقدم المستوى: مسار أبيض، تعبئة نعناعية من اليمين، ومقبض أبيض دائري. */
@Composable
private fun LevelProgressBar(progress: Float) {
    BoxWithConstraints(Modifier.fillMaxWidth().height(18.dp)) {
        val fillW = maxWidth * progress.coerceIn(0f, 1f)
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(9.dp)).background(Color.White.copy(alpha = 0.75f))) {
            Box(Modifier.align(Alignment.CenterEnd).width(fillW).fillMaxHeight().background(Color(0xFFA5DDC0)))
        }
        Box(
            Modifier.align(Alignment.CenterEnd).offset(x = -(fillW - 9.dp))
                .size(18.dp).shadow(3.dp, CircleShape, spotColor = Color(0x40000000)).clip(CircleShape).background(Color.White),
        )
    }
}

@Composable
private fun InfoPill(label: String, value: String, icon: ImageVector, modifier: Modifier) {
    Row(
        modifier.clip(RoundedCornerShape(22.dp)).background(Color.White.copy(alpha = 0.55f)).padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(40.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.9f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color(0xFF17171B), modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(label, color = Color(0xFF17171B).copy(alpha = 0.65f), fontWeight = FontWeight.Medium, fontSize = 12.sp)
            Text(value, color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 19.sp)
        }
    }
}

@Composable
private fun BodyCard(s: BodyStat, modifier: Modifier) {
    Column(modifier.height(148.dp).clip(RoundedCornerShape(28.dp)).background(AiQoMintCard.copy(alpha = 0.62f)).padding(16.dp)) {
        Box(Modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.7f)), contentAlignment = Alignment.Center) {
            Icon(s.icon, null, tint = Color(0xFF17171B), modifier = Modifier.size(24.dp))
        }
        Spacer(Modifier.weight(1f))
        Text(s.label, color = Color(0xFF4A544E), fontWeight = FontWeight.Medium, fontSize = 15.sp)
        // اتجاه LTR قسري كي تتقدم الأرقام النص («175 سم» لا «سم 175») كما iOS.
        Text(
            s.value, color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 24.sp, lineHeight = 30.sp,
            style = LocalTextStyle.current.copy(textDirection = TextDirection.Ltr),
        )
    }
}

@Composable
private fun SubscriptionCard() {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(30.dp))
            .background(Brush.verticalGradient(listOf(Color(0xFFF4DEAE), Color(0xFFEFD29B))))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .padding(horizontal = 14.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(54.dp).clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.7f)), contentAlignment = Alignment.Center) {
            Icon(CrownIcon, null, tint = Color(0xFF17171B), modifier = Modifier.size(26.dp))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text("AiQo Max", color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 20.sp)
            Text("نشط حتى 2026/08/22", color = Color(0xFF17171B).copy(alpha = 0.6f), fontWeight = FontWeight.Medium, fontSize = 13.sp)
        }
        ChevronBubble()
    }
}

// تاج «AiQo Max» — لا تاج في أيقونات Material فرُسم يدويًّا (قاعدة + ثلاث قمم بكرات).
private val CrownIcon: ImageVector = ImageVector.Builder(
    name = "Crown", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f,
).apply {
    val ink = SolidColor(Color.Black)
    path(fill = ink) {
        moveTo(4.2f, 8.6f)
        lineTo(8.1f, 11.4f)
        lineTo(12f, 6.4f)
        lineTo(15.9f, 11.4f)
        lineTo(19.8f, 8.6f)
        lineTo(18.3f, 16.2f)
        lineTo(5.7f, 16.2f)
        close()
    }
    path(stroke = ink, strokeLineWidth = 1.8f, strokeLineCap = StrokeCap.Round) { moveTo(5.7f, 18.9f); lineTo(18.3f, 18.9f) }
    path(fill = ink) { moveTo(4.2f, 6.5f); curveTo(5.0f, 6.5f, 5.6f, 7.1f, 5.6f, 7.9f); curveTo(5.6f, 8.7f, 5.0f, 9.3f, 4.2f, 9.3f); curveTo(3.4f, 9.3f, 2.8f, 8.7f, 2.8f, 7.9f); curveTo(2.8f, 7.1f, 3.4f, 6.5f, 4.2f, 6.5f); close() }
    path(fill = ink) { moveTo(19.8f, 6.5f); curveTo(20.6f, 6.5f, 21.2f, 7.1f, 21.2f, 7.9f); curveTo(21.2f, 8.7f, 20.6f, 9.3f, 19.8f, 9.3f); curveTo(19.0f, 9.3f, 18.4f, 8.7f, 18.4f, 7.9f); curveTo(18.4f, 7.1f, 19.0f, 6.5f, 19.8f, 6.5f); close() }
    path(fill = ink) { moveTo(12f, 4.0f); curveTo(12.8f, 4.0f, 13.4f, 4.6f, 13.4f, 5.4f); curveTo(13.4f, 6.2f, 12.8f, 6.8f, 12f, 6.8f); curveTo(11.2f, 6.8f, 10.6f, 6.2f, 10.6f, 5.4f); curveTo(10.6f, 4.6f, 11.2f, 4.0f, 12f, 4.0f); close() }
}.build()

/** سهم iOS: ‹ صغير داخل دائرة بيضاء ناعمة على يمين الصف. */
@Composable
private fun ChevronBubble() {
    Box(Modifier.size(38.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
        Icon(Icons.Filled.ChevronLeft, null, tint = Color(0xFF17171B).copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun SettingRow(s: SettingItem) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(30.dp))
            .background(if (s.peach) AiQoPeachCard.copy(alpha = 0.72f) else AiQoMintCard.copy(alpha = 0.55f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .padding(horizontal = 14.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(54.dp).clip(RoundedCornerShape(18.dp))
                .background(if (s.darkTile) Color(0xFF6F6F76) else Color.White.copy(alpha = 0.7f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(s.icon, null, tint = if (s.darkTile) Color.White else Color(0xFF17171B), modifier = Modifier.size(24.dp))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(s.title, color = Color(0xFF17171B), fontWeight = FontWeight.Black, fontSize = 19.sp)
            Text(s.sub, color = Color(0xFF17171B).copy(alpha = 0.55f), fontWeight = FontWeight.Medium, fontSize = 13.sp)
        }
        ChevronBubble()
    }
}

// ── شريط التنقل — زجاج عائم بحبّة اختيار منزلقة (روح iOS 26 Liquid Glass) ─────

@Composable
private fun AiQoBottomNav(selected: AiQoTab, onSelect: (AiQoTab) -> Unit, modifier: Modifier = Modifier) {
    val tabs = AiQoTab.entries
    BoxWithConstraints(
        modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 12.dp)
            .shadow(18.dp, RoundedCornerShape(34.dp), spotColor = Color(0x40474030), ambientColor = Color(0x26474030))
            .clip(RoundedCornerShape(34.dp))
            .background(Color.White)
            .padding(6.dp),
    ) {
        val tabWidth = maxWidth / tabs.size
        val pillOffset by animateDpAsState(
            tabWidth * tabs.indexOf(selected),
            spring(dampingRatio = 0.78f, stiffness = Spring.StiffnessMediumLow),
            label = "انزلاق الحبة",
        )
        // حبّة الاختيار الكريمية تنزلق تحت التبويب النشط (offset الموجب يتجه يسارًا في RTL).
        Box(
            Modifier.offset(x = pillOffset).width(tabWidth).height(64.dp).padding(horizontal = 3.dp)
                .clip(RoundedCornerShape(26.dp))
                .background(Brush.verticalGradient(listOf(Color(0xFFFBF3D9), Color(0xFFF5EBC6)))),
        )
        Row(Modifier.fillMaxWidth()) {
            tabs.forEach { tab ->
                val active = tab == selected
                val iconScale by animateFloatAsState(
                    if (active) 1.12f else 1f,
                    spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium),
                    label = "قفزة الأيقونة",
                )
                val tint by animateColorAsState(if (active) AiQoGoldDeep else AiQoInk, tween(220), label = "لون التبويب")
                Column(
                    Modifier.width(tabWidth).height(64.dp)
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onSelect(tab) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(tab.icon, contentDescription = tab.labelAr, tint = tint, modifier = Modifier.size(24.dp).scale(iconScale))
                    Spacer(Modifier.height(3.dp))
                    Text(
                        tab.labelAr, color = tint, fontSize = 11.sp,
                        fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
                    )
                }
            }
        }
    }
}

// أيقونة «النادي» مرسومة يدويًّا لمطابقة figure.strengthtraining.traditional:
// شخصٌ يرفع البار فوق رأسه بثقلَين على الطرفين.
private val GymFigureIcon: ImageVector = ImageVector.Builder(
    name = "GymFigure", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f,
).apply {
    val ink = SolidColor(Color.Black)
    // البار والثقلان
    path(stroke = ink, strokeLineWidth = 1.5f, strokeLineCap = StrokeCap.Round) { moveTo(3.6f, 4.6f); lineTo(20.4f, 4.6f) }
    path(stroke = ink, strokeLineWidth = 2.0f, strokeLineCap = StrokeCap.Round) { moveTo(5.2f, 2.5f); lineTo(5.2f, 6.7f) }
    path(stroke = ink, strokeLineWidth = 2.0f, strokeLineCap = StrokeCap.Round) { moveTo(18.8f, 2.5f); lineTo(18.8f, 6.7f) }
    // الذراعان الممدودتان للبار
    path(stroke = ink, strokeLineWidth = 1.6f, strokeLineCap = StrokeCap.Round) { moveTo(11.6f, 10.6f); lineTo(8.0f, 5.1f) }
    path(stroke = ink, strokeLineWidth = 1.6f, strokeLineCap = StrokeCap.Round) { moveTo(12.4f, 10.6f); lineTo(16.0f, 5.1f) }
    // الرأس
    path(fill = ink) {
        moveTo(12f, 6.2f)
        curveTo(13.02f, 6.2f, 13.85f, 7.03f, 13.85f, 8.05f)
        curveTo(13.85f, 9.07f, 13.02f, 9.9f, 12f, 9.9f)
        curveTo(10.98f, 9.9f, 10.15f, 9.07f, 10.15f, 8.05f)
        curveTo(10.15f, 7.03f, 10.98f, 6.2f, 12f, 6.2f)
        close()
    }
    // الجذع والساقان
    path(stroke = ink, strokeLineWidth = 2.3f, strokeLineCap = StrokeCap.Round) { moveTo(12f, 10.6f); lineTo(12f, 15.0f) }
    path(stroke = ink, strokeLineWidth = 1.9f, strokeLineCap = StrokeCap.Round) { moveTo(12f, 15.0f); lineTo(9.3f, 20.9f) }
    path(stroke = ink, strokeLineWidth = 1.9f, strokeLineCap = StrokeCap.Round) { moveTo(12f, 15.0f); lineTo(14.7f, 20.9f) }
}.build()

// ── RoQo — مساعد النظام الذكي (كانت شاشة الكابتن؛ الشخصية صارت RoQo) ──────────

private data class CaptainMsg(val text: String, val isUser: Boolean)

/** أخضر نعناعي مائل للتركواز (لون المؤشر/الإرسال/نقاط التفكير في iOS). */
private val CaptainTeal = Color(0xFF5ECDB7)

/** تحية افتتاحية بحسب وقت اليوم — بلهجة RoQo العراقية الودودة. */
private fun captainGreeting(): String = when (Calendar.getInstance().get(Calendar.HOUR_OF_DAY)) {
    in 4..11 -> "صباح الخير محمد! اليوم توه بادي — شلونها همتك اليوم؟"
    in 12..16 -> "هلا محمد! نص اليوم مر — شلون طاقتك هسه؟"
    in 17..21 -> "مساء الخير محمد! شلون كان يومك؟ نختمه بحركة حلوة؟"
    else -> "هلا محمد! الوقت متأخر شوية — أهم شي نومك الليلة. شنو تحتاج؟"
}

/** ردود RoQo المحلية — قواعد كلمات مفتاحية بلهجة عراقية (بلا سحابة بعد). */
private fun captainReply(user: String): String {
    val t = user.lowercase()
    fun any(vararg k: String) = k.any { t.contains(it) }
    return when {
        any("تمرين", "تدريب", "نادي", "اتمرن", "كارديو", "جري", "ركض", "قوة", "حديد", "رياضة") ->
            "خوش قرار! نبدي بكارديو Zone 2 خفيف — 20 دقيقة مشي سريع وياها إحماء. روح للنادي وابدي «كارديو ويا Rafiqo» وأني وياك 💪"
        any("اكل", "أكل", "جوعان", "وجبة", "فطور", "غدا", "عشا", "رجيم", "دايت", "سعرات") ->
            "التغذية نص الطريق! افتح المطبخ وشوف وجبات اليوم — خلي البروتين عالي والسكر واطي، والباقي يمشي وحده."
        any("نوم", "تعبان", "تعب", "مرهق", "نايم", "سهران") ->
            "التعافي أهم من التمرين نفسه. حاول تنام 7 ساعات الليلة — وعرش التعافي بالمعركة ينتظرك 😴"
        any("ماء", "عطش") ->
            "اشرب كوب ماء هسه! هدفك اليوم لترين — ونبع الماء بالمعركة يحسبها وياك 💧"
        any("شكرا", "شكرًا", "تسلم", "عاشت ايدك") ->
            "حياك الله! أي وقت تحتاجني أني هنا — يلا نكمل 💪"
        any("هلا", "سلام", "شلونك", "مرحبا", "صباح", "مساء", "هاي", "hello", "hi", "hey") ->
            "أهلاً بيك محمد! شلونك اليوم؟ عساك بخير. خبرني شنو هدفك: تمرين، أكل، لو نوم؟"
        else ->
            "تمام محمد! خبرني أكثر شوية — تريد خطة تمرين، نصيحة أكل، لو متابعة نومك؟ أني حاضر."
    }
}

@Composable
private fun CaptainScreen(chat: SnapshotStateList<CaptainMsg>, onOpenProfile: () -> Unit) {
    var typing by remember { mutableStateOf(false) }
    var bannerExpanded by rememberSaveable { mutableStateOf(false) }
    val hasUserChat = chat.any { it.isUser }
    val listState = rememberLazyListState()

    // صوت محلي حقيقي (TextToSpeech) — زر السماعة يظهر فقط إذا توفر محرك عربي.
    val context = LocalContext.current
    var ttsReady by remember { mutableStateOf(false) }
    val tts = remember {
        var engine: TextToSpeech? = null
        engine = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val r = engine?.setLanguage(Locale("ar"))
                ttsReady = r != null && r >= TextToSpeech.LANG_AVAILABLE
            }
        }
        engine
    }
    DisposableEffect(Unit) { onDispose { tts?.shutdown() } }

    // الرد يتولد من أثر «آخر رسالة للمستخدم» — ينجو من مغادرة التبويب والعودة.
    LaunchedEffect(chat.size) {
        val last = chat.lastOrNull()
        if (last != null && last.isUser) {
            typing = true
            delay((1_400L..2_300L).random())
            chat.add(CaptainMsg(captainReply(last.text), isUser = false))
            typing = false
        }
    }
    LaunchedEffect(chat.size, typing) {
        if (hasUserChat) listState.animateScrollToItem((chat.size - if (typing) 0 else 1).coerceAtLeast(0))
    }

    // أسفل الشاشة: 96dp فوق شريط التنقل العائم، أو فوق الكيبورد إذا كان أعلى منه.
    val imeBottom = with(LocalDensity.current) { WindowInsets.ime.getBottom(this).toDp() }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 18.dp)) {
        Spacer(Modifier.height(8.dp))
        CaptainHeader(subtitle = if (typing) "يفكر الحين" else "متصل الآن", onOpenProfile = onOpenProfile, onNewChat = {
            chat.clear()
            chat.add(CaptainMsg(captainGreeting(), isUser = false))
        }, onInfo = { bannerExpanded = !bannerExpanded })
        Spacer(Modifier.height(10.dp))
        CaptainSafetyBanner(expanded = bannerExpanded, onToggle = { bannerExpanded = !bannerExpanded })

        if (!hasUserChat) {
            // وضع العرض (قبل أول رسالة): الفقاعة فوق + RoQo كبير يتنفس بالأسفل.
            Box(Modifier.weight(1f).fillMaxWidth()) {
                Column(Modifier.align(Alignment.TopCenter).fillMaxWidth().padding(top = 16.dp)) {
                    chat.forEach { CaptainBubbleRow(it, canSpeak = ttsReady) { text -> tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "captain") } }
                }
                BreathingRoqo(Modifier.align(Alignment.BottomCenter).fillMaxHeight(0.62f))
            }
        } else {
            // وضع المحادثة: الرسائل ملء الشاشة + أفاتار مصغر فوق شريط الإدخال يسارًا.
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentPadding = PaddingValues(top = 16.dp, bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(chat) { CaptainBubbleRow(it, canSpeak = ttsReady) { text -> tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "captain") } }
                if (typing) item { CaptainTypingRow() }
            }
            Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Spacer(Modifier.weight(1f))
                MiniRoqo()
            }
        }

        CaptainInputBar(sending = typing, onSend = { chat.add(CaptainMsg(it, isUser = true)) })
        Spacer(Modifier.height(max(96.dp, imeBottom + 10.dp)))
    }
}

@Composable
private fun CaptainHeader(subtitle: String, onOpenProfile: () -> Unit, onNewChat: () -> Unit, onInfo: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        // في RTL: الأفاتار أولًا (أقصى اليمين)، ثم زرا الزجاج، والعنوان أقصى اليسار.
        Image(
            painter = painterResource(R.drawable.aiqo_profile), contentDescription = "الملف الشخصي",
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(46.dp).clip(CircleShape)
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onOpenProfile() },
        )
        Spacer(Modifier.width(8.dp))
        CaptainChromeButton(Icons.Filled.History, "محادثة جديدة", onNewChat)
        Spacer(Modifier.width(6.dp))
        CaptainChromeButton(Icons.Filled.Book, "عن المحادثة", onInfo)
        Spacer(Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.End) { // End في RTL = حافة اليسار
            Text("Rafiqo", color = AiQoInk, fontWeight = FontWeight.Bold, fontSize = 21.sp)
            Text(subtitle, color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 11.5.sp)
        }
    }
}

@Composable
private fun CaptainChromeButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    Box(
        Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.75f))
            .border(0.7.dp, Color(0x14000000), CircleShape)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onClick() },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = label, tint = AiQoMuted, modifier = Modifier.size(17.dp)) }
}

@Composable
private fun CaptainSafetyBanner(expanded: Boolean, onToggle: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(Color.White.copy(alpha = 0.75f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onToggle() }
            .padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.Info, contentDescription = null, tint = Color(0xFF6FBFA0), modifier = Modifier.size(15.dp))
            Spacer(Modifier.width(8.dp))
            Text("محادثة للعافية فقط — ليست استشارة طبية", color = AiQoInk.copy(alpha = 0.75f), fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp)
            Spacer(Modifier.weight(1f))
            Icon(Icons.Filled.ChevronLeft, contentDescription = null, tint = AiQoMuted.copy(alpha = 0.7f), modifier = Modifier.size(16.dp).rotate(if (expanded) -90f else 0f))
        }
        if (expanded) {
            Spacer(Modifier.height(6.dp))
            Text(
                "Rafiqo يساعدك بالتمرين والتغذية والنوم بشكل عام. لأي عرض صحي أو دواء، راجع طبيبك.",
                color = AiQoMuted, fontWeight = FontWeight.Medium, fontSize = 11.5.sp,
            )
        }
    }
}

/** فقاعة رسالة كما في iOS: عرض ثابت 300dp، نص محاذٍ لليمين، وزاوية صغيرة واحدة. */
@Composable
private fun CaptainBubbleRow(msg: CaptainMsg, canSpeak: Boolean, onSpeak: (String) -> Unit) {
    // iOS: زاوية المستخدم الصغيرة أسفل-يسار (bottomTrailing في RTL)، والكابتن أسفل-يمين.
    val shape = if (msg.isUser) {
        RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomEnd = 6.dp, bottomStart = 18.dp)
    } else {
        RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomEnd = 18.dp, bottomStart = 6.dp)
    }
    val fill = if (msg.isUser) AiQoMint else AiQoSand
    Row(Modifier.fillMaxWidth()) {
        if (!msg.isUser) Spacer(Modifier.weight(1f)) // يدفع فقاعة الكابتن لليسار
        Column(horizontalAlignment = if (msg.isUser) Alignment.Start else Alignment.End) {
            Box(
                Modifier.width(300.dp)
                    .background(Brush.verticalGradient(listOf(fill, fill.copy(alpha = 0.85f))), shape)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Text(msg.text, color = Color(0xFF0F1721), fontWeight = FontWeight.Medium, fontSize = 15.sp, lineHeight = 23.sp)
            }
            if (!msg.isUser && canSpeak) {
                Icon(
                    Icons.AutoMirrored.Filled.VolumeUp, contentDescription = "استمع",
                    tint = Color(0xFF0F1721).copy(alpha = 0.55f),
                    modifier = Modifier.padding(top = 5.dp, start = 2.dp, end = 2.dp).size(15.dp)
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onSpeak(msg.text) },
                )
            }
        }
        if (msg.isUser) Spacer(Modifier.weight(1f)) // يدفع فقاعة المستخدم لليمين
    }
}

/** «RoQo يفكر...» — ثلاث نقاط نعناعية نابضة يمين النص، كما في iOS. */
@Composable
private fun CaptainTypingRow() {
    val pulse = rememberInfiniteTransition(label = "نبض")
    Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            repeat(3) { i ->
                val p by pulse.animateFloat(
                    initialValue = 0f, targetValue = 1f,
                    animationSpec = infiniteRepeatable(tween(480, delayMillis = i * 180), RepeatMode.Reverse),
                    label = "نقطة$i",
                )
                Box(Modifier.size(6.dp).scale(0.82f + 0.4f * p).alpha(0.30f + 0.68f * p).clip(CircleShape).background(CaptainTeal))
            }
        }
        Spacer(Modifier.width(8.dp))
        Text("Rafiqo يفكر...", color = AiQoMuted.copy(alpha = 0.85f), fontWeight = FontWeight.Medium, fontSize = 13.sp)
    }
}

/** RoQo الكبير (وضع العرض): هالة ناعمة + تنفّس بطيء صعودًا ونزولًا. */
@Composable
private fun BreathingRoqo(modifier: Modifier = Modifier) {
    val breath = rememberInfiniteTransition(label = "تنفس")
    val dy by breath.animateFloat(
        initialValue = 0f, targetValue = -8f,
        animationSpec = infiniteRepeatable(tween(3_000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "dy",
    )
    Box(modifier, contentAlignment = Alignment.Center) {
        Box(
            Modifier.fillMaxHeight(0.92f).aspectRatio(0.8f)
                .background(Brush.radialGradient(listOf(Color.White.copy(alpha = 0.85f), AiQoMintCard.copy(alpha = 0.35f), Color.Transparent))),
        )
        Image(
            painter = painterResource(R.drawable.roqo), contentDescription = "Rafiqo",
            contentScale = ContentScale.Fit,
            modifier = Modifier.fillMaxHeight().offset(y = dy.dp),
        )
    }
}

/** الأفاتار المصغر فوق شريط الإدخال (وضع المحادثة) — RoQo داخل دائرة بيضاء. */
@Composable
private fun MiniRoqo() {
    Box(
        Modifier.size(56.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.85f))
            .border(1.dp, Color.White.copy(alpha = 0.55f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.roqo), contentDescription = "Rafiqo",
            contentScale = ContentScale.Fit, modifier = Modifier.fillMaxHeight(0.92f),
        )
    }
}

@Composable
private fun CaptainInputBar(sending: Boolean, onSend: (String) -> Unit) {
    var text by rememberSaveable { mutableStateOf("") }
    val canSend = text.trim().isNotEmpty() && !sending
    fun submit() {
        val t = text.trim()
        if (t.isEmpty() || sending) return
        onSend(t)
        text = ""
    }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(30.dp)).background(Color.White.copy(alpha = 0.92f))
            .border(0.8.dp, Color(0x12000000), RoundedCornerShape(30.dp))
            .padding(start = 18.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (text.isEmpty()) {
                Text("شنو هدفك اليوم؟", color = AiQoMuted.copy(alpha = 0.8f), fontWeight = FontWeight.Medium, fontSize = 17.sp)
            }
            BasicTextField(
                value = text, onValueChange = { text = it },
                textStyle = LocalTextStyle.current.copy(color = AiQoInk, fontWeight = FontWeight.Medium, fontSize = 17.sp),
                cursorBrush = SolidColor(CaptainTeal),
                maxLines = 4,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { submit() }),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier.size(42.dp).clip(CircleShape)
                .background(if (canSend) CaptainTeal.copy(alpha = 0.20f) else Color(0x0D000000))
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, enabled = canSend) { submit() },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.ArrowUpward, contentDescription = "إرسال",
                tint = if (canSend) Color(0xFF2FA88E) else AiQoMuted.copy(alpha = 0.5f),
                modifier = Modifier.size(19.dp),
            )
        }
    }
}
