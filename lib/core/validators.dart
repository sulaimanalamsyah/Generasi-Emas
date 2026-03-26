String? emailValidator(String? v) {
  if (v == null || v.isEmpty) return 'Wajib diisi';
  if (!v.contains('@')) return 'Email tidak valid';
  return null;
}

String? requiredValidator(String? v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null;

String? minLength(String? v, int n) {
  if (v == null || v.length < n) return 'Min $n karakter';
  return null;
}
