class Sweep < Formula
  desc "Quiet disk cleaner for macOS"
  homepage "https://github.com/kprobe0/sweep"
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
