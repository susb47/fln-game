/// Bangla text helpers.
library;

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// Writes [n] with Bangla digits, e.g. 12 -> "১২".
String bn(int n) => n.toString().split('').map((c) {
  final d = int.tryParse(c);
  return d == null ? c : _bnDigits[d];
}).join();

/// Reads a number typed with Bangla or English digits.
int? parseNumber(String s) {
  var t = s.trim();
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(_bnDigits[i], '$i');
  }
  return int.tryParse(t);
}

/// Minutes, e.g. 125 seconds -> "২ মিনিট".
String bnMinutes(int seconds) => '${bn((seconds / 60).round())} মিনিট';

String bnPercent(double share) => '${bn((share * 100).round())}%';

/// Short date, e.g. "১২/১০".
String bnDate(DateTime d) => '${bn(d.day)}/${bn(d.month)}';

/// Short words of praise, picked at random after a correct answer.
const praise = ['সাবাশ!', 'দারুণ!', 'খুব ভালো!', 'চমৎকার!', 'ঠিক হয়েছে!'];

/// Gentle nudge after a wrong answer. Never scolding.
const tryAgain = 'আবার চেষ্টা করো';

/// Pictures a child can pick for their profile.
const avatars = ['🐯', '🐘', '🦜', '🐟', '🐢', '🐰', '🦁', '🐼', '🐸', '🐝', '🦋', '🐱'];
