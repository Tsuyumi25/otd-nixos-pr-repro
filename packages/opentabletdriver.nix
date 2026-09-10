{
  lib,
  buildDotnetModule,
  copyDesktopItems,
  coreutils,
  diffutils,
  dotnetCorePackages,
  gtk3,
  jq,
  libappindicator,
  libevdev,
  libnotify,
  libx11,
  libxrandr,
  makeDesktopItem,
  src,
  udev,
  wrapGAppsHook3,
  versionCheckHook,
  udevCheckHook,
  hidSharpCore,
}:

let
  # Regenerate with:
  #   nix build .#packages.x86_64-linux.opentabletdriver.fetch-deps
  #   ./result packages/deps.json
  nugetDeps = ./deps.json;
  hasUpstreamHidSharpCore = lib.any (dependency: lib.toLower dependency.pname == "hidsharpcore") (
    lib.importJSON nugetDeps
  );
in
assert lib.assertMsg (!hasUpstreamHidSharpCore) ''
  deps.json must not contain the upstream HidSharpCore package;
  PR #31 is supplied through projectReferences.
'';
buildDotnetModule (finalAttrs: {
  pname = "OpenTabletDriver";
  version = "0.6.7-pr4672.3339730";

  inherit src nugetDeps;

  dotnet-sdk =
    with dotnetCorePackages;
    sdk_10_0
    // {
      inherit
        (combinePackages [
          sdk_10_0
          sdk_8_0
        ])
        packages
        targetPackages
        ;
    };

  projectFile = [
    "OpenTabletDriver.Console"
    "OpenTabletDriver.Daemon"
    "OpenTabletDriver.UX.Gtk"
  ];
  projectReferences = [ hidSharpCore ];

  executables = [
    "OpenTabletDriver.Console"
    "OpenTabletDriver.Daemon"
    "OpenTabletDriver.UX.Gtk"
  ];

  nativeBuildInputs = [
    copyDesktopItems
    wrapGAppsHook3
    udevCheckHook
    jq
  ];

  runtimeDeps = [
    gtk3
    libappindicator
    libevdev
    libnotify
    libx11
    libxrandr
    udev
  ];
  buildInputs = finalAttrs.runtimeDeps;

  env.OTD_CONFIGURATIONS = "${finalAttrs.src}/OpenTabletDriver.Configurations/Configurations";

  doCheck = true;
  testProjectFile = "OpenTabletDriver.Tests/OpenTabletDriver.Tests.csproj";

  disabledTests = [
    "OpenTabletDriver.Tests.UpdaterTests.CheckForUpdates_Returns_Update_When_Available"
    "OpenTabletDriver.Tests.UpdaterTests.Install_Throws_UpdateAlreadyInstalledException_When_AlreadyInstalled"
    "OpenTabletDriver.Tests.UpdaterTests.Install_DoesNotThrow_UpdateAlreadyInstalledException_When_PreviousInstallFailed"
    "OpenTabletDriver.Tests.UpdaterTests.Install_Throws_UpdateInProgressException_When_AnotherUpdate_Is_InProgress"
    "OpenTabletDriver.Tests.UpdaterTests.Install_Moves_UpdatedBinaries_To_BinDirectory"
    "OpenTabletDriver.Tests.UpdaterTests.Install_Moves_Only_ToBeUpdated_Binaries"
    "OpenTabletDriver.Tests.UpdaterTests.Install_Copies_AppDataFiles"
    "OpenTabletDriver.Tests.TimerTests.TimerAccuracy"
  ];

  preBuild = ''
    patchShebangs generate-rules.sh
    substituteInPlace generate-rules.sh \
      --replace-fail '/usr/bin/env rm' '${lib.getExe' coreutils "rm"}'
  '';

  dontWrapGApps = true;

  postFixup = ''
    # Give a more "*nix" name to the binaries
    mv $out/bin/OpenTabletDriver.Console $out/bin/otd
    mv $out/bin/OpenTabletDriver.Daemon $out/bin/otd-daemon
    mv $out/bin/OpenTabletDriver.UX.Gtk $out/bin/otd-gui

    install -Dm644 $src/OpenTabletDriver.UX/Assets/otd.png -t $out/share/icons

    # Generate udev rules from source
    mkdir -p $out/lib/udev/rules.d
    ./generate-rules.sh > $out/lib/udev/rules.d/70-opentabletdriver.rules

    wrapProgram $out/bin/otd-gui \
      "''${gappsWrapperArgs[@]}" \
      --add-flags --skipupdate
  '';

  desktopItems = [
    (makeDesktopItem {
      desktopName = "OpenTabletDriver";
      name = "OpenTabletDriver";
      exec = "otd-gui";
      icon = "otd";
      comment = "Open source, cross-platform, user-mode tablet driver";
      categories = [ "Utility" ];
    })
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    diffutils
  ];
  preInstallCheck = ''
    cmp \
      ${hidSharpCore}/lib/HidSharpCore/HidSharpCore.dll \
      $out/lib/OpenTabletDriver/HidSharpCore.dll
  '';
  versionCheckProgram = "${placeholder "out"}/bin/otd-daemon";

  passthru = {
    pullRequest = 4672;
    revision = "3339730d0e469978d29324bf94acf242ceec74a1";
    hidSharpCoreRevision = hidSharpCore.passthru.revision;
  };

  meta = {
    description = "Open source, cross-platform, user-mode tablet driver";
    homepage = "https://github.com/OpenTabletDriver/OpenTabletDriver";
    license = lib.licenses.lgpl3Plus;
    mainProgram = "otd";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
