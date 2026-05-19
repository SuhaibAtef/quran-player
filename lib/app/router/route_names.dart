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

  // Reader routes. Page and surah are concrete targets; ayah is an
  // addressable redirect that resolves to whichever mode is active.
  static const readerPagePattern = '/reader/page/:pageNumber';
  static const readerSurahPattern = '/reader/surah/:surahNumber';
  static const readerAyahPattern = '/reader/ayah/:surah/:ayah';

  static String surahDetailFor(String id) => '/surahs/$id';
  static String readerPageFor(int pageNumber) => '/reader/page/$pageNumber';
  static String readerSurahFor(int surahNumber) => '/reader/surah/$surahNumber';
  static String readerAyahFor(int surah, int ayah) =>
      '/reader/ayah/$surah/$ayah';
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
  static const readerPage = 'reader_page';
  static const readerSurah = 'reader_surah';
  static const readerAyah = 'reader_ayah';
}
