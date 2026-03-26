import 'package:flutter/material.dart';
import '../routes.dart';

void goHomeByRole(BuildContext context, String? role) {
  switch ((role ?? 'mother').toLowerCase()) {
    case 'nurse':
      Navigator.pushNamedAndRemoveUntil(context, Routes.nurseHome, (_) => false);
      break;
    case 'mother':
    case 'father':
    default:
      Navigator.pushNamedAndRemoveUntil(context, Routes.homePatient, (_) => false);
  }
}
