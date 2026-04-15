enum PostAuthIntentType {
  none,
  openFavorites,
  editProfile,
  openReservations,
  openPropertyDetails,
}

class PostAuthIntent {
  final PostAuthIntentType type;
  final String? propertyId;

  const PostAuthIntent({required this.type, this.propertyId});
}

class PostAuthIntentService {
  PostAuthIntentService._();

  static final PostAuthIntentService instance = PostAuthIntentService._();

  PostAuthIntent _pendingIntent = const PostAuthIntent(
    type: PostAuthIntentType.none,
  );

  void setIntent(PostAuthIntent intent) {
    _pendingIntent = intent;
  }

  PostAuthIntent consumeIntent() {
    final intent = _pendingIntent;
    _pendingIntent = const PostAuthIntent(type: PostAuthIntentType.none);
    return intent;
  }
}
