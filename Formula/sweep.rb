class Sweep < Formula
  desc "Quiet disk cleaner for macOS"
  homepage "https://github.com/kprobe0/sweep"
  url "https://github.com/kprobe0/sweep/archive/refs/tags/v0.14.0.tar.gz"
  sha256 "881a879dc334e119c1c44f6afca5b13591681c3a032c5fbf00af4bc33c291f86"
  license "MIT"
  head "https://github.com/kprobe0/sweep.git", branch: "main"

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
