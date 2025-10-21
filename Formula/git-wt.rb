class GitWt < Formula
  desc "Interactive git worktree manager with fuzzy finder"
  homepage "https://github.com/aidankinzett/git-wt"
  # For local development, we'll use the local repo
  url "file:///Users/aidankinzett/Git/git-wt", using: :git
  version "0.1.0"
  head "file:///Users/aidankinzett/Git/git-wt", using: :git

  depends_on "fzf"

  def install
    bin.install "git-wt"
  end

  test do
    system "#{bin}/git-wt", "--help"
  end
end
