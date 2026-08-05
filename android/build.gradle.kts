// No buildscript{} classpath for google-services here on purpose.
//
// The plugin is resolved through the plugins{} block in settings.gradle.kts,
// which is what actually applies. A second declaration here resolved nothing
// but was free to drift out of step with it — and did: this file pinned 4.4.0
// while settings.gradle.kts pinned 4.3.15, leaving the effective version below
// the 4.4.1 floor that Crashlytics 3.x requires and breaking every release
// build with an error naming neither file.
//
// One declaration, in settings.gradle.kts. Version changes go there.

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
