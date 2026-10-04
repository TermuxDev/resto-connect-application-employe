import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/configuration.dart';
import '../../config/theme.dart';
import '../../domaine/modeles.dart';
import '../../domaine/verification.dart';
import '../../etat/etat_terminal.dart';
import '../composants/confirmation_repas.dart';
import '../composants/elements.dart';
import '../composants/photo_etudiant.dart';
import '../composants/resultat_scan.dart';
import '../sons.dart';

/// Pendant le service : scan → vérification → validation par l'employé → résultat plein écran.
/// Le bouton « Menu » ramène à l'accueil sans terminer le service.
class EcranService extends StatefulWidget {
  const EcranService({super.key, required this.etat, required this.sons});

  final EtatTerminal etat;
  final Sons sons;

  @override
  State<EcranService> createState() => _EcranServiceState();
}

class _EcranServiceState extends State<EcranService> {
  final _camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);

  /// Étudiant qui a droit au repas, en attente de la validation de l'employé.
  Verdict? _aValider;

  /// Résultat affiché en plein écran (repas validé, ou refus).
  Verdict? _resultat;

  /// Dernier repas validé, rappelé en bas de l'écran.
  Verdict? _dernierServi;

  String? _dernierQr;
  DateTime _finAffichage = DateTime(2000);
  bool _enCours = false;

  bool get _occupe => _enCours || _aValider != null || _resultat != null;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _surDetection(BarcodeCapture capture) async {
    final qr = capture.barcodes.firstOrNull?.rawValue;
    if (qr == null || _occupe) return;
    // La caméra relit la même carte plusieurs fois par seconde : on l'ignore quelques secondes.
    if (qr == _dernierQr &&
        DateTime.now().difference(_finAffichage) < Configuration.antiRebond) {
      return;
    }

    setState(() => _enCours = true);
    _dernierQr = qr;
    final verdict = await widget.etat.verifierQr(qr);
    if (!verdict.accepte) await widget.sons.jouer(accepte: false);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      if (verdict.accepte) {
        _aValider = verdict;
      } else {
        _resultat = verdict;
      }
    });
  }

  Future<void> _valider() async {
    setState(() => _enCours = true);
    final resultat = await widget.etat.validerRepas(_aValider!);
    await widget.sons.jouer(accepte: resultat.accepte);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _aValider = null;
      _resultat = resultat;
      if (resultat.accepte) _dernierServi = resultat;
    });
  }

  void _annuler() => _reprendre(() => _aValider = null);

  void _fermerResultat() => _reprendre(() => _resultat = null);

  void _reprendre(VoidCallback changement) {
    _finAffichage = DateTime.now();
    setState(changement);
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    final service = etat.service!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _surDetection,
            errorBuilder: (context, erreur) => _ErreurCamera(erreur: erreur),
          ),
          const _CadreDeVisee(),

          // En haut : retour au menu, créneau, lampe.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: etat.retourMenu,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Menu'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Pastille(
                        service.creneau == Creneau.libre
                            ? 'Service des externes'
                            : 'Service du ${service.creneau.libelle}',
                        sombre: true,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Lampe',
                    onPressed: _camera.toggleTorch,
                    icon: const Icon(Icons.flashlight_on_rounded),
                  ),
                ],
              ),
            ),
          ),

          // En bas : dernier repas validé et compteur.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: Couleurs.fond,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DernierRepas(verdict: _dernierServi),
                  const SizedBox(height: 12),
                  Carte(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${etat.servisDuService}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'repas servis pendant ce service',
                            style: TextStyle(color: Couleurs.discret),
                          ),
                        ),
                        if (_enCours)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_aValider != null)
            ConfirmationRepas(
              verdict: _aValider!,
              enCours: _enCours,
              surValidation: _valider,
              surAnnulation: _annuler,
            ),
          if (_resultat != null)
            ResultatScan(verdict: _resultat!, surFin: _fermerResultat),
        ],
      ),
    );
  }
}

class _DernierRepas extends StatelessWidget {
  const _DernierRepas({required this.verdict});

  final Verdict? verdict;

  @override
  Widget build(BuildContext context) {
    final etudiant = verdict?.etudiant;
    if (etudiant == null) {
      return const Carte(
        child: Row(
          children: [
            Icon(Icons.qr_code_2_rounded, size: 40, color: Couleurs.vert),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Présentez la carte ou le téléphone de l\'étudiant devant la caméra.',
              ),
            ),
          ],
        ),
      );
    }
    return Carte(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          PhotoEtudiant(etudiant: etudiant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etudiant.nomComplet,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  verdict!.detail ?? 'Servi',
                  style: const TextStyle(color: Couleurs.vert),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Couleurs.vert,
            size: 30,
          ),
        ],
      ),
    );
  }
}

/// Cadre de visée aux coins arrondis, au centre de l'image.
class _CadreDeVisee extends StatelessWidget {
  const _CadreDeVisee();

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -.3),
    child: Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 4),
        borderRadius: BorderRadius.circular(32),
      ),
    ),
  );
}

class _ErreurCamera extends StatelessWidget {
  const _ErreurCamera({required this.erreur});

  final MobileScannerException erreur;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        erreur.errorCode == MobileScannerErrorCode.permissionDenied
            ? 'Autorisez l\'accès à la caméra dans les réglages du téléphone pour scanner les QR.'
            : 'La caméra ne répond pas. Revenez au menu puis reprenez le scan.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    ),
  );
}
