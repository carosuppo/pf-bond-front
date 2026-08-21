/// Datos enviados al backend al actualizar el perfil.
///
/// Ambos campos son opcionales: solo se envían los que fueron modificados.
class UpdateProfileRequest {
  final String? name;
  final String? email;

  const UpdateProfileRequest({this.name, this.email});

  Map<String, dynamic> toJson() {
    return {if (name != null) 'name': name, if (email != null) 'email': email};
  }
}
