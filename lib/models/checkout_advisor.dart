class CheckoutAdvisor {
  static const Map<int, String> doubleOutCheckouts = {
    170: 'T20 · T20 · Bull',
    167: 'T20 · T19 · Bull',
    164: 'T20 · T18 · Bull',
    161: 'T20 · T17 · Bull',
    160: 'T20 · T20 · D20',
    158: 'T20 · T20 · D19',
    157: 'T20 · T19 · D20',
    156: 'T20 · T20 · D18',
    155: 'T20 · T19 · D19',
    154: 'T20 · T18 · D20',
    153: 'T20 · T19 · D18',
    152: 'T20 · T20 · D16',
    151: 'T20 · T17 · D20',
    150: 'T20 · T18 · D18',
    149: 'T20 · T19 · D16',
    148: 'T20 · T20 · D14',
    147: 'T20 · T17 · D18',
    146: 'T20 · T18 · D16',
    145: 'T20 · T15 · D20',
    144: 'T20 · T20 · D12',
    143: 'T20 · T17 · D16',
    142: 'T20 · T14 · D20',
    141: 'T20 · T19 · D12',
    140: 'T20 · T20 · D10',
    139: 'T19 · T14 · D20',
    138: 'T20 · T18 · D12',
    137: 'T20 · T19 · D10',
    136: 'T20 · T20 · D8',
    135: 'T20 · T17 · D12',
    134: 'T20 · T14 · D16',
    133: 'T20 · T19 · D8',
    132: 'T20 · T16 · D12',
    131: 'T20 · T13 · D16',
    130: 'T20 · T20 · D5',
    129: 'T19 · T16 · D12',
    128: 'T18 · T18 · D10',
    127: 'T20 · T17 · D8',
    126: 'T19 · T19 · D6',
    125: 'T18 · T13 · D16',
    124: 'T20 · T16 · D8',
    123: 'T19 · T16 · D9',
    122: 'T18 · T18 · D7',
    121: 'T20 · T11 · D14',
    120: 'T20 · S20 · D20',
    119: 'T19 · T12 · D13',
    118: 'T20 · S18 · D20',
    117: 'T20 · S17 · D20',
    116: 'T20 · S16 · D20',
    115: 'T20 · S15 · D20',
    114: 'T20 · S14 · D20',
    113: 'T20 · S13 · D20',
    112: 'T20 · S12 · D20',
    111: 'T20 · S19 · D16',
    110: 'T20 · S18 · D16',
    109: 'T20 · S17 · D16',
    108: 'T20 · S16 · D16',
    107: 'T19 · S18 · D16',
    106: 'T20 · S10 · D18',
    105: 'T20 · S13 · D16',
    104: 'T18 · S18 · D16',
    103: 'T19 · S10 · D18',
    102: 'T20 · S10 · D16',
    101: 'T17 · S18 · D16',
    100: 'T20 · D20',
    99: 'T19 · S10 · D16',
    98: 'T20 · D19',
    97: 'T19 · D20',
    96: 'T20 · D18',
    95: 'T19 · D19',
    94: 'T18 · D20',
    93: 'T19 · D18',
    92: 'T20 · D16',
    91: 'T17 · D20',
    90: 'T18 · D18',
    89: 'T19 · D16',
    88: 'T16 · D20',
    87: 'T17 · D18',
    86: 'T18 · D16',
    85: 'T15 · D20',
    84: 'T20 · D12',
    83: 'T17 · D16',
    82: 'Bull · D16',
    81: 'T19 · D12',
    80: 'T20 · D10',
    79: 'T19 · D11',
    78: 'T18 · D12',
    77: 'T19 · D10',
    76: 'T20 · D8',
    75: 'T17 · D12',
    74: 'T14 · D16',
    73: 'T19 · D8',
    72: 'T16 · D12',
    71: 'T13 · D16',
    70: 'T18 · D8',
    69: 'T19 · D6',
    68: 'T20 · D4',
    67: 'T17 · D8',
    66: 'T10 · D18',
    65: 'T19 · D4',
    64: 'T16 · D8',
    63: 'T13 · D12',
    62: 'T10 · D16',
    61: 'T15 · D8',
    60: 'S20 · D20',
    59: 'S19 · D20',
    58: 'S18 · D20',
    57: 'S17 · D20',
    56: 'S16 · D20',
    55: 'S15 · D20',
    54: 'S14 · D20',
    53: 'S13 · D20',
    52: 'S12 · D20',
    51: 'S19 · D16',
    50: 'Bull',
    49: 'S17 · D16',
    48: 'S16 · D16',
    47: 'S15 · D16',
    46: 'S14 · D16',
    45: 'S13 · D16',
    44: 'S12 · D16',
    43: 'S11 · D16',
    42: 'S10 · D16',
    41: 'S9 · D16',
    40: 'D20',
    39: 'S7 · D16',
    38: 'D19',
    37: 'S5 · D16',
    36: 'D18',
    35: 'S3 · D16',
    34: 'D17',
    33: 'S1 · D16',
    32: 'D16',
    31: 'S15 · D8',
    30: 'D15',
    29: 'S13 · D8',
    28: 'D14',
    27: 'S11 · D8',
    26: 'D13',
    25: 'S9 · D8',
    24: 'D12',
    23: 'S7 · D8',
    22: 'D11',
    21: 'S5 · D8',
    20: 'D10',
    19: 'S3 · D8',
    18: 'D9',
    17: 'S1 · D8',
    16: 'D8',
    15: 'S7 · D4',
    14: 'D7',
    13: 'S5 · D4',
    12: 'D6',
    11: 'S3 · D4',
    10: 'D5',
    9: 'S1 · D4',
    8: 'D4',
    7: 'S3 · D2',
    6: 'D3',
    5: 'S1 · D2',
    4: 'D2',
    3: 'S1 · D1',
    2: 'D1',
  };

  static String getCheckoutText({
    required int score,
    required bool doubleOut,
    required bool doubleIn,
    required bool playerIsIn,
    required bool matchFinished,
  }) {
    if (matchFinished) {
      return 'Match beendet.';
    }

    if (doubleIn && !playerIsIn) {
      return 'Erst mit Double oder Bull ins Spiel kommen.';
    }

    if (score <= 0) {
      return 'Kein Checkout nötig.';
    }

    if (doubleOut) {
      if (score > 170) {
        return 'Noch kein direkter 3-Dart-Checkout möglich.';
      }

      if (score == 1) {
        return 'Rest 1 ist bei Double Out nicht checkbar.';
      }

      return doubleOutCheckouts[score] ?? 'Kein direkter Checkout.';
    }

    return _calculateStraightOutCheckout(score);
  }

  static String _calculateStraightOutCheckout(int score) {
    if (score > 180) {
      return 'Noch kein direkter 3-Dart-Checkout möglich.';
    }

    final List<_CheckoutDart> darts = _allDarts();

    for (final dart in darts) {
      if (dart.score == score) {
        return dart.label;
      }
    }

    for (final first in darts) {
      for (final second in darts) {
        if (first.score + second.score == score) {
          return '${first.label} · ${second.label}';
        }
      }
    }

    for (final first in darts) {
      for (final second in darts) {
        for (final third in darts) {
          if (first.score + second.score + third.score == score) {
            return '${first.label} · ${second.label} · ${third.label}';
          }
        }
      }
    }

    return 'Kein direkter Checkout.';
  }

  static List<_CheckoutDart> _allDarts() {
    final List<_CheckoutDart> darts = [];

    for (int number = 20; number >= 1; number--) {
      darts.add(
        _CheckoutDart(
          label: 'T$number',
          score: number * 3,
        ),
      );
    }

    darts.add(
      const _CheckoutDart(
        label: 'Bull',
        score: 50,
      ),
    );

    for (int number = 20; number >= 1; number--) {
      darts.add(
        _CheckoutDart(
          label: 'D$number',
          score: number * 2,
        ),
      );
    }

    darts.add(
      const _CheckoutDart(
        label: 'Outer',
        score: 25,
      ),
    );

    for (int number = 20; number >= 1; number--) {
      darts.add(
        _CheckoutDart(
          label: 'S$number',
          score: number,
        ),
      );
    }

    darts.sort((a, b) => b.score.compareTo(a.score));
    return darts;
  }
}

class _CheckoutDart {
  final String label;
  final int score;

  const _CheckoutDart({
    required this.label,
    required this.score,
  });
}