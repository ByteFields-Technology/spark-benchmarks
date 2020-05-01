lazy val scala212 = "2.12.10"
lazy val scala211 = "2.11.12"
lazy val supportedScalaVersions = List(scala212, scala211)

ThisBuild / organization := "com.mapr"
ThisBuild / version      := "0.10.0-SNAPSHOT"
ThisBuild / scalaVersion := scala212

scalaVersion := "2.11.12"

lazy val sparkBenchmarks = project
  .in(file("."))
  .disablePlugins(AssemblyPlugin)
  .aggregate(dfsio)
  .settings(
    // crossScalaVersions must be set to Nil on the aggregating project
    crossScalaVersions := Nil,
    publish / skip := true
  )

lazy val dfsio = project
  .enablePlugins( AssemblyPlugin, BuildInfoPlugin)
  .settings(
    crossScalaVersions := supportedScalaVersions,
    name := "spark-benchmarks-dfsio",
    buildInfoPackage := "com.bbva.spark.benchmarks.dfsio",
    scalaVersion := "2.11.12",
    Dependencies.Spark,
    Dependencies.Scopt,
    Dependencies.Alluxio
  )

//organizationName := "Heiko Seeberger"
organizationName := "MAPR"
startYear := Some(2015)
licenses += ("Apache-2.0", new URL("https://www.apache.org/licenses/LICENSE-2.0.txt"))
headerLicenseStyle := HeaderLicenseStyle.SpdxSyntax

