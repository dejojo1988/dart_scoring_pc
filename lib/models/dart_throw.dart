enum DartThrowType {
  single,
  double,
  triple,
  outer,
  bull,
  miss,
}

class DartThrow {
  final DartThrowType type;
  final int? number;

  const DartThrow({
    required this.type,
    this.number,
  });

  int get score {
    switch (type) {
      case DartThrowType.single:
        return number ?? 0;
      case DartThrowType.double:
        return (number ?? 0) * 2;
      case DartThrowType.triple:
        return (number ?? 0) * 3;
      case DartThrowType.outer:
        return 25;
      case DartThrowType.bull:
        return 50;
      case DartThrowType.miss:
        return 0;
    }
  }

  bool get isDouble {
    switch (type) {
      case DartThrowType.double:
      case DartThrowType.bull:
        return true;
      case DartThrowType.single:
      case DartThrowType.triple:
      case DartThrowType.outer:
      case DartThrowType.miss:
        return false;
    }
  }

  bool get isMiss {
    return type == DartThrowType.miss;
  }

  String get label {
    switch (type) {
      case DartThrowType.single:
        return 'S${number ?? 0}';
      case DartThrowType.double:
        return 'D${number ?? 0}';
      case DartThrowType.triple:
        return 'T${number ?? 0}';
      case DartThrowType.outer:
        return 'Outer';
      case DartThrowType.bull:
        return 'Bull';
      case DartThrowType.miss:
        return 'Miss';
    }
  }

  String get fullLabel {
    switch (type) {
      case DartThrowType.single:
        return 'Single ${number ?? 0}';
      case DartThrowType.double:
        return 'Double ${number ?? 0}';
      case DartThrowType.triple:
        return 'Triple ${number ?? 0}';
      case DartThrowType.outer:
        return 'Outer Bull';
      case DartThrowType.bull:
        return 'Bull';
      case DartThrowType.miss:
        return 'Miss';
    }
  }

  factory DartThrow.single(int number) {
    return DartThrow(
      type: DartThrowType.single,
      number: number,
    );
  }

  factory DartThrow.double(int number) {
    return DartThrow(
      type: DartThrowType.double,
      number: number,
    );
  }

  factory DartThrow.triple(int number) {
    return DartThrow(
      type: DartThrowType.triple,
      number: number,
    );
  }

  factory DartThrow.outer() {
    return const DartThrow(
      type: DartThrowType.outer,
    );
  }

  factory DartThrow.bull() {
    return const DartThrow(
      type: DartThrowType.bull,
    );
  }

  factory DartThrow.miss() {
    return const DartThrow(
      type: DartThrowType.miss,
    );
  }
}