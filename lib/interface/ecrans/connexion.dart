import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domaine/adresse.dart';
import '../../etat/etat_terminal.dart';
import '../composants/elements.dart';

class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key, required this.etat});

  final EtatTerminal etat;

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _formulaire = GlobalKey<FormState>();
  late final _serveur = TextEditingController(text: widget.etat.serveur);
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _serveur.dispose();
    _telephone.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    if (!_formulaire.currentState!.validate()) return;
    final erreur = await widget.etat.connecter(
      _serveur.text,
      _telephone.text,
      _motDePasse.text,
    );
    if (mounted) setState(() => _erreur = erreur);
  }

  @override
  Widget build(BuildContext context) {
    final occupe = widget.etat.occupe;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Carte(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formulaire,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Logo()),
                    const SizedBox(height: 28),
                    const Text(
                      'Terminal de scan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Connectez-vous avec le compte du terminal fourni par le gérant.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Couleurs.discret),
                    ),
                    const SizedBox(height: 24),
                    if (_erreur != null) ...[
                      Bandeau(texte: _erreur!),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _telephone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Indiquez le téléphone du terminal.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _motDePasse,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => (v ?? '').isEmpty
                          ? 'Indiquez le mot de passe.'
                          : null,
                      onFieldSubmitted: (_) => _connecter(),
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        // Le champ reste vérifié même quand le volet est fermé.
                        maintainState: true,
                        title: const Text(
                          'Adresse du serveur',
                          style: TextStyle(
                            color: Couleurs.discret,
                            fontSize: 14,
                          ),
                        ),
                        // L'adresse réellement utilisée reste visible, volet fermé.
                        subtitle: ListenableBuilder(
                          listenable: _serveur,
                          builder: (context, _) => Text(
                            normaliserAdresse(_serveur.text) ??
                                'Adresse invalide',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        children: [
                          TextFormField(
                            controller: _serveur,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              hintText: 'http://192.168.1.20:8000',
                              helperText:
                                  "Le « http:// » est ajouté automatiquement s'il manque.",
                            ),
                            validator: (v) => normaliserAdresse(v ?? '') == null
                                ? 'Adresse invalide. Exemple : http://192.168.1.20:8000'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: occupe ? null : _connecter,
                      child: occupe
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text('Se connecter'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Version ${widget.etat.version}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Couleurs.discret,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
