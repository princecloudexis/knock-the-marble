enum Player {
  black,
  white,
  none;

  Player get opponent {
    switch (this) {
      case Player.black:
        return Player.white;
      case Player.white:
        return Player.black;
      case Player.none:
        return Player.none;
    }
  }

  String get displayName {
    switch (this) {
      case Player.black:
        return 'Black';
      case Player.white:
        return 'White';
      case Player.none:
        return '';
    }
  }

  String get symbol {
    switch (this) {
      case Player.black:
        return '●';
      case Player.white:
        return '○';
      case Player.none:
        return '';
    }
  }
}