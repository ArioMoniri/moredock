cask "moredock" do
  version "0.1.2"
  sha256 "c61159b0bda18554f68da9ba8f765fd9da84c4e7c2ee4bc2d055c7754200a843"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
