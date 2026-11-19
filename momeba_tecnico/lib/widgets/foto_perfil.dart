import 'dart:convert';

import 'package:flutter/material.dart';

/// La foto puede venir como liga (subida desde la app) o como imagen
/// pequeña incrustada "data:image/jpeg;base64,…" (subida desde el panel web).
ImageProvider? fotoProvider(String? foto) {
  if (foto == null || foto.isEmpty) return null;
  if (foto.startsWith('data:')) {
    final i = foto.indexOf(',');
    if (i < 0) return null;
    try {
      return MemoryImage(base64Decode(foto.substring(i + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(foto);
}
