allprojects {
    repositories {
        google()
        mavenCentral()
        // Required by agora_rtc_engine / iris_method_channel for flutter_embedding_debug
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

// Force all plugin subprojects to compile against SDK 36.
// This satisfies flutter_plugin_android_lifecycle's requirement when
// plugins like file_picker are compiled against an older SDK.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as? com.android.build.gradle.BaseExtension)?.let { android ->
                try {
                    val current = android.compileSdkVersion
                        ?.removePrefix("android-")?.toIntOrNull() ?: 0
                    if (current in 1..35) {
                        android.compileSdkVersion(36)
                    }
                } catch (_: Exception) { /* ignore non-android modules */ }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
