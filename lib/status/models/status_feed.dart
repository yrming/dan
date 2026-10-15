/// Current timeline-like status feeds.
enum StatusFeed {
  /// Home timeline.
  home,

  /// Public timeline from non-protected accounts.
  public,

  /// Public statuses matching a submitted keyword.
  search,

  /// Statuses posted by the active account matching a keyword.
  searchMine,

  /// Statuses posted by a selected user matching a keyword.
  searchUser,

  /// Mentions timeline.
  mentions,

  /// Statuses posted by one user.
  user,

  /// Statuses with photos posted by one user.
  photos,

  /// Favorite statuses.
  favorites,
}
