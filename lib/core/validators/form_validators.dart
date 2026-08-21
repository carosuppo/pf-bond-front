/// Validadores de formulario compartidos por las pantallas de la aplicación.
class FormValidators {
  const FormValidators._();

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'El nombre es obligatorio.';
    }

    if (name.length < 2 || name.length > 100) {
      return 'El nombre debe tener entre 2 y 100 caracteres.';
    }

    final nameRegex = RegExp(r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü\s'-]+$");

    if (!nameRegex.hasMatch(name)) {
      return 'El nombre solo puede contener letras, espacios, guiones o apóstrofes.';
    }

    return null;
  }

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'El email es obligatorio.';
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      return 'Ingresá un email válido.';
    }

    return null;
  }
}
