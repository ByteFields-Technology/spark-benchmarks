import sbt._
import Keys._

object Dependencies {

  val AlluxioVersion = "1.4.0"
  val ScalaVersion = "2.11.12"
  val ScalaLoggingVersion = "3.5.0"
  val ScalaTestVersion = "3.0.1"
  val ScoptVersion = "3.5.0"
  val SparkVersion = "2.4.4"

  val Common = Seq(
    libraryDependencies ++= Seq(
      "org.scalatest" %% "scalatest" % ScalaTestVersion % Test,
      "com.typesafe.scala-logging" %% "scala-logging" % ScalaLoggingVersion
    )
  )

  val Spark = Seq(
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % SparkVersion % Provided,
      "org.apache.spark" %% "spark-sql" % SparkVersion % Provided,
      "com.typesafe.scala-logging" %% "scala-logging" % "3.9.2",
      "ch.qos.logback" % "logback-classic" % "1.2.3"
    )
  )


  val SparkMllib = Seq(
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-mllib" % SparkVersion % Provided
    )
  )

  val Alluxio = Seq(
    libraryDependencies ++= Seq(
      "org.alluxio" % "alluxio-core-client" % AlluxioVersion % Provided
    )
  )


  val Scopt = Seq(
    libraryDependencies ++= Seq(
      "com.github.scopt" %% "scopt" % ScoptVersion
    )
  )

}