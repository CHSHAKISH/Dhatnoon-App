plugins {
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.android.application") version "8.7.3" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// CORRECTED: 'root' changed to 'rootProject'
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
// CORRECTED: 'root' changed to 'rootProject'
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    // CORRECTED: 'root' changed to 'rootProject'
    delete(rootProject.layout.buildDirectory)
}