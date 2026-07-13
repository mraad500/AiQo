package com.mraad500.aiqo.data

import com.mraad500.aiqo.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

data class AndroidAuthSession(
    val userId: String,
    val email: String,
    val accessToken: String,
)

sealed interface AndroidAuthResult {
    data class Success(val session: AndroidAuthSession) : AndroidAuthResult
    data class Error(val message: String) : AndroidAuthResult
}

object SupabaseAuthClient {
    private val supabaseUrl: String = BuildConfig.SUPABASE_URL.trim().trimEnd('/')
    private val anonKey: String = BuildConfig.SUPABASE_ANON_KEY.trim()

    val isConfigured: Boolean
        get() = supabaseUrl.startsWith("https://") && anonKey.isNotEmpty()

    suspend fun signIn(email: String, password: String): AndroidAuthResult =
        requestAuth(
            endpoint = "$supabaseUrl/auth/v1/token?grant_type=password",
            email = email,
            password = password,
        )

    suspend fun signUp(email: String, password: String): AndroidAuthResult =
        requestAuth(
            endpoint = "$supabaseUrl/auth/v1/signup",
            email = email,
            password = password,
        )

    private suspend fun requestAuth(
        endpoint: String,
        email: String,
        password: String,
    ): AndroidAuthResult = withContext(Dispatchers.IO) {
        if (!isConfigured) {
            return@withContext AndroidAuthResult.Error(
                "Supabase بعده غير مضبوط بنسخة Android. تقدر تتابع بدون حساب حالياً.",
            )
        }

        runCatching {
            val body = JSONObject()
                .put("email", email)
                .put("password", password)
                .toString()

            val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("apikey", anonKey)
                setRequestProperty("Authorization", "Bearer $anonKey")
            }

            connection.outputStream.use { stream ->
                stream.write(body.toByteArray(Charsets.UTF_8))
            }

            val responseText = connection.readText()
            if (connection.responseCode !in 200..299) {
                return@withContext AndroidAuthResult.Error(
                    responseText.supabaseErrorMessage()
                        ?: "فشل تسجيل الدخول. تأكد من الإيميل وكلمة المرور.",
                )
            }

            val json = JSONObject(responseText)
            val user = json.optJSONObject("user")
            val session = AndroidAuthSession(
                userId = user?.optString("id").orEmpty(),
                email = user?.optString("email").takeUnless { it.isNullOrBlank() } ?: email,
                accessToken = json.optString("access_token"),
            )

            AndroidAuthResult.Success(session)
        }.getOrElse { error ->
            AndroidAuthResult.Error(error.localizedMessage ?: "صار خطأ غير متوقع.")
        }
    }

    private fun HttpURLConnection.readText(): String {
        val input = if (responseCode in 200..299) inputStream else errorStream
        return input?.use { stream ->
            BufferedReader(InputStreamReader(stream)).readText()
        }.orEmpty()
    }

    private fun String.supabaseErrorMessage(): String? {
        if (isBlank()) return null
        return runCatching {
            val json = JSONObject(this)
            json.optString("msg")
                .ifBlank { json.optString("message") }
                .ifBlank { json.optString("error_description") }
                .ifBlank { null }
        }.getOrNull()
    }
}
