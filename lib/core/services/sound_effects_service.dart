import 'package:audioplayers/audioplayers.dart';

/// Short, app-wide UI sound effects.
class SoundEffectsService {
  static final _messagePlayer = AudioPlayer();
  static final _incomingOrderPlayer = AudioPlayer();
  static final _completedOrderPlayer = AudioPlayer();
  static final _playedMessageEvents = <String>{};

  static Future<void> playNewMessage({String? eventKey}) {
    if (eventKey != null && !_playedMessageEvents.add(eventKey)) {
      return Future<void>.value();
    }
    if (_playedMessageEvents.length > 100) {
      _playedMessageEvents.remove(_playedMessageEvents.first);
    }
    return _play(_messagePlayer, 'audio/message.mp3');
  }

  static Future<void> playIncomingOrder() =>
      _play(_incomingOrderPlayer, 'audio/incoming-orders.mp3');

  static Future<void> playCompletedDelivery() =>
      _play(_completedOrderPlayer, 'audio/complete-delivery.mp3');

  static Future<void> _play(AudioPlayer player, String asset) async {
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.8);
    } catch (_) {
      // Audio is an enhancement; playback failures must not interrupt app actions.
    }
  }
}
