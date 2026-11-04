class Sweep < Formula
  desc "Quiet disk cleaner for macOS"
  homepage "https://github.com/kprobe0/sweep"
  url "https://github.com/kprobe0/sweep/archive/refs/tags/v0.18.0.tar.gz"
  sha256 "057915577cafa4da97c43bb1045d4d9fbf084e08edcc711bac8b65c764fefbd9"
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
