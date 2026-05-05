import 'package:flutter/material.dart';

import '../models/dart_throw.dart';

class DartInputGrid extends StatefulWidget {
  final ValueChanged<DartThrow> onThrowSelected;
  final VoidCallback? onUndo;

  const DartInputGrid({
    super.key,
    required this.onThrowSelected,
    this.onUndo,
  });

  @override
  State<DartInputGrid> createState() => _DartInputGridState();
}

class _DartInputGridState extends State<DartInputGrid> {
  DartThrowType selectedThrowType = DartThrowType.single;

  Color get accentColor => Theme.of(context).colorScheme.primary;

  void _selectThrowType(DartThrowType throwType) {
    setState(() {
      selectedThrowType = throwType;
    });
  }

  void _submitNumber(int number) {
    final DartThrowType throwType = selectedThrowType;

    widget.onThrowSelected(
      DartThrow(
        type: throwType,
        number: number,
      ),
    );

    _resetThrowTypeToSingle();
  }

  void _submitSpecialThrow(DartThrow dartThrow) {
    widget.onThrowSelected(dartThrow);
    _resetThrowTypeToSingle();
  }

  void _resetThrowTypeToSingle() {
    if (!mounted) {
      return;
    }

    if (selectedThrowType == DartThrowType.single) {
      return;
    }

    setState(() {
      selectedThrowType = DartThrowType.single;
    });
  }

  String get selectedThrowTypeLabel {
    switch (selectedThrowType) {
      case DartThrowType.single:
        return 'Single';
      case DartThrowType.double:
        return 'Double';
      case DartThrowType.triple:
        return 'Triple';
      case DartThrowType.outer:
      case DartThrowType.bull:
      case DartThrowType.miss:
        return 'Single';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF243040),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          _buildModeHeader(),
          const SizedBox(height: 10),
          _buildThrowTypeSelector(),
          const SizedBox(height: 10),
          Expanded(
            child: _buildNumberGrid(),
          ),
          const SizedBox(height: 10),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildModeHeader() {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Icon(
            Icons.ads_click_rounded,
            color: accentColor,
            size: 22,
          ),
          const SizedBox(width: 9),
          const Text(
            'Wurfeingabe',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Center(
              child: Text(
                '$selectedThrowTypeLabel aktiv',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThrowTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _ThrowTypeButton(
            label: 'Single',
            shortLabel: 'S',
            isSelected: selectedThrowType == DartThrowType.single,
            accentColor: accentColor,
            onTap: () {
              _selectThrowType(DartThrowType.single);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ThrowTypeButton(
            label: 'Double',
            shortLabel: 'D',
            isSelected: selectedThrowType == DartThrowType.double,
            accentColor: accentColor,
            onTap: () {
              _selectThrowType(DartThrowType.double);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ThrowTypeButton(
            label: 'Triple',
            shortLabel: 'T',
            isSelected: selectedThrowType == DartThrowType.triple,
            accentColor: accentColor,
            onTap: () {
              _selectThrowType(DartThrowType.triple);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumberGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 20,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.72,
      ),
      itemBuilder: (context, index) {
        final int number = index + 1;

        return _NumberButton(
          number: number,
          throwType: selectedThrowType,
          accentColor: accentColor,
          onTap: () {
            _submitNumber(number);
          },
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          child: _SpecialButton(
            label: 'Outer',
            value: '25',
            icon: Icons.radio_button_unchecked_rounded,
            accentColor: accentColor,
            onTap: () {
              _submitSpecialThrow(
                const DartThrow(
                  type: DartThrowType.outer,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SpecialButton(
            label: 'Bull',
            value: '50',
            icon: Icons.gps_fixed_rounded,
            accentColor: accentColor,
            onTap: () {
              _submitSpecialThrow(
                const DartThrow(
                  type: DartThrowType.bull,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SpecialButton(
            label: 'Miss',
            value: '0',
            icon: Icons.close_rounded,
            accentColor: accentColor,
            onTap: () {
              _submitSpecialThrow(
                const DartThrow(
                  type: DartThrowType.miss,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UndoButton(
            onTap: widget.onUndo,
          ),
        ),
      ],
    );
  }
}

class _ThrowTypeButton extends StatelessWidget {
  final String label;
  final String shortLabel;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ThrowTypeButton({
    required this.label,
    required this.shortLabel,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? accentColor : const Color(0xFF141A22),
          foregroundColor:
              isSelected ? const Color(0xFF06100B) : const Color(0xFFEAF1F8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? accentColor : const Color(0xFF2A3545),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF06100B).withValues(alpha: 0.10)
                    : const Color(0xFF101720),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  shortLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? const Color(0xFF06100B) : accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final int number;
  final DartThrowType throwType;
  final Color accentColor;
  final VoidCallback onTap;

  const _NumberButton({
    required this.number,
    required this.throwType,
    required this.accentColor,
    required this.onTap,
  });

  String get prefix {
    switch (throwType) {
      case DartThrowType.single:
        return 'S';
      case DartThrowType.double:
        return 'D';
      case DartThrowType.triple:
        return 'T';
      case DartThrowType.outer:
      case DartThrowType.bull:
      case DartThrowType.miss:
        return 'S';
    }
  }

  int get score {
    switch (throwType) {
      case DartThrowType.single:
        return number;
      case DartThrowType.double:
        return number * 2;
      case DartThrowType.triple:
        return number * 3;
      case DartThrowType.outer:
      case DartThrowType.bull:
      case DartThrowType.miss:
        return number;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF141A22),
        foregroundColor: const Color(0xFFEAF1F8),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(
            color: Color(0xFF2A3545),
            width: 1.0,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$prefix$number',
              style: const TextStyle(
                color: Color(0xFFEAF1F8),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              score == 1 ? '1 Punkt' : '$score Punkte',
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _SpecialButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF141A22),
          foregroundColor: const Color(0xFFEAF1F8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFF2A3545),
              width: 1.1,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _UndoButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B2430),
          foregroundColor: const Color(0xFFEAF1F8),
          disabledBackgroundColor: const Color(0xFF141A22),
          disabledForegroundColor: const Color(0xFF566172),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFF2A3545),
              width: 1.1,
            ),
          ),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.undo_rounded,
                size: 21,
              ),
              SizedBox(height: 3),
              Text(
                'Undo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}