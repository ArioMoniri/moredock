cask "moredock" do
  version "0.3.7"
  sha256 "9ffd5c8223dfe0ea7386429a28972dcf782b0bcfab2b79af8a5d54f1a59abe09"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
