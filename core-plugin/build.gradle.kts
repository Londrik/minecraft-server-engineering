plugins {
    `java-library`
    id("com.gradleup.shadow") version "8.3.3"
}

group = "com.server"
version = "1.0.0-SNAPSHOT"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

repositories {
    mavenCentral()
    maven("https://repo.papermc.io/repository/maven-public/")
}

dependencies {
    compileOnly("io.papermc.paper:paper-api:1.21.1-R0.1-SNAPSHOT")
    implementation("com.zaxxer:HikariCP:5.1.0")
    implementation("com.github.ben-manes.caffeine:caffeine:3.1.8")
    implementation("org.postgresql:postgresql:42.7.4")
}

tasks {
    compileJava {
        options.encoding = "UTF-8"
        options.release.set(21)
    }

    shadowJar {
        archiveClassifier.set("")
        relocate("com.zaxxer.hikari", "com.server.libs.hikari")
        relocate("com.github.benmanes.caffeine", "com.server.libs.caffeine")
        relocate("org.postgresql", "com.server.libs.postgresql")
    }

    build {
        dependsOn(shadowJar)
    }
}
