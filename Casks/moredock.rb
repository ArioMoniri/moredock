cask "moredock" do
  version "0.1.4"
  sha256 "a1019c21a16283851f1288d834c5ae08ed1980838632a3ce8404f5e9b7c37b92"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
