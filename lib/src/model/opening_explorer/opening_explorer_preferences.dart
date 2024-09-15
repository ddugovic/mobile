import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/db/shared_preferences.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/common/speed.dart';
import 'package:lichess_mobile/src/model/opening_explorer/opening_explorer.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'opening_explorer_preferences.freezed.dart';
part 'opening_explorer_preferences.g.dart';

@Riverpod(keepAlive: true)
class OpeningExplorerPreferences extends _$OpeningExplorerPreferences {
  static const prefKey = 'preferences.opening_explorer';

  @override
  OpeningExplorerPrefState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final session = ref.watch(authSessionProvider);

    final stored = prefs.getString(prefKey);
    return stored != null
        ? OpeningExplorerPrefState.fromJson(
            jsonDecode(stored) as Map<String, dynamic>,
            user: session?.user,
          )
        : OpeningExplorerPrefState.defaults(user: session?.user);
  }

  Future<void> setDatabase(OpeningDatabase db) => _save(
        state.copyWith(db: db),
      );

  Future<void> setMasterDbSince(int year) =>
      _save(state.copyWith(masterDb: state.masterDb.copyWith(sinceYear: year)));

  Future<void> toggleLichessDbSpeed(Speed speed) => _save(
        state.copyWith(
          lishogiDb: state.lishogiDb.copyWith(
            speeds: state.lishogiDb.speeds.contains(speed)
                ? state.lishogiDb.speeds.remove(speed)
                : state.lishogiDb.speeds.add(speed),
          ),
        ),
      );

  Future<void> toggleLichessDbRating(int rating) => _save(
        state.copyWith(
          lishogiDb: state.lishogiDb.copyWith(
            ratings: state.lishogiDb.ratings.contains(rating)
                ? state.lishogiDb.ratings.remove(rating)
                : state.lishogiDb.ratings.add(rating),
          ),
        ),
      );

  Future<void> setLichessDbSince(DateTime since) => _save(
        state.copyWith(lishogiDb: state.lishogiDb.copyWith(since: since)),
      );

  Future<void> setPlayerDbUsernameOrId(String username) => _save(
        state.copyWith(
          playerDb: state.playerDb.copyWith(
            username: username,
          ),
        ),
      );

  Future<void> setPlayerDbSide(Side side) => _save(
        state.copyWith(playerDb: state.playerDb.copyWith(side: side)),
      );

  Future<void> togglePlayerDbSpeed(Speed speed) => _save(
        state.copyWith(
          playerDb: state.playerDb.copyWith(
            speeds: state.playerDb.speeds.contains(speed)
                ? state.playerDb.speeds.remove(speed)
                : state.playerDb.speeds.add(speed),
          ),
        ),
      );

  Future<void> togglePlayerDbGameMode(GameMode gameMode) => _save(
        state.copyWith(
          playerDb: state.playerDb.copyWith(
            gameModes: state.playerDb.gameModes.contains(gameMode)
                ? state.playerDb.gameModes.remove(gameMode)
                : state.playerDb.gameModes.add(gameMode),
          ),
        ),
      );

  Future<void> setPlayerDbSince(DateTime since) => _save(
        state.copyWith(playerDb: state.playerDb.copyWith(since: since)),
      );

  Future<void> _save(OpeningExplorerPrefState newState) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      prefKey,
      jsonEncode(newState.toJson()),
    );
    state = newState;
  }
}

enum OpeningDatabase {
  master,
  lishogi,
  player,
}

@Freezed(fromJson: true, toJson: true)
class OpeningExplorerPrefState with _$OpeningExplorerPrefState {
  const OpeningExplorerPrefState._();

  const factory OpeningExplorerPrefState({
    required OpeningDatabase db,
    required MasterDbPrefState masterDb,
    required LichessDbPrefState lishogiDb,
    required PlayerDbPrefState playerDb,
  }) = _OpeningExplorerPrefState;

  factory OpeningExplorerPrefState.defaults({LightUser? user}) =>
      OpeningExplorerPrefState(
        db: OpeningDatabase.master,
        masterDb: MasterDbPrefState.defaults,
        lishogiDb: LichessDbPrefState.defaults,
        playerDb: PlayerDbPrefState.defaults(user: user),
      );

  factory OpeningExplorerPrefState.fromJson(
    Map<String, dynamic> json, {
    LightUser? user,
  }) {
    try {
      final prefs = _$OpeningExplorerPrefStateFromJson(json);
      return prefs.copyWith(
        playerDb: user != null
            ? prefs.playerDb.copyWith(username: user.name)
            : prefs.playerDb,
      );
    } catch (_) {
      return OpeningExplorerPrefState.defaults(user: user);
    }
  }
}

@Freezed(fromJson: true, toJson: true)
class MasterDbPrefState with _$MasterDbPrefState {
  const MasterDbPrefState._();

  const factory MasterDbPrefState({
    required int sinceYear,
  }) = _MasterDbPrefState;

  static const kEarliestYear = 1952;
  static final now = DateTime.now();
  static final datesMap = {
    'Last 3 years': now.year - 3,
    'Last 10 years': now.year - 10,
    'Last 20 years': now.year - 20,
    'All time': kEarliestYear,
  };
  static const defaults = MasterDbPrefState(sinceYear: kEarliestYear);

  factory MasterDbPrefState.fromJson(Map<String, dynamic> json) {
    try {
      return _$MasterDbPrefStateFromJson(json);
    } catch (_) {
      return defaults;
    }
  }
}

@Freezed(fromJson: true, toJson: true)
class LichessDbPrefState with _$LichessDbPrefState {
  const LichessDbPrefState._();

  const factory LichessDbPrefState({
    required ISet<Speed> speeds,
    required ISet<int> ratings,
    required DateTime since,
  }) = _LichessDbPrefState;

  static const kAvailableSpeeds = ISetConst({
    Speed.ultraBullet,
    Speed.bullet,
    Speed.blitz,
    Speed.rapid,
    Speed.classical,
    Speed.correspondence,
  });
  static const kAvailableRatings = ISetConst({
    400,
    1000,
    1200,
    1400,
    1600,
    1800,
    2000,
    2200,
    2500,
  });
  static final earliestDate = DateTime.utc(2012, 12);
  static final now = DateTime.now();
  static const kDaysInAYear = 365;
  static final datesMap = {
    'Last year': now.subtract(const Duration(days: kDaysInAYear)),
    'Last 5 years': now.subtract(const Duration(days: kDaysInAYear * 5)),
    'All time': earliestDate,
  };
  static final defaults = LichessDbPrefState(
    speeds: kAvailableSpeeds.remove(Speed.ultraBullet),
    ratings: kAvailableRatings.remove(400),
    since: earliestDate,
  );

  factory LichessDbPrefState.fromJson(Map<String, dynamic> json) {
    try {
      return _$LichessDbPrefStateFromJson(json);
    } catch (_) {
      return defaults;
    }
  }
}

@Freezed(fromJson: true, toJson: true)
class PlayerDbPrefState with _$PlayerDbPrefState {
  const PlayerDbPrefState._();

  const factory PlayerDbPrefState({
    String? username,
    required Side side,
    required ISet<Speed> speeds,
    required ISet<GameMode> gameModes,
    required DateTime since,
  }) = _PlayerDbPrefState;

  static const kAvailableSpeeds = ISetConst({
    Speed.ultraBullet,
    Speed.bullet,
    Speed.blitz,
    Speed.rapid,
    Speed.classical,
    Speed.correspondence,
  });
  static final earliestDate = DateTime.utc(2012, 12);
  static final now = DateTime.now();
  static final datesMap = {
    'This month': now,
    'Last month': now.subtract(const Duration(days: 32)),
    'Last 6 months': now.subtract(const Duration(days: 183)),
    'Last year': now.subtract(const Duration(days: 365)),
    'All time': earliestDate,
  };
  factory PlayerDbPrefState.defaults({LightUser? user}) => PlayerDbPrefState(
        username: user?.name,
        side: Side.white,
        speeds: kAvailableSpeeds,
        gameModes: GameMode.values.toISet(),
        since: earliestDate,
      );

  factory PlayerDbPrefState.fromJson(Map<String, dynamic> json) {
    try {
      return _$PlayerDbPrefStateFromJson(json);
    } catch (_) {
      return PlayerDbPrefState.defaults();
    }
  }
}
