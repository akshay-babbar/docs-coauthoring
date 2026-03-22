def get_diff(commit_range: str, include_untracked: bool = False) -> str:
    """Run git diff for the given commit range.

    Args:
        commit_range: A valid git ref or range like HEAD~3..HEAD.
        include_untracked: Whether to include untracked files. Defaults to False. [inferred — verify]

    Returns:
        Raw diff output as a string.
    """
    pass
