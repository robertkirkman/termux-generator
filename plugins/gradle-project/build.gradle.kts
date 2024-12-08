plugins {
    java
    application
}

application {
    mainClass.set("hello.helloworld")
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = application.mainClass.get()
    }
}