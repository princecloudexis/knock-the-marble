class Hex {
  final int q, r;
  int get s => -q - r;

  const Hex(this.q, this.r);

  Hex operator +(Hex other) => Hex(q + other.q, r + other.r);
  Hex operator -(Hex other) => Hex(q - other.q, r - other.r);

  int distanceTo(Hex other) {
    final dq = (q - other.q).abs();
    final dr = (r - other.r).abs();
    final ds = (s - other.s).abs();
    return (dq + dr + ds) ~/ 2;
  } 

  bool get isOnBoard {
    return q.abs() <= 4 && r.abs() <= 4 && s.abs() <= 4;
  }

  List<Hex> get neighbors => directions.map((d) => this + d).toList();

  static const List<Hex> directions = [
    Hex(1, 0),
    Hex(1, -1),
    Hex(0, -1),
    Hex(-1, 0),
    Hex(-1, 1),
    Hex(0, 1),
  ];

  @override
  bool operator ==(Object other) =>
      other is Hex && q == other.q && r == other.r;

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => 'Hex($q, $r)';
}