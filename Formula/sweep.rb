class Sweep < Formula
  desc "Quiet disk cleaner for macOS"
  homepage "https://github.com/kprobe0/sweep"
  url "https://github.com/kprobe0/sweep/archive/refs/tags/v0.12.0.tar.gz"
  sha256 "0f9f5d79b3af56010d968a98d801b8703310b1b9a93baff43c125513f21eefaf"
  license "MIT"
  head "https://github.com/kprobe0/sweep.git", branch: "main"

  def install
    bin.install "sweep"
  end

  def caveats
    <<~EOS
      sweep does not phone home. Run `sweep` in Terminal.
    EOS
  end
end
