cask "moredock" do
  version "0.1.4"
  sha256 "e4789323bd7b024db2ed5be3a46cc955dd367060e585c643229636cb030737a0"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
