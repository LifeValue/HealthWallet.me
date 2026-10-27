allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            if (namespace.isNullOrEmpty()) {
                namespace = project.group.toString().ifEmpty {
                    val manifest = project.file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val pkg = Regex(
                            "package=\"([^\"]+)\""
                        ).find(manifest.readText())?.groupValues?.get(1)
                        pkg ?: "com.${project.name.replace("-", ".")}"
                    } else {
                        "com.${project.name.replace("-", ".")}"
                    }
                }
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
            // Current AndroidX libraries and flutter_plugin_android_lifecycle require compileSdk 36+,
            // but several plugins still compile against 31-35 (e.g. flutter_google_wallet 0.2.1, its
            // latest release; bonsoir_android 5.x; desktop_drop 0.4.x; file_picker 8.x). compileSdk
            // only affects which APIs compile; it doesn't change runtime behaviour (that's
            // targetSdk), so raising it for them is safe.
            if ((
                    compileSdkVersion?.removePrefix("android-")?.substringBefore('.')?.toIntOrNull()
                        ?: 0
                    ) <
                36
            ) {
                compileSdkVersion(37)
            }
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
