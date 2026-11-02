const minimumAccountAgeYears = 13;

String? validateBirthDateRequired(DateTime? birthDate) {
  if (birthDate == null) {
    return 'La fecha de nacimiento es obligatoria.';
  }

  return null;
}

String? validateMinimumAccountAge(DateTime? birthDate, {DateTime? today}) {
  final requiredError = validateBirthDateRequired(birthDate);
  if (requiredError != null) return requiredError;

  final currentDate = today ?? DateTime.now();
  final todayDate = DateTime(
    currentDate.year,
    currentDate.month,
    currentDate.day,
  );
  final minimumBirthDate = DateTime(
    todayDate.year - minimumAccountAgeYears,
    todayDate.month,
    todayDate.day,
  );
  final selectedDate = DateTime(
    birthDate!.year,
    birthDate.month,
    birthDate.day,
  );

  if (selectedDate.isAfter(todayDate) ||
      selectedDate.isAfter(minimumBirthDate)) {
    return 'La fecha ingresada no pudo ser validada.';
  }

  return null;
}

String formatBirthDate(DateTime birthDate) {
  return '${birthDate.day.toString().padLeft(2, '0')}/${birthDate.month.toString().padLeft(2, '0')}/${birthDate.year}';
}

String serializeBirthDate(DateTime birthDate) {
  return '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
}
