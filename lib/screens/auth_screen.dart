import 'package:flutter/material.dart';

import '../bn.dart';
import '../brand.dart';
import '../dashboards/teacher_dashboard.dart';
import '../game_scope.dart';
import '../widgets/avatar.dart';
import '../widgets/trainer_picker.dart';
import '../widgets/adult_gate.dart';

/// "Who is playing?" Children tap their own picture. No passwords.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final store = scope.store;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D6),
      // The button stays in view while the child scrolls through pictures and trainers.
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(Brand.appIcon, width: 120, height: 120),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              Brand.appName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF0A4F7A)),
            ),
            const Text(
              Brand.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Color(0xFFE07000)),
            ),
            const SizedBox(height: 16),
            const Text('কে খেলবে?', textAlign: TextAlign.center, style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final p in store.profiles)
                  _PlayerCard(avatar: p.avatar, name: p.name, onTap: () => store.signIn(p)),
                _PlayerCard(
                  key: const ValueKey('new_player'),
                  avatar: '➕',
                  name: 'নতুন খেলোয়াড়',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CreateProfileScreen())),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: OutlinedButton.icon(
                key: const ValueKey('guest'),
                onPressed: store.playAsGuest,
                icon: const Text('🙂', style: TextStyle(fontSize: 24)),
                label: const Text('অতিথি হিসেবে খেলো', style: TextStyle(fontSize: 20)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'অতিথির খেলা সেভ হয় না',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  if (await askAdult(context) && context.mounted) {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const TeacherDashboard()));
                  }
                },
                icon: const Icon(Icons.insights),
                label: const Text('শিক্ষক / অভিভাবক ড্যাশবোর্ড'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              Brand.productOf,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String avatar;
  final String name;
  final VoidCallback onTap;

  const _PlayerCard({super.key, required this.avatar, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 130,
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AvatarView(avatar, size: 64),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name and picture for a new player. With [fromGuest], keeps the guest's progress.
class CreateProfileScreen extends StatefulWidget {
  final bool fromGuest;

  const CreateProfileScreen({super.key, this.fromGuest = false});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _name = TextEditingController();
  String _avatar = kidAvatars.first;
  String? _trainer;

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context).store;
    final ready = _name.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF4D6),
        title: Text(widget.fromGuest ? 'খেলা সেভ করো' : 'নতুন খেলোয়াড়'),
      ),
      // The button stays in view while the child scrolls through pictures and trainers.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const ValueKey('create'),
            onPressed: ready
                ? () {
                    if (widget.fromGuest) {
                      store.saveGuest(_name.text, _avatar, trainer: _trainer);
                    } else {
                      store.create(_name.text, _avatar, trainer: _trainer);
                    }
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                : null,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('চলো খেলি!', style: TextStyle(fontSize: 22)),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('তোমার নাম', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('name'),
              controller: _name,
              maxLength: 20,
              style: const TextStyle(fontSize: 24),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                hintText: 'যেমন: রিয়া',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('তোমার ছবি বাছো', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in [...kidAvatars, ...avatars])
                  ChoiceChip(
                    key: ValueKey('avatar_$a'),
                    label: AvatarView(a, size: 44),
                    selected: a == _avatar,
                    onSelected: (_) => setState(() => _avatar = a),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('তোমার ট্রেনার বেছে নাও', style: TextStyle(fontSize: 22)),
            const Text(
              'ট্রেনার প্রশ্ন পড়ে শোনাবে, সাহায্য করবে আর উৎসাহ দেবে।',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            TrainerPicker(selected: _trainer, onPick: (t) => setState(() => _trainer = t.id)),
          ],
        ),
      ),
    );
  }
}
