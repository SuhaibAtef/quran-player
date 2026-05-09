class RoutePaths {
  const RoutePaths._();

  static const home = '/';
  static const surahDetail = '/surahs/:id';
  static const search = '/search';
  static const bookmarks = '/bookmarks';
  static const settings = '/settings';
  static const mcpStatus = '/mcp';
  static const dataIntegrityError = '/_error/data-integrity';
  static const bootstrapping = '/_loading';

  static String surahDetailFor(String id) => '/surahs/$id';
}

class RouteNames {
  const RouteNames._();

  static const home = 'home';
  static const surahDetail = 'surah_detail';
  static const search = 'search';
  static const bookmarks = 'bookmarks';
  static const settings = 'settings';
  static const mcpStatus = 'mcp_status';
  static const dataIntegrityError = 'data_integrity_error';
  static const bootstrapping = 'bootstrapping';
}
