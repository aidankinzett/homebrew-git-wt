class GitWt < Formula
  desc "Interactive git worktree manager with fuzzy finder"
  homepage "https://github.com/aidankinzett/homebrew-git-wt"
  head "https://github.com/aidankinzett/homebrew-git-wt.git", branch: "main"

  depends_on "fzf"

  def install
    bin.install "git-wt"
  end

  test do
    system "#{bin}/git-wt", "--help"
  end
end
