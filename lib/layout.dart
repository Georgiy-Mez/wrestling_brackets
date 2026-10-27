/// Геометрия сетки — общая для экрана и PDF.
class BoxPos {
  final double x, y;
  const BoxPos(this.x, this.y);
}

/// Отрезок линии (горизонтальный или вертикальный прямоугольник).
class Seg {
  final double x, y, w, h;
  const Seg(this.x, this.y, this.w, this.h);
}

class BoutLabel {
  final double x, y;
  final int number;
  const BoutLabel(this.x, this.y, this.number);
}

class BracketGeometry {
  final int size;
  final double boxW, boxH, colGap, rowGap, pairGap, topPad;
  late final int rounds;
  late final List<List<BoxPos>> cols;
  final List<Seg> lines = [];
  final List<BoutLabel> labels = [];
  late final double width, height;

  BracketGeometry(
    this.size,
    List<String?> slots, {
    this.boxW = 170,
    this.boxH = 36,
    this.colGap = 32,
    this.rowGap = 6,
    this.pairGap = 18,
    this.topPad = 26,
  }) {
    var r = 0;
    while ((1 << r) < size) {
      r++;
    }
    rounds = r;

    final c = <List<BoxPos>>[];
    c.add([
      for (var i = 0; i < size; i++)
        BoxPos(0, topPad + i * (boxH + rowGap) + (i ~/ 2) * pairGap)
    ]);
    for (var k = 1; k <= rounds; k++) {
      final prev = c[k - 1];
      final x = k * (boxW + colGap);
      c.add([
        for (var j = 0; j < prev.length ~/ 2; j++)
          BoxPos(x, (prev[2 * j].y + prev[2 * j + 1].y) / 2)
      ]);
    }
    cols = c;

    var num = 1;
    for (var k = 1; k <= rounds; k++) {
      for (var j = 0; j < cols[k].length; j++) {
        final a = cols[k - 1][2 * j];
        final b = cols[k - 1][2 * j + 1];
        final p = cols[k][j];
        final xm = a.x + boxW + colGap / 2;
        final ay = a.y + boxH / 2, by = b.y + boxH / 2, py = p.y + boxH / 2;
        lines.add(Seg(a.x + boxW, ay, colGap / 2, 1));
        lines.add(Seg(b.x + boxW, by, colGap / 2, 1));
        lines.add(Seg(xm, ay, 1, by - ay + 1));
        lines.add(Seg(xm, py, colGap / 2, 1));
        final isBout =
            k > 1 || (slots[2 * j] != null && slots[2 * j + 1] != null);
        if (isBout) labels.add(BoutLabel(xm, py, num++));
      }
    }

    width = rounds * (boxW + colGap) + boxW;
    height = cols[0].last.y + boxH + 4;
  }
}

/// Название стадии для колонки k.
String roundTitle(int k, int rounds) {
  if (k == rounds) return 'Победитель';
  final fromEnd = rounds - 1 - k;
  if (fromEnd == 0) return 'Финал';
  return '1/${1 << fromEnd} финала';
}

/// Кто показывается в ячейке: в 1-й колонке — слот, во 2-й — прошедший без схватки.
String? shownId(int col, int idx, List<String?> slots) {
  if (col == 0) return slots[idx];
  if (col == 1) {
    final a = slots[2 * idx], b = slots[2 * idx + 1];
    if (a != null && b == null) return a;
    if (a == null && b != null) return b;
  }
  return null;
}

String shorten(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';
