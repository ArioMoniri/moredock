cask "moredock" do
  version "0.3.3"
  sha256 "d7512466b2f21f1af3e976667c1c7e6aaabd448557173e5650471d9a2207b6dc"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
