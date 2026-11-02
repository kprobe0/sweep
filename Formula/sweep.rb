class Sweep < Formula
  desc "Quiet disk cleaner for macOS"
  homepage "https://github.com/kprobe0/sweep"
  url "https://github.com/kprobe0/sweep/archive/refs/tags/v0.16.0.tar.gz"
  sha256 "794a0377398ec691273c7280616cde2ab2898e356931576ac4893c0bb585ce4f"
  license "MIT"
  head "https://github.com/kprobe0/sweep.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  def install
    bin.install "sweep"
    bash_completion.install "completions/sweep.bash" => "sweep"
    zsh_completion.install "completions/_sweep"
    man1.install "sweep.1"
  end

  def caveats
    <<~EOS
      sweep does not phone home. Run `sweep` in Terminal.
    EOS
  end
end
