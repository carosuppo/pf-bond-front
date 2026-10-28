/// Divide un importe en partes iguales entre los participantes.
/// Los centavos sobrantes se asignan de a uno a los primeros,
/// igual que en el backend, para que las partes sumen el total.
List<({int memberId, int amountCents})> splitEquallyCents(
  int totalCents,
  List<int> memberIds,
) {
  final base = totalCents ~/ memberIds.length;
  final remainder = totalCents % memberIds.length;

  return [
    for (var i = 0; i < memberIds.length; i++)
      (memberId: memberIds[i], amountCents: base + (i < remainder ? 1 : 0)),
  ];
}
