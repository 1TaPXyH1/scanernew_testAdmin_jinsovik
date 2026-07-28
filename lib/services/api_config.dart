class ApiConfig {
  static const String baseUrl = 'https://static.88-198-21-139.clients.your-server.de:956';
  static const String productEndpoint = '/REST/hs/prices/product_new';

  static String productUrl(String barcode) => '$baseUrl$productEndpoint/$barcode/';
}
