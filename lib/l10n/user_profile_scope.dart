import 'package:flutter/widgets.dart';

import 'user_profile_controller.dart';

/// InheritedWidget that exposes the [UserProfileController] down the
/// widget tree. Mirrors the [LocaleScope] / [ThemeScope] pattern.
class UserProfileScope extends InheritedNotifier<UserProfileController> {
  const UserProfileScope({
    super.key,
    required UserProfileController controller,
    required super.child,
  }) : super(notifier: controller);

  static UserProfileController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<UserProfileScope>();
    assert(
      scope != null,
      'UserProfileScope.of() called with a context that does not '
      'contain a UserProfileScope ancestor.',
    );
    return scope!.notifier!;
  }

  /// Same as [of] but does not establish a dependency, useful for
  /// callbacks that shouldn't rebuild the consumer.
  static UserProfileController read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<UserProfileScope>();
    assert(scope != null, 'UserProfileScope is missing from the tree.');
    return scope!.notifier!;
  }
}
