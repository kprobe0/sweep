class Sweep < Formula
  desc "Quiet disk cleaner for macOS"
  homepage "https://github.com/kprobe0/sweep"
  url "https://github.com/kprobe0/sweep/archive/refs/tags/v0.13.0.tar.gz"
  sha256 "b888b2e6bbc2a132ac112aeb121265ad8370a1d4a0d18a6585c35e3a8dc3937a"
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
