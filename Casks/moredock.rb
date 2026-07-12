cask "moredock" do
  version "0.4.4"
  sha256 "64f6a7d6460251a6700e63f9b86bdca2d79b82dc35807f00b8bf6b37ccbc4a7e"

  url "https://github.com/ArioMoniri/moredock/releases/download/v#{version}/MoreDock-#{version}-macOS.dmg"
  name "MoreDock"
  desc "Native macOS Dock-style launcher for every display"
  homepage "https://github.com/ArioMoniri/moredock"

  app "MoreDock.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.moredock.plist",
  ]
end
