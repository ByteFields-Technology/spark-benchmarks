lazy val sparkBenchmarks = project
  .in(file("."))
  .disablePlugins(AssemblyPlugin)
  .aggregate(dfsio)

lazy val dfsio = project
  .enablePlugins( AssemblyPlugin, BuildInfoPlugin)
  .settings(
    name := "spark-benchmarks-dfsio",
    buildInfoPackage := "com.bbva.spark.benchmarks.dfsio",
    Dependencies.Spark,
    Dependencies.Scopt,
    Dependencies.Alluxio
  )

organizationName := "Heiko Seeberger"
startYear := Some(2015)
licenses += ("Apache-2.0", new URL("https://www.apache.org/licenses/LICENSE-2.0.txt"))
headerLicenseStyle := HeaderLicenseStyle.SpdxSyntax

