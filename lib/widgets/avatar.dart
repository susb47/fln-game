import 'package:flutter/material.dart';

/// Player pictures: an emoji, or one of the children ("kid:rafi").
const kidAvatarPrefix = 'kid:';

/// The children's faces offered as player pictures, in the same order as the trainers.
const kidAvatars = [
  'kid:rafi',
  'kid:mitu',
  'kid:sakib',
  'kid:tisha',
  'kid:arif',
  'kid:rumi',
  'kid:joy',
  'kid:mim',
  'kid:raju',
];

bool isKidAvatar(String a) => a.startsWith(kidAvatarPrefix);

/// For text such as dashboard lists: the emoji and a space, or nothing for a picture.
String avatarText(String a) => isKidAvatar(a) ? '' : '$a ';

/// Shows a player's picture at [size].
class AvatarView extends StatelessWidget {
  final String avatar;
  final double size;
  const AvatarView(this.avatar, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    if (!isKidAvatar(avatar)) {
      return Text(avatar, style: TextStyle(fontSize: size * 0.85, height: 1.1));
    }
    final id = avatar.substring(kidAvatarPrefix.length);
    return ClipOval(
      child: Image.asset(
        'assets/characters/faces/$id.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Text('🙂', style: TextStyle(fontSize: size * 0.85)),
      ),
    );
  }
}
