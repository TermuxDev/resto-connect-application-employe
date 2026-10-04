/// Bip aigu (servi) et bip grave (refusé), accompagnés d'une vibration.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class Sons {
  final _vert = AudioPlayer();
  final _rouge = AudioPlayer();

  /// Les sons sont préchargés : le bip part sans délai au moment du scan.
  Future<void> preparer() async {
    for (final (lecteur, fichier) in [
      (_vert, 'sons/bip_vert.wav'),
      (_rouge, 'sons/bip_rouge.wav'),
    ]) {
      await lecteur.setPlayerMode(PlayerMode.lowLatency);
      await lecteur.setReleaseMode(ReleaseMode.stop);
      await lecteur.setSource(AssetSource(fichier));
    }
  }

  Future<void> jouer({required bool accepte}) async {
    final lecteur = accepte ? _vert : _rouge;
    await lecteur.stop();
    await lecteur.resume();
    await (accepte
        ? HapticFeedback.lightImpact()
        : HapticFeedback.heavyImpact());
  }

  Future<void> liberer() async {
    await _vert.dispose();
    await _rouge.dispose();
  }
}
