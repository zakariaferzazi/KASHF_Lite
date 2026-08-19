import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_storage.dart';

/// Re-export so callers that already `import
/// '../l10n/user_profile_scope.dart';` keep getting the
/// [UserProfile] type.
export '../models/user_profile.dart' show UserProfile;

/// InheritedWidget that publishes the current [UserProfile] to
/// the widget tree. Pages that need to read or mutate the
/// profile grab the controller via [UserProfileScope.of] and
/// call its setters; the controller notifies listeners on every
/// successful update.
class UserProfileScope extends StatefulWidget {
  const UserProfileScope({super.key, required this.child, this.controller});

  /// Widget below this widget that should see the same profile.
  final Widget child;

  /// Optional external controller. When null, the scope creates
  /// its own controller so screens reached without an explicit
  /// `UserProfileScope` ancestor still get a working profile.
  final UserProfileController? controller;

  /// Resolves the controller for the calling widget. Throws if
  /// no scope is in scope (which is a programmer error).
  static UserProfileController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_UserProfileInherited>();
    assert(scope != null, 'UserProfileScope.of() called without an ancestor');
    return scope!.controller;
  }

  /// Same as [UserProfileScope.of] but does not register the
  /// calling widget as a dependent — useful inside callbacks
  /// that fire once (e.g. button handlers).
  static UserProfileController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<_UserProfileInherited>();
    final widget = element?.widget as _UserProfileInherited?;
    return widget!.controller;
  }

  @override
  State<UserProfileScope> createState() => _UserProfileScopeState();
}

class _UserProfileScopeState extends State<UserProfileScope> {
  late final UserProfileController _controller =
      widget.controller ?? UserProfileController();

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UserProfileInherited(controller: _controller, child: widget.child);
  }
}

class _UserProfileInherited extends InheritedWidget {
  const _UserProfileInherited({required this.controller, required super.child});

  final UserProfileController controller;

  @override
  bool updateShouldNotify(_UserProfileInherited old) =>
      controller != old.controller;
}

/// Read/write handle on the user's profile. Settlers persist
/// immediately through [UserProfileStorage] and then rebuild any
/// `UserProfileScope.of(context)` listeners.
class UserProfileController extends ChangeNotifier {
  UserProfileController({UserProfileStorage? storage})
    : _storage = storage ?? UserProfileStorage.instance;

  final UserProfileStorage _storage;
  UserProfile _profile = const UserProfile();

  UserProfile get profile => _profile;

  /// Hydrates from storage on first read. Subsequent reads are
  /// served from the in-memory cache. The first load happens
  /// asynchronously, so listeners may see an empty profile for
  /// one frame until [load] completes — pages handle this by
  /// `didChangeDependencies` initialisation.
  Future<void> load() async {
    final loaded = await _storage.read();
    if (loaded.name != _profile.name ||
        loaded.email != _profile.email ||
        loaded.avatarColor != _profile.avatarColor ||
        loaded.avatarImagePath != _profile.avatarImagePath) {
      _profile = loaded;
      notifyListeners();
    }
  }

  Future<void> setName(String name) async {
    _profile = _profile.copyWith(name: name.trim());
    await _storage.write(_profile);
    notifyListeners();
  }

  Future<void> setEmail(String email) async {
    _profile = _profile.copyWith(email: email.trim());
    await _storage.write(_profile);
    notifyListeners();
  }

  Future<void> setAvatarImage(String path) async {
    _profile = _profile.copyWith(avatarImagePath: path);
    await _storage.write(_profile);
    notifyListeners();
  }

  Future<void> setAvatarColor(int color) async {
    _profile = _profile.copyWith(avatarColor: color, clearAvatarImage: true);
    await _storage.write(_profile);
    notifyListeners();
  }

  Future<void> resetAvatar() async {
    _profile = _profile.copyWith(clearAvatarImage: true);
    await _storage.write(_profile);
    notifyListeners();
  }
}

/// The avatar circle used by Settings → Personal Info and any
/// other surface that wants to show "who's signed in". Falls
/// back to a coloured disc with the user's initial when no
/// image is set.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    this.size = 48,
    this.borderColor,
    this.borderWidth = 0,
  });

  final UserProfile profile;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final hasImage = (profile.avatarImagePath ?? '').isNotEmpty;
    final initialsStyle = TextStyle(
      color: Colors.white,
      fontSize: size * 0.42,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
    );
    final core = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image(
                image: AssetImage(profile.avatarImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => _Initial(
                  initial: profile.initial,
                  color: Color(profile.avatarColor),
                  textStyle: initialsStyle,
                ),
              )
            : _Initial(
                initial: profile.initial,
                color: Color(profile.avatarColor),
                textStyle: initialsStyle,
              ),
      ),
    );
    if (borderColor == null || borderWidth <= 0) return core;
    return Container(
      width: size + borderWidth * 2,
      height: size + borderWidth * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      child: Padding(padding: EdgeInsets.all(borderWidth), child: core),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({
    required this.initial,
    required this.color,
    required this.textStyle,
  });

  final String initial;
  final Color color;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(initial, style: textStyle),
    );
  }
}
