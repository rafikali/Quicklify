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

// Force consistent JVM target across all subprojects (plugins)
// Match Kotlin JVM target to whatever Java target each plugin sets
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            val javaCompile = project.tasks.findByName("compileDebugJavaWithJavac") as? JavaCompile
            val javaVersion = javaCompile?.targetCompatibility
            val target = when (javaVersion) {
                "1.8", "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }
            jvmTarget.set(target)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
