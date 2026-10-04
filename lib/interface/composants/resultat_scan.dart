/// Résultat d'un scan en plein écran : la couleur envahit l'écran depuis le centre, puis l'icône apparaît.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/configuration.dart';
import '../../config/theme.dart';
import '../../domaine/modeles.dart';
import '../../domaine/verification.dart';
import 'photo_etudiant.dart';

class ResultatScan extends StatefulWidget {
  const ResultatScan({super.key, required this.verdict, required this.surFin});

  final Verdict verdict;
  final VoidCallback surFin;

  @override
  State<ResultatScan> createState() => _ResultatScanState();
}

class _ResultatScanState extends State<ResultatScan>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  late final _remplissage = CurvedAnimation(
    parent: _animation,
    curve: const Interval(0, .55, curve: Curves.easeOutCubic),
  );
  late final _icone = CurvedAnimation(
    parent: _animation,
    curve: const Interval(.35, 1, curve: Curves.elasticOut),
  );
  late final _contenu = CurvedAnimation(
    parent: _animation,
    curve: const Interval(.45, 1, curve: Curves.easeOut),
  );
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    final duree = widget.verdict.accepte
        ? Configuration.dureeResultatAccepte
        : Configuration.dureeResultatRefuse;
    _minuteur = Timer(duree, widget.surFin);
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verdict = widget.verdict;
    final accepte = verdict.accepte;
    final etudiant = verdict.etudiant;
    final degrade = accepte
        ? Couleurs.degrade
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Couleurs.danger, Couleurs.dangerFonce],
          );

    // Surface Material transparente : le résultat garde son style de texte quel que soit l'écran parent.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: widget.surFin,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => ClipPath(
            clipper: _Cercle(_remplissage.value),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: degrade),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Spacer(),
                      Transform.scale(
                        scale: _icone.value,
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            accepte ? Icons.check_rounded : Icons.close_rounded,
                            size: 92,
                            color: accepte ? Couleurs.vert : Couleurs.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _contenu.value,
                        child: Column(
                          children: [
                            Text(
                              accepte
                                  ? 'Bon appétit !'
                                  : verdict.motif!.libelle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (verdict.detail != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                verdict.detail!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .85),
                                  fontSize: 18,
                                ),
                              ),
                            ],
                            if (etudiant != null) ...[
                              const SizedBox(height: 32),
                              _CarteEtudiant(etudiant: etudiant),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Touchez l\'écran pour continuer',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteEtudiant extends StatelessWidget {
  const _CarteEtudiant({required this.etudiant});

  final Etudiant etudiant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhotoEtudiant(etudiant: etudiant, taille: 84),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              etudiant.nomComplet,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cercle centré dont le rayon grandit jusqu'à couvrir tout l'écran.
class _Cercle extends CustomClipper<Path> {
  _Cercle(this.progression);
  final double progression;

  @override
  Path getClip(Size taille) {
    final rayon =
        sqrt(taille.width * taille.width + taille.height * taille.height) /
        2 *
        progression;
    return Path()..addOval(
      Rect.fromCircle(center: taille.center(Offset.zero), radius: rayon),
    );
  }

  @override
  bool shouldReclip(_Cercle ancien) => ancien.progression != progression;
}
