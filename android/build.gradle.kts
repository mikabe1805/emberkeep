allprojects {
    repositories {
        google()
        mavenCentral()
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

// Some plugins (flutter_timezone) still compile Java at 11 while their Kotlin
// sits at 1.8, which modern AGP rejects as an inconsistent JVM target. Pin
// every subproject's Java and Kotlin to 17 so plugin defaults can't disagree.
subprojects {
    fun pinJavaTargets() {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions
            ?.apply {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
    }
    // afterEvaluate, so the pin lands AFTER each plugin's own script sets
    // its (often ancient) compileOptions. The state guard skips :app, which
    // evaluationDependsOn already evaluated — it manages its own options.
    if (!state.executed) {
        afterEvaluate { pinJavaTargets() }
    }
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
        .configureEach {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            )
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
