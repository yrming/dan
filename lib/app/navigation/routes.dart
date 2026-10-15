/// Route names used by the application.
abstract final class AppRouteName {
  /// Loading route.
  static const loading = 'loading';

  /// Login route.
  static const login = 'login';

  /// Authentication failure route.
  static const authenticationFailure = 'authentication-failure';

  /// Home tab route.
  static const home = 'home';

  /// Mentions tab route.
  static const mentions = 'mentions';

  /// Browse tab route.
  static const browse = 'browse';

  /// Public status search route.
  static const search = 'search';

  /// Active account profile tab route.
  static const mine = 'mine';

  /// Favorite statuses route.
  static const favorites = 'favorites';

  /// User statuses route.
  static const userStatuses = 'user-statuses';

  /// User photo statuses route.
  static const userPhotos = 'user-photos';

  /// Accounts followed by a user.
  static const following = 'following';

  /// Accounts following a user.
  static const followers = 'followers';

  /// Active account blacklist.
  static const blacklist = 'blacklist';

  /// Incoming follow requests.
  static const followRequests = 'follow-requests';

  /// Appearance settings route.
  static const settings = 'settings';

  /// Font-size adjustment below settings.
  static const fontSize = 'font-size';

  /// Add-account route.
  static const addAccount = 'add-account';

  /// Status detail route.
  static const statusDetail = 'status-detail';

  /// User profile route.
  static const userProfile = 'user-profile';

  /// Status image viewer route.
  static const statusImageViewer = 'status-image-viewer';

  /// Status composer route.
  static const statusComposer = 'status-composer';

  /// Direct message conversation list route.
  static const directMessageList = 'direct-messages';

  /// Direct message conversation route.
  static const directMessageConversation = 'direct-message-conversation';
}

/// Route paths used by the application.
abstract final class AppRoutePath {
  /// Loading path.
  static const loading = '/loading';

  /// Login path.
  static const login = '/login';

  /// Authentication failure path.
  static const authenticationFailure = '/authentication-failure';

  /// Home tab path.
  static const home = '/home';

  /// Mentions tab path.
  static const mentions = '/mentions';

  /// Browse tab path.
  static const browse = '/browse';

  /// Public status search path.
  static const search = '/search';

  /// Active account profile tab path.
  static const mine = '/mine';

  /// Favorite statuses path for a user.
  static const favorites = '/favorites/:userId';

  /// Statuses path for a user.
  static const userStatuses = '/statuses/:userId';

  /// Photo statuses path for a user.
  static const userPhotos = '/photos/:userId';

  /// Accounts followed by a user.
  static const following = '/following/:userId';

  /// Accounts following a user.
  static const followers = '/followers/:userId';

  /// Active account blacklist.
  static const blacklist = '/blacklist';

  /// Incoming follow requests for the active account.
  static const followRequests = '/follow-requests';

  /// Appearance settings path relative to a user route.
  static const settings = 'settings';

  /// Font-size adjustment below settings.
  static const fontSize = 'font-size';

  /// Add-account path relative to the settings route.
  static const addAccount = 'add-account';

  /// Status detail path.
  static const statusDetail = '/:userId/status/:statusId';

  /// User profile path.
  static const userProfile = '/:userId';

  /// Status image viewer path.
  static const statusImageViewer = '/status-image';

  /// Status composer path.
  static const statusComposer = '/status/compose';

  /// Direct message conversation list path.
  static const directMessageList = '/direct-messages';

  /// Direct message conversation path with a user.
  static const directMessageConversation = '/direct-messages/:userId';
}
