/// Recorded voice clips, stitched together.
///
/// A line is played from clips when every piece of it has one; otherwise the
/// whole line falls back to text-to-speech, so a child never hears half a
/// recording and half a robot.
///
/// Pieces, tried from largest to smallest:
/// 1. the whole line, e.g. "দারুণ!"
/// 2. each sentence, e.g. "একবার গুনে দেখি!" then "দুই দল মিলিয়ে সব গুনে দেখো।"
/// 3. inside a sentence, numbers and the words between them, e.g.
///    "৮ যোগ ৫ সমান কত?" -> "৮", "যোগ", "৫", "সমান কত?".
///    A number keeps a suffix stuck to it ("৩টি"), because Bangla says it as
///    one word ("তিনটি").
///
/// Keys in clips.json are the piece's text, or "speaker|text" for a clip only
/// one character should use (for example "piku|দুই দল মিলিয়ে সব গুনে দেখো।").
/// A speaker's own clip wins over a shared one.
library;

class VoicePack {
  final Map<String, String> clips;
  const VoicePack(this.clips);

  bool get isEmpty => clips.isEmpty;

  String? _find(String speaker, String text) => clips['$speaker|$text'] ?? clips[text];

  /// The clip files to play, in order, or null when something is missing.
  List<String>? plan(String speaker, String text) {
    if (clips.isEmpty) return null;
    final whole = _find(speaker, text.trim());
    if (whole != null) return [whole];
    final files = <String>[];
    for (final sentence in sentences(text)) {
      final s = _find(speaker, sentence);
      if (s != null) {
        files.add(s);
        continue;
      }
      for (final piece in pieces(sentence)) {
        final p = _find(speaker, piece);
        if (p == null) return null;
        files.add(p);
      }
    }
    return files.isEmpty ? null : files;
  }

  static final _sentenceEnd = RegExp(r'(?<=[।!?])\s+');
  static final _number = RegExp(r'[০-৯0-9]+[^\s,।!?০-৯0-9]*');
  static final _onlyPunctuation = RegExp(r'^[\s,।!?.:;\-]*$');
  static final _edgePunctuation = RegExp(r'^[\s,]+|[\s,]+$');

  /// Splits text after । ! and ?.
  static List<String> sentences(String text) => [
    for (final s in text.trim().split(_sentenceEnd))
      if (s.trim().isNotEmpty) s.trim(),
  ];

  /// Numbers and the words around them, in order. Commas and spaces between
  /// pieces are dropped (the pause between clips stands in for them).
  static List<String> pieces(String sentence) {
    final out = <String>[];
    void words(String s) {
      final t = s.replaceAll(_edgePunctuation, '');
      if (!_onlyPunctuation.hasMatch(t)) out.add(t);
    }

    var at = 0;
    for (final m in _number.allMatches(sentence)) {
      words(sentence.substring(at, m.start));
      out.add(m.group(0)!);
      at = m.end;
    }
    words(sentence.substring(at));
    return out;
  }

  /// Every piece a line can need, for the recording script.
  static List<String> allPieces(String text) => [
    for (final s in sentences(text)) ...(_number.hasMatch(s) ? pieces(s) : [s]),
  ];
}
