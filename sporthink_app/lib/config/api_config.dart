/// Uygulama genelinde API ayarları
class ApiConfig {
  // ⚠️ TELEFON İLE TEST İÇİN: Bilgisayarın yerel IP adresini yaz (Şu anki IP: 10.0.16.206)
  // ⚠️ EMÜLATÖR İÇİN: 10.0.2.2 kullan
  // ⚠️ PRODUCTION İÇİN: Gerçek sunucu adresini yaz
  
  static const String baseUrl = 'http://10.0.2.2:3000'; // Emülatör için (Varsayılan)
  
  // Kolay geçiş için alternatifler:
  // static const String baseUrl = 'http://10.152.133.61:3000'; // Telefon ile test (Güncel Wi-Fi IP'si)
  // static const String baseUrl = 'https://api.sporthink.com'; // Production
}
