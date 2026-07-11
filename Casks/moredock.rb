cask "moredock" do
  version "0.3.5"
  sha256 "b04adbbfd105dc58bbdb938df459e4ee6d33b1b13ecaf59140d5ea201960ae10"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
