enum RouteMode {
  driving('DRIVING', 'Auto'),
  walking('WALKING', 'Caminando');

  const RouteMode(this.backendValue, this.label);

  final String backendValue;
  final String label;
}
