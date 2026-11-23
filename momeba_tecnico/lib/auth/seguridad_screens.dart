import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../tema.dart';

/// Marco común de las pantallas de verificación en dos pasos.
class _Marco extends ConsumerWidget {
  const _Marco({required this.titulo, required this.hijos});
  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Momeba.fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE1E3EC)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                const LogoMomeba(alto: 56),
                const SizedBox(height: 14),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: Momeba.texto),
                  SizedBox(width: 6),
                  Text('Verificación en dos pasos', style: TextStyle(color: Momeba.texto, fontSize: 12.5)),
                ]),
                const SizedBox(height: 10),
                Text(titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Momeba.indigo)),
                const SizedBox(height: 12),
                ...hijos,
                const SizedBox(height: 6),
                TextButton(onPressed: () => cerrarSesionCompleta(ref), child: const Text('Cerrar sesión')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo para el código de 6 dígitos; envía solo al completar los 6.
class _CampoCodigo extends StatelessWidget {
  const _CampoCodigo({super.key, required this.ctrl, required this.onCompleto, this.respaldo = false});
  final TextEditingController ctrl;
  final ValueChanged<String> onCompleto;
  final bool respaldo;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: respaldo ? TextInputType.text : TextInputType.number,
      textCapitalization: respaldo ? TextCapitalization.characters : TextCapitalization.none,
      maxLength: respaldo ? 11 : 6,
      autofillHints: respaldo ? null : const [AutofillHints.oneTimeCode],
      inputFormatters: respaldo ? null : [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(fontSize: respaldo ? 20 : 28, letterSpacing: respaldo ? 2 : 10, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        counterText: '',
        hintText: respaldo ? 'XXXXX-XXXXX' : '000000',
      ),
      onChanged: (v) {
        if (!respaldo && v.length == 6) onCompleto(v);
      },
      onSubmitted: onCompleto,
    );
  }
}

/* ================= Alta de Google Authenticator ================= */

class AltaAutenticadorScreen extends ConsumerStatefulWidget {
  const AltaAutenticadorScreen({super.key, required this.alta, required this.correo});
  final AltaAutenticador alta;
  final String correo;

  @override
  ConsumerState<AltaAutenticadorScreen> createState() => _AltaAutenticadorScreenState();
}

class _AltaAutenticadorScreenState extends ConsumerState<AltaAutenticadorScreen> {
  final _ctrl = TextEditingController();
  bool _enviando = false;
  String? _error;

  String get _claveBonita => widget.alta.secreto.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();

  Future<void> _abrirAutenticador() async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(widget.alta.uri), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Instala Google Authenticator desde Play Store o escribe la clave a mano.')));
      try {
        await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2'),
            mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _confirmar(String codigo) async {
    if (_enviando) return;
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _error = 'Escribe los 6 dígitos que muestra la app.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final err = await ref.read(seguridadProvider.notifier).confirmarAlta(codigo);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = err;
      if (err != null) _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Marco(titulo: 'Protege tu cuenta', hijos: [
      const Text(
        'Además de tu contraseña, cada vez que entres te pediremos un código de Google Authenticator.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Momeba.texto, fontSize: 13.5),
      ),
      const SizedBox(height: 16),
      const Text('1. Instala Google Authenticator en este celular.', style: TextStyle(fontSize: 13.5)),
      const SizedBox(height: 6),
      const Text('2. Toca el botón para agregar tu cuenta de Grupo Momeba:', style: TextStyle(fontSize: 13.5)),
      const SizedBox(height: 8),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Momeba.indigo, padding: const EdgeInsets.symmetric(vertical: 13)),
        onPressed: _abrirAutenticador,
        icon: const Icon(Icons.add_moderator_outlined),
        label: const Text('Agregar a Google Authenticator'),
      ),
      const SizedBox(height: 8),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('¿No se abrió? Escribe la clave a mano', style: TextStyle(fontSize: 13, color: Momeba.turquesaOscuro)),
        children: [
          SelectableText(_claveBonita, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Cuenta: ${widget.correo} · Tipo: basada en tiempo', style: const TextStyle(fontSize: 12, color: Momeba.texto)),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.alta.secreto));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clave copiada')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar clave'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text('3. Regresa aquí y escribe el código de 6 dígitos:', style: TextStyle(fontSize: 13.5)),
      const SizedBox(height: 8),
      _CampoCodigo(ctrl: _ctrl, onCompleto: _confirmar),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB42318))),
      ],
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Momeba.turquesa, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: _enviando ? null : () => _confirmar(_ctrl.text.trim()),
        child: Text(_enviando ? 'Verificando…' : 'Activar y entrar'),
      ),
    ]);
  }
}

/* ================= Códigos de respaldo ================= */

class CodigosRespaldoScreen extends ConsumerStatefulWidget {
  const CodigosRespaldoScreen({super.key, required this.codigos, required this.correo});
  final List<String> codigos;
  final String correo;

  @override
  ConsumerState<CodigosRespaldoScreen> createState() => _CodigosRespaldoScreenState();
}

class _CodigosRespaldoScreenState extends ConsumerState<CodigosRespaldoScreen> {
  bool _guardados = false;

  String get _texto =>
      'Grupo Momeba · códigos de respaldo de ${widget.correo}\nCada código sirve una sola vez.\n\n${widget.codigos.join('\n')}\n';

  Future<void> _compartir() async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/momeba-codigos-respaldo.txt');
      await f.writeAsString(_texto);
      await Share.shareXFiles([XFile(f.path, mimeType: 'text/plain')], text: 'Códigos de respaldo Grupo Momeba');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return _Marco(titulo: 'Guarda tus códigos de respaldo', hijos: [
      const Text(
        'Si pierdes o cambias de celular, cada código te deja entrar una sola vez. Guárdalos fuera del celular '
        '(apúntalos o mándatelos por correo). No se volverán a mostrar.',
        style: TextStyle(color: Momeba.texto, fontSize: 13.5),
      ),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.4,
        children: widget.codigos
            .map((c) => Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Momeba.fondo,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE1E3EC)),
                  ),
                  child: SelectableText(c, style: const TextStyle(fontSize: 15, letterSpacing: 1, fontWeight: FontWeight.w600)),
                ))
            .toList(),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _texto));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Códigos copiados')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(onPressed: _compartir, icon: const Icon(Icons.share, size: 16), label: const Text('Guardar')),
        ),
      ]),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _guardados,
        onChanged: (v) => setState(() => _guardados = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Ya guardé mis códigos', style: TextStyle(fontSize: 14)),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Momeba.turquesa, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: _guardados ? () => ref.read(seguridadProvider.notifier).terminarRespaldo() : null,
        child: const Text('Entrar a la app'),
      ),
    ]);
  }
}

/* ================= Código al entrar ================= */

class CodigoScreen extends ConsumerStatefulWidget {
  const CodigoScreen({super.key, this.aviso});
  final String? aviso;

  @override
  ConsumerState<CodigoScreen> createState() => _CodigoScreenState();
}

class _CodigoScreenState extends ConsumerState<CodigoScreen> {
  final _ctrl = TextEditingController();
  bool _respaldo = false;
  bool _enviando = false;
  String? _error;

  Future<void> _verificar(String codigo) async {
    if (_enviando) return;
    final c = codigo.trim();
    if (!_respaldo && !RegExp(r'^\d{6}$').hasMatch(c)) {
      setState(() => _error = 'Escribe los 6 dígitos que muestra la app.');
      return;
    }
    if (_respaldo && c.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length != 10) {
      setState(() => _error = 'El código de respaldo tiene 10 caracteres, por ejemplo 9B4A5-4D057.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final (err, restantes) = await ref.read(seguridadProvider.notifier).verificar(c);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = err;
      if (err != null) _ctrl.clear();
    });
    if (err == null && restantes != null) {
      messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Usaste un código de respaldo. Te quedan $restantes. '
              'Pide al Super Admin que reinicie tu verificación para tu celular nuevo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Marco(titulo: _respaldo ? 'Código de respaldo' : 'Escribe tu código', hijos: [
      if (widget.aviso != null) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFEAF0FB), borderRadius: BorderRadius.circular(10)),
          child: Text(widget.aviso!, style: const TextStyle(fontSize: 13, color: Color(0xFF2A4FB8))),
        ),
        const SizedBox(height: 12),
      ],
      Text(
        _respaldo
            ? 'Escribe uno de tus códigos de respaldo.'
            : 'Abre Google Authenticator y escribe el código de 6 dígitos de Grupo Momeba.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Momeba.texto, fontSize: 13.5),
      ),
      const SizedBox(height: 12),
      _CampoCodigo(key: ValueKey(_respaldo), ctrl: _ctrl, onCompleto: _verificar, respaldo: _respaldo),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB42318))),
      ],
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Momeba.turquesa, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: _enviando ? null : () => _verificar(_ctrl.text),
        child: Text(_enviando ? 'Verificando…' : 'Verificar'),
      ),
      TextButton(
        onPressed: () => setState(() {
          _respaldo = !_respaldo;
          _ctrl.clear();
          _error = null;
        }),
        child: Text(_respaldo ? 'Usar el código de la app' : 'Perdí mi celular: usar un código de respaldo'),
      ),
    ]);
  }
}
