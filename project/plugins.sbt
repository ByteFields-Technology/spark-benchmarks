logLevel := Level.Warn

resolvers += Resolver.url("bintray-sbt-plugins", url("http://dl.bintray.com/sbt/sbt-plugin-releases"))(Resolver.ivyStylePatterns)

addSbtPlugin("de.heikoseeberger"                 % "sbt-header"       % "5.6.0")
//addSbtPlugin("com.geirsson"                      % "sbt-scalafmt"     % "0.6.8")
addSbtPlugin("org.scalameta"                     % "sbt-scalafmt" % "2.3.2")
//addSbtPlugin("com.dwijnand"                      % "sbt-dynver"       % "1.2.0")
addSbtPlugin("com.lightbend.paradox"             % "sbt-paradox"      % "latest.release")
addSbtPlugin("com.eed3si9n"                      % "sbt-unidoc"       % "latest.release")
addSbtPlugin("com.thoughtworks.sbt-api-mappings" % "sbt-api-mappings" % "latest.release")
addSbtPlugin("com.eed3si9n"                      % "sbt-assembly"     % "latest.release")
addSbtPlugin("com.eed3si9n"                      % "sbt-buildinfo"    % "latest.release")