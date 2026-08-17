enum AppEnvironment {
  development,
  staging,
  production;

  factory AppEnvironment.fromString(String value) {
    switch (value.toLowerCase()) {
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
        return AppEnvironment.production;
      case 'development':
      default:
        return AppEnvironment.development;
    }
  }
}
