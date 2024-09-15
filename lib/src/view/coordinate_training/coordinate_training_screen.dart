import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/coordinate_training/coordinate_training_controller.dart';
import 'package:lichess_mobile/src/model/coordinate_training/coordinate_training_preferences.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/coordinate_training/coordinate_display.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform_alert_dialog.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

class CoordinateTrainingScreen extends StatelessWidget {
  const CoordinateTrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('Coordinate Training'), // TODO l10n once script works
      ),
      body: _Body(),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late Side orientation;

  Square? highlightLastGuess;

  Timer? highlightTimer;

  void _setOrientation(SideChoice choice) {
    setState(() {
      orientation = switch (choice) {
        SideChoice.white => Side.white,
        SideChoice.black => Side.black,
        SideChoice.random => Side.values[Random().nextInt(Side.values.length)],
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _setOrientation(ref.read(coordinateTrainingPreferencesProvider).sideChoice);
  }

  @override
  void dispose() {
    super.dispose();
    highlightTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final trainingState = ref.watch(coordinateTrainingControllerProvider);
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);

    final IMap<Square, SquareHighlight> squareHighlights =
        <Square, SquareHighlight>{
      if (trainingState.trainingActive)
        if (trainingPrefs.mode == TrainingMode.findSquare) ...{
          if (highlightLastGuess != null) ...{
            highlightLastGuess!: SquareHighlight(
              details: HighlightDetails(
                solidColor: (trainingState.lastGuess == Guess.correct
                        ? context.lishogiColors.good
                        : context.lishogiColors.error)
                    .withValues(alpha: 0.5),
              ),
            ),
          },
        } else ...{
          trainingState.currentCoord!: SquareHighlight(
            details: HighlightDetails(
              solidColor: context.lishogiColors.good.withValues(alpha: 0.5),
            ),
          ),
        },
    }.lock;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = constraints.biggest.aspectRatio;

                final defaultBoardSize = constraints.biggest.shortestSide;
                final isTablet = isTabletOrLarger(context);
                final remainingHeight =
                    constraints.maxHeight - defaultBoardSize;
                final isSmallScreen =
                    remainingHeight < kSmallRemainingHeightLeftBoardThreshold;
                final boardSize = isTablet || isSmallScreen
                    ? defaultBoardSize - kTabletBoardTableSidePadding * 2
                    : defaultBoardSize;

                final direction =
                    aspectRatio > 1 ? Axis.horizontal : Axis.vertical;

                return Flex(
                  direction: direction,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        _TimeBar(
                          maxWidth: boardSize,
                          timeFractionElapsed:
                              trainingState.timeFractionElapsed,
                          color: trainingState.lastGuess == Guess.incorrect
                              ? context.lishogiColors.error
                              : context.lishogiColors.good,
                        ),
                        _TrainingBoard(
                          boardSize: boardSize,
                          isTablet: isTablet,
                          orientation: orientation,
                          squareHighlights: squareHighlights,
                          onGuess: _onGuess,
                        ),
                      ],
                    ),
                    if (trainingState.trainingActive)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Score(
                              score: trainingState.score,
                              size: boardSize / 8,
                              color: trainingState.lastGuess == Guess.incorrect
                                  ? context.lishogiColors.error
                                  : context.lishogiColors.good,
                            ),
                            FatButton(
                              semanticsLabel: 'Abort Training',
                              onPressed: ref
                                  .read(
                                    coordinateTrainingControllerProvider
                                        .notifier,
                                  )
                                  .stopTraining,
                              child: const Text(
                                'Abort Training',
                                style: Styles.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: _Settings(
                          onSideChoiceSelected: _setOrientation,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          BottomBar(
            children: [
              BottomBarButton(
                label: context.l10n.menu,
                onTap: () => showAdaptiveBottomSheet<void>(
                  context: context,
                  builder: (BuildContext context) =>
                      const _CoordinateTrainingMenu(),
                ),
                icon: Icons.tune,
              ),
              BottomBarButton(
                icon: Icons.info_outline,
                label: context.l10n.aboutX('Coordinate Training'),
                onTap: () => _coordinateTrainingInfoDialogBuilder(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onGuess(Square square) {
    ref
        .read(coordinateTrainingControllerProvider.notifier)
        .guessCoordinate(square);

    setState(() {
      highlightLastGuess = square;

      highlightTimer?.cancel();
      highlightTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          highlightLastGuess = null;
        });
      });
    });
  }
}

class _TimeBar extends StatelessWidget {
  const _TimeBar({
    required this.maxWidth,
    required this.timeFractionElapsed,
    required this.color,
  });

  final double maxWidth;
  final double? timeFractionElapsed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: maxWidth * (timeFractionElapsed ?? 0.0),
        height: 15.0,
        child: ColoredBox(
          color: color,
        ),
      ),
    );
  }
}

class _CoordinateTrainingMenu extends ConsumerWidget {
  const _CoordinateTrainingMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);

    return BottomSheetScrollableContainer(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      children: [
        ListSection(
          header: Text(
            context.l10n.preferencesDisplay,
            style: Styles.sectionTitle,
          ),
          children: [
            SwitchSettingTile(
              title: const Text('Show Coordinates'),
              value: trainingPrefs.showCoordinates,
              onChanged: ref
                  .read(coordinateTrainingPreferencesProvider.notifier)
                  .setShowCoordinates,
            ),
            SwitchSettingTile(
              title: const Text('Show Pieces'),
              value: trainingPrefs.showPieces,
              onChanged: ref
                  .read(coordinateTrainingPreferencesProvider.notifier)
                  .setShowPieces,
            ),
          ],
        ),
      ],
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({
    required this.size,
    required this.color,
    required this.score,
  });

  final int score;

  final double size;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10.0,
        left: 10.0,
        right: 10.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(4.0),
          ),
          color: color,
        ),
        width: size,
        height: size,
        child: Center(
          child: Text(
            score.toString(),
            style: Styles.bold.copyWith(
              color: Colors.white,
              fontSize: 24.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _Settings extends ConsumerStatefulWidget {
  const _Settings({
    required this.onSideChoiceSelected,
  });

  final void Function(SideChoice) onSideChoiceSelected;

  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  @override
  Widget build(BuildContext context) {
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PlatformListTile(
          title: Text(context.l10n.side),
          trailing: Padding(
            padding: Styles.horizontalBodyPadding,
            child: Wrap(
              spacing: 8.0,
              children: SideChoice.values.map((choice) {
                return ChoiceChip(
                  label: Text(sideChoiceL10n(context, choice)),
                  selected: trainingPrefs.sideChoice == choice,
                  showCheckmark: false,
                  onSelected: (selected) {
                    widget.onSideChoiceSelected(choice);
                    ref
                        .read(coordinateTrainingPreferencesProvider.notifier)
                        .setSideChoice(choice);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        PlatformListTile(
          title: Text(context.l10n.time),
          trailing: Padding(
            padding: Styles.horizontalBodyPadding,
            child: Wrap(
              spacing: 8.0,
              children: TimeChoice.values.map((choice) {
                return ChoiceChip(
                  label: timeChoiceL10n(context, choice),
                  selected: trainingPrefs.timeChoice == choice,
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(
                            coordinateTrainingPreferencesProvider.notifier,
                          )
                          .setTimeChoice(choice);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ),
        FatButton(
          semanticsLabel: 'Start Training',
          onPressed: () => ref
              .read(coordinateTrainingControllerProvider.notifier)
              .startTraining(trainingPrefs.timeChoice.duration),
          child: const Text(
            // TODO l10n once script works
            'Start Training',
            style: Styles.bold,
          ),
        ),
      ],
    );
  }
}

class _TrainingBoard extends ConsumerStatefulWidget {
  const _TrainingBoard({
    required this.boardSize,
    required this.isTablet,
    required this.orientation,
    required this.onGuess,
    required this.squareHighlights,
  });

  final double boardSize;

  final bool isTablet;

  final Side orientation;

  final void Function(Square) onGuess;

  final IMap<Square, SquareHighlight> squareHighlights;

  @override
  ConsumerState<_TrainingBoard> createState() => _TrainingBoardState();
}

class _TrainingBoardState extends ConsumerState<_TrainingBoard> {
  @override
  Widget build(BuildContext context) {
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);
    final trainingState = ref.watch(coordinateTrainingControllerProvider);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ChessboardEditor(
              size: widget.boardSize,
              pieces: readFen(
                trainingPrefs.showPieces ? kInitialFEN : kEmptyFEN,
              ),
              squareHighlights: widget.squareHighlights,
              orientation: widget.orientation,
              settings: ChessboardEditorSettings(
                pieceAssets: boardPrefs.pieceSet.assets,
                colorScheme: boardPrefs.boardTheme.colors,
                enableCoordinates: trainingPrefs.showCoordinates,
                borderRadius: widget.isTablet
                    ? const BorderRadius.all(Radius.circular(4.0))
                    : BorderRadius.zero,
                boxShadow: widget.isTablet ? boardShadows : const <BoxShadow>[],
              ),
              pointerMode: EditorPointerMode.edit,
              onEditedSquare: (square) {
                if (trainingState.trainingActive &&
                    trainingPrefs.mode == TrainingMode.findSquare) {
                  widget.onGuess(square);
                }
              },
            ),
            if (trainingState.trainingActive &&
                trainingPrefs.mode == TrainingMode.findSquare)
              CoordinateDisplay(
                currentCoord: trainingState.currentCoord!,
                nextCoord: trainingState.nextCoord!,
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> _coordinateTrainingInfoDialogBuilder(BuildContext context) {
  return showAdaptiveDialog(
    context: context,
    builder: (context) {
      final content = SingleChildScrollView(
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            // TODO translate
            children: const [
              TextSpan(
                text:
                    'Knowing the chessboard coordinates is a very important skill for several reasons:\n',
              ),
              TextSpan(
                text:
                    '  • Most chess courses and exercises use the algebraic notation extensively.\n',
              ),
              TextSpan(
                text:
                    "  • It makes it easier to talk to your chess friends, since you both understand the 'language of chess'.\n",
              ),
              TextSpan(
                text:
                    '  • You can analyse a game more effectively if you can quickly recognise coordinates.\n',
              ),
              TextSpan(
                text: '\n',
              ),
              TextSpan(
                text: 'Find Square\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'A coordinate appears on the board and you must click on the corresponding square.\n',
              ),
              TextSpan(
                text:
                    'You have 30 seconds to correctly map as many squares as possible!\n',
              ),
            ],
          ),
        ),
      );

      return PlatformAlertDialog(
        title: Text(context.l10n.aboutX('Coordinate Training')),
        content: content,
        actions: [
          PlatformDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.mobileOkButton),
          ),
        ],
      );
    },
  );
}
