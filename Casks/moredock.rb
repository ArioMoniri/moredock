cask "moredock" do
  version "0.1.1"
  sha256 "3d3d53c017a2e368b988e55a97c8e03e3bf72ba4b18d75b6bf73c1f6248d7497"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
