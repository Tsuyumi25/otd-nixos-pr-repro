{
  buildDotnetModule,
  dotnetCorePackages,
  src,
}:

buildDotnetModule {
  pname = "HidSharpCore";
  version = "1.3.0";

  inherit src;
  projectFile = "HidSharp/HidSharp.csproj";
  nugetDeps = [ ];

  dotnet-sdk = dotnetCorePackages.sdk_8_0;

  packNupkg = true;
  executables = [ ];
  doCheck = false;

  passthru = {
    pullRequest = 31;
    revision = "34667a671f96e52a2cf2c93c9ac263634085a368";
  };
}
