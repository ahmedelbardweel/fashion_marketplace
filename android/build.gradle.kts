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
    // Register before :app evaluation triggers evaluation of Flutter plugins.
    plugins.withId("com.android.library") {
        extensions.getByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)
            .finalizeDsl { library ->
                if ((library.compileSdk ?: 0) < 36) {
                    library.compileSdk = 36
                }
            }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerExecutionStrategy.set(
            org.jetbrains.kotlin.gradle.tasks.KotlinCompilerExecutionStrategy.IN_PROCESS
        )
        useDaemonFallbackStrategy.set(true)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
