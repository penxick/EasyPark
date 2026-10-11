import java.util.Properties
import java.util.Base64
import java.net.URI

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeys = Properties()
val releaseKeysFile = rootProject.file("key.properties")
if (releaseKeysFile.exists()) releaseKeysFile.inputStream().use { releaseKeys.load(it) }
val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseKeys = requiredKeys.all { !releaseKeys.getProperty(it).isNullOrBlank() }
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") }) {
        check(hasReleaseKeys) { "Release signing is not configured. See docs/android-apk-build.md." }
        check(rootProject.file(releaseKeys.getProperty("storeFile")).isFile) { "Release keystore does not exist." }
        val defines = (project.findProperty("dart-defines") as? String).orEmpty().split(',')
            .filter { it.isNotEmpty() }.map { String(Base64.getDecoder().decode(it)) }
        val api = defines.lastOrNull { it.startsWith("API_BASE_URL=") }?.substringAfter('=')
        val uri = api?.let { URI(it) }
        check(uri != null && uri.scheme == "https" && !uri.host.isNullOrBlank() &&
            uri.host !in listOf("localhost", "10.0.2.2", "127.0.0.1", "[::1]") &&
            uri.userInfo == null && uri.query == null && uri.fragment == null) {
            "Release requires an explicit HTTPS API_BASE_URL without credentials or loopback host."
        }
    }
}

android {
    namespace = "com.easypark.easypark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.easypark.easypark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24 // Required by flutter_secure_storage 11.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("release") {
                storeFile = rootProject.file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
