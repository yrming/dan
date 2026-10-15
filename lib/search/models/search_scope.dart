enum SearchScope { all, mine, his, hers, theirs }

/// Converts a profile gender value into the corresponding search scope.
SearchScope searchScopeForGender(String? gender) {
  switch (gender?.trim().toLowerCase()) {
    case '男':
    case 'male':
    case 'm':
      return SearchScope.his;
    case '女':
    case 'female':
    case 'f':
      return SearchScope.hers;
    default:
      return SearchScope.theirs;
  }
}

/// Returns the query value used when opening the search route.
String searchScopeQueryValue(SearchScope scope) => scope.name;
