import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (releaseBuildRequested) {
    val dartDefines = providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(',')
        .mapNotNull { encodedDefine ->
            runCatching {
                String(Base64.getDecoder().decode(encodedDefine), StandardCharsets.UTF_8)
            }.getOrNull()
        }
        .mapNotNull { define ->
            val separatorIndex = define.indexOf('=')
            if (separatorIndex < 0) null else
                define.substring(0, separatorIndex) to define.substring(separatorIndex + 1)
        }
        .toMap()

    if (dartDefines["API_BASE_URL"] != "https://srv2008002.hstgr.cloud") {
        throw GradleException(
            "Release requires API_BASE_URL=https://srv2008002.hstgr.cloud. Use tool/flutter_with_env.dart.",
        )
    }

    if (dartDefines["CARTO_API_KEY"].isNullOrBlank()) {
        throw GradleException(
            "Release requires CARTO_API_KEY. Use tool/flutter_with_env.dart.",
        )
    }
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.isFile) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

android {
    namespace = "cloud.hstgr.srv2008002"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "cloud.hstgr.srv2008002"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            signingProperties.getProperty("storeFile")?.let { storeFile = file(it) }
            signingProperties.getProperty("storePassword")?.let { storePassword = it }
            signingProperties.getProperty("keyAlias")?.let { keyAlias = it }
            signingProperties.getProperty("keyPassword")?.let { keyPassword = it }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
