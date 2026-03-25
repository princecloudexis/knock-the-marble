import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knock_the_marble/theme/board_themes.dart';
import 'package:knock_the_marble/widgets/name_setup_dialog.dart';
import 'package:knock_the_marble/widgets/tutorial_overlay.dart';
import 'dart:math' as math;
import '../models/game_mode.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/ad_provider.dart';
import '../services/game_save_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/banner_ad_widget.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'room_screen.dart';
import 'profile_screen.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _pulseCtrl;
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    GameSaveService.clearCache();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════

  String _marbleName(BoardTheme t, Player player) {
    if (player == Player.black) {
      return _inferMarbleColorName(t.blackMarbleColors);
    } else if (player == Player.white) {
      return _inferMarbleColorName(t.whiteMarbleColors);
    }
    return '';
  }

  String _inferMarbleColorName(List<Color> colors) {
    if (colors.isEmpty) return 'Marble';
    final primary = colors.first;
    final r = primary.red, g = primary.green, b = primary.blue;

    if (r > 200 && g > 200 && b > 200) return 'Pearl';
    if (r > 200 && g > 180 && b < 150) return 'Gold';
    if (r > 200 && g < 100 && b < 100) return 'Ruby';
    if (r > 200 && g > 100 && b < 80) return 'Ember';
    if (r > 200 && g < 120 && b > 120) return 'Rose';
    if (r < 100 && g < 100 && b > 150) return 'Sapphire';
    if (r < 80 && g > 120 && b > 150) return 'Teal';
    if (r < 100 && g > 150 && b < 120) return 'Emerald';
    if (r > 100 && g < 80 && b > 150) return 'Amethyst';
    if (r > 150 && g > 150 && b > 200) return 'Crystal';
    if (r > 200 && g > 220 && b > 220) return 'Frost';
    if (r > 180 && g > 200 && b > 230) return 'Ice';
    if (r > 200 && g > 200 && b < 100) return 'Amber';
    if (r < 60 && g > 100 && b > 100) return 'Ocean';

    if (r > g && r > b) return 'Crimson';
    if (g > r && g > b) return 'Jade';
    if (b > r && b > g) return 'Azure';

    return 'Marble';
  }

  String? _getUserName() {
    final userAsync = ref.read(userProvider);
    return userAsync.when(
      data: (user) =>
          user.displayName.isNotEmpty ? user.displayName : null,
      loading: () => null,
      error: (_, __) => null,
    );
  }

  Future<bool> _ensureNameSet() async {
  return await NameSetupDialog.ensureNameSet(context, ref);
}

  // ══════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════

  void _go(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _goWithAd(Widget screen) {
    ref.read(adProvider.notifier).showAdBeforeGame(
      onDone: () {
        if (mounted) _go(screen);
      },
    );
  }

  void _showAdThen(VoidCallback onDone) {
    ref.read(adProvider.notifier).showAdBeforeGame(
      onDone: () {
        if (mounted) onDone();
      },
    );
  }

  // ══════════════════════════════════════
  // HANDLERS
  // ══════════════════════════════════════

  Future<void> _handleVsComputerTap() async {
    HapticFeedback.lightImpact();
    final hasName = await _ensureNameSet();
    if (!hasName || !mounted) return;

    final t = ref.read(boardThemeProvider);
    final savedGame = await GameSaveService.loadGame(GameMode.vsComputer);
    if (!mounted) return;
    if (savedGame != null) {
      _showContinueOrNewDialog(t, savedGame, GameMode.vsComputer);
    } else {
      _showAdThen(() {
        if (mounted) _showColorPicker(ref.read(boardThemeProvider));
      });
    }
  }

  Future<void> _handleLocal1v1Tap() async {
    HapticFeedback.lightImpact();
    final hasName = await _ensureNameSet();
    if (!hasName || !mounted) return;

    final t = ref.read(boardThemeProvider);
    final savedGame =
        await GameSaveService.loadGame(GameMode.localMultiplayer);
    if (!mounted) return;
    if (savedGame != null) {
      _showContinueOrNewDialog(t, savedGame, GameMode.localMultiplayer);
    } else {
      _showAdThen(() {
        if (mounted) _showLocalColorPicker(ref.read(boardThemeProvider));
      });
    }
  }

  void _showLocalColorPicker(BoardTheme t) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => _buildColorPickerDialog(
        ctx: ctx,
        t: t,
        title: 'Choose Your Side',
        subtitle: 'Pick your marble color',
        onColorChosen: (player) {
          Navigator.pop(ctx);
          ref.read(gameProvider.notifier).startLocalMultiplayer();
          _go(const GameScreen());
        },
      ),
    );
  }

  void _handleProfileTap() {
    HapticFeedback.lightImpact();
    _goWithAd(const ProfileScreen());
  }

  void _handleSettingsTap() {
    HapticFeedback.lightImpact();
    _goWithAd(const SettingsScreen());
  }

  void _handlePlayOnlineTap() {
    HapticFeedback.lightImpact();
    _goWithAd(const RoomScreen());
  }

  void _handleHowToPlayTap() {
    HapticFeedback.lightImpact();
    _showAdThen(() {
      if (mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                const TutorialScreen(markAsSeen: false),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  // ══════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(boardThemeProvider);
    final userAsync = ref.watch(userProvider);
    final screenH = MediaQuery.of(context).size.height;
    final compact = screenH < 700;
    final veryCompact = screenH < 620;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: Stack(
          children: [
            ..._buildBgDecorations(t),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(t, userAsync),
                  Expanded(
                    flex: veryCompact ? 3 : 4,
                    child: _buildLogoSection(t, compact, veryCompact),
                  ),
                  Expanded(
                    flex: veryCompact ? 5 : 5,
                    child: _buildGameGrid(t, compact, veryCompact),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: veryCompact ? 2 : 4),
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: t.textSecondary.withOpacity(0.35),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const BannerAdWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // BACKGROUND DECORATIONS
  // ══════════════════════════════════════

  List<Widget> _buildBgDecorations(BoardTheme t) {
    return [
      Positioned(
        top: -60,
        right: -40,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  t.accent.withOpacity(0.06 + _pulseCtrl.value * 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -60,
        left: -50,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  t.accent.withOpacity(0.04 + _pulseCtrl.value * 0.02),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter:
              _GridPatternPainter(color: t.textSecondary.withOpacity(0.015)),
        ),
      ),
    ];
  }

  // ══════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════

  Widget _buildTopBar(BoardTheme t, AsyncValue<dynamic> userAsync) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.4),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Row(
            children: [
              Expanded(child: _buildProfileCard(t, userAsync)),
              const SizedBox(width: 10),
              _buildSettingsBtn(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BoardTheme t, AsyncValue<dynamic> userAsync) {
    return GestureDetector(
      onTap: _handleProfileTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.cardColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.surfaceBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: userAsync.when(
          loading: () => Row(
            children: [
              _shimmerCircle(t, 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBar(t, 70, 10),
                    const SizedBox(height: 4),
                    _shimmerBar(t, 45, 7),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: Icon(Icons.person_off_rounded,
                    size: 16, color: Colors.red.withOpacity(0.7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap to setup',
                  style: TextStyle(
                    color: t.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          data: (user) => Row(
            children: [
              Stack(
                children: [
                  AvatarWidget(avatarIndex: user.avatarIndex, size: 32),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        border: Border.all(color: t.cardColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isEmpty
                          ? 'Set your name'
                          : user.displayName,
                      style: TextStyle(
                        color: user.displayName.isEmpty
                            ? t.accent
                            : t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontStyle: user.displayName.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(Icons.tag_rounded,
                            size: 9, color: t.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          user.shortId,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: t.textSecondary.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerCircle(BoardTheme t, double size) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              t.textSecondary.withOpacity(0.08 + _pulseCtrl.value * 0.08),
        ),
      ),
    );
  }

  Widget _shimmerBar(BoardTheme t, double w, double h) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color:
              t.textSecondary.withOpacity(0.06 + _pulseCtrl.value * 0.06),
        ),
      ),
    );
  }

  Widget _buildSettingsBtn(BoardTheme t) {
    return GestureDetector(
      onTap: _handleSettingsTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: t.cardColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.surfaceBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child:
            Icon(Icons.settings_rounded, color: t.textSecondary, size: 22),
      ),
    );
  }

  // ══════════════════════════════════════
  // LOGO SECTION
  // ══════════════════════════════════════

  Widget _buildLogoSection(BoardTheme t, bool compact, bool veryCompact) {
    final logoSize = veryCompact ? 140.0 : (compact ? 180.0 : 200.0);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.1, 0.5),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, child) => Transform.translate(
              offset:
                  Offset(0, math.sin(_floatCtrl.value * math.pi) * 4),
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: t.accent.withOpacity(
                              0.08 + _pulseCtrl.value * 0.1),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // GAME GRID
  // ══════════════════════════════════════

  Widget _buildGameGrid(BoardTheme t, bool compact, bool veryCompact) {
    final gap = veryCompact ? 8.0 : (compact ? 10.0 : 12.0);
    final hPad = veryCompact ? 16.0 : (compact ? 18.0 : 22.0);

    final items = [
      _GameCardData(
        title: 'VS Computer',
        subtitle: 'Challenge the AI',
        icon: Icons.smart_toy_rounded,
        gradientColors: [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
        onTap: _handleVsComputerTap,
      ),
      _GameCardData(
        title: 'Local 1v1',
        subtitle: 'Play with a friend',
        icon: Icons.people_rounded,
        gradientColors: [const Color(0xFF00B894), const Color(0xFF55EFC4)],
        onTap: _handleLocal1v1Tap,
      ),
      _GameCardData(
        title: 'Play Online',
        subtitle: 'Compete globally',
        icon: Icons.language_rounded,
        gradientColors: [const Color(0xFFE17055), const Color(0xFFFAB1A0)],
        onTap: _handlePlayOnlineTap,
      ),
      _GameCardData(
        title: 'How to Play',
        subtitle: 'Learn the rules',
        icon: Icons.menu_book_rounded,
        gradientColors: [const Color(0xFFFDAA3E), const Color(0xFFFECF71)],
        onTap: _handleHowToPlayTap,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child:
                        _buildCard(t, items[0], 0, compact, veryCompact)),
                SizedBox(width: gap),
                Expanded(
                    child:
                        _buildCard(t, items[1], 1, compact, veryCompact)),
              ],
            ),
          ),
          SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child:
                        _buildCard(t, items[2], 2, compact, veryCompact)),
                SizedBox(width: gap),
                Expanded(
                    child:
                        _buildCard(t, items[3], 3, compact, veryCompact)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BoardTheme t,
    _GameCardData data,
    int index,
    bool compact,
    bool veryCompact,
  ) {
    const seg = 0.12;
    final begin = (0.35 + index * seg).clamp(0.0, 1.0);
    final end = (begin + 0.3).clamp(0.0, 1.0);

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(index.isEven ? -0.3 : 0.3, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity:
            CurvedAnimation(parent: _ctrl, curve: Interval(begin, end)),
        child: _CompactGameCard(
          t: t,
          data: data,
          compact: compact,
          veryCompact: veryCompact,
          pulseCtrl: _pulseCtrl,
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // CONTINUE OR NEW DIALOG
  // ══════════════════════════════════════

  void _showContinueOrNewDialog(
    BoardTheme t,
    SavedGameData savedGame,
    GameMode mode,
  ) {
    final isVsComputer = mode == GameMode.vsComputer;
    final userName = _getUserName() ?? 'You';

    final blackColors = t.blackMarbleColors;
    final whiteColors = t.whiteMarbleColors;
    final blackHlCol = t.blackHighlightColor;
    final blackHlOp = t.blackHighlightOpacity;
    final whiteHlCol = t.whiteHighlightColor;
    final whiteHlOp = t.whiteHighlightOpacity;

    String player1Label;
    String player2Label;
    if (isVsComputer) {
      if (savedGame.myColor == Player.black) {
        player1Label = userName;
        player2Label = 'Computer';
      } else {
        player1Label = 'Computer';
        player2Label = userName;
      }
    } else {
      player1Label = userName;
      player2Label = 'Player 2';
    }

    String currentTurnLabel;
    if (isVsComputer) {
      currentTurnLabel = savedGame.currentTurn == savedGame.myColor
          ? userName
          : 'Computer';
    } else {
      currentTurnLabel =
          savedGame.currentTurn == Player.black ? userName : 'Player 2';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: t.surfaceBorder.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        t.accent.withOpacity(0.2),
                        t.accent.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Icon(
                    isVsComputer
                        ? Icons.smart_toy_rounded
                        : Icons.people_rounded,
                    color: t.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Unfinished Game',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVsComputer
                      ? 'You have a saved VS Computer game'
                      : 'You have a saved Local 1v1 game',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // Score card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: t.surfaceColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: t.surfaceBorder.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _savedMarbleScore(
                              colors: blackColors,
                              hlCol: blackHlCol,
                              hlOp: blackHlOp,
                              score: savedGame.blackScore,
                              label: player1Label,
                              t: t,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6),
                            child: isVsComputer &&
                                    savedGame
                                        .difficultyLabel.isNotEmpty
                                ? Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6),
                                    decoration: BoxDecoration(
                                      color: t.accent
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              12),
                                      border: Border.all(
                                          color: t.accent
                                              .withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      savedGame.difficultyLabel,
                                      style: TextStyle(
                                        color: t.accent,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.surfaceColor
                                          .withOpacity(0.5),
                                      border: Border.all(
                                          color: t.surfaceBorder
                                              .withOpacity(0.4)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'VS',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight:
                                              FontWeight.w900,
                                          color: t.textSecondary
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          Expanded(
                            child: _savedMarbleScore(
                              colors: whiteColors,
                              hlCol: whiteHlCol,
                              hlOp: whiteHlOp,
                              score: savedGame.whiteScore,
                              label: player2Label,
                              t: t,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: t.surfaceColor.withOpacity(0.4),
                        ),
                        child: Text(
                          'Move ${savedGame.moveCount} • $currentTurnLabel\'s turn',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                t.textSecondary.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Continue
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx);
                      _showAdThen(() async {
                        final ok = await ref
                            .read(gameProvider.notifier)
                            .continueGame(mode);
                        if (ok && mounted) _go(const GameScreen());
                      });
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            t.accent,
                            t.accent.withOpacity(0.8)
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.accent.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // New Game
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      GameSaveService.deleteSave(mode);
                      if (isVsComputer) {
                        _showAdThen(() {
                          if (mounted) {
                            _showColorPicker(
                                ref.read(boardThemeProvider));
                          }
                        });
                      } else {
                        _showAdThen(() {
                          if (mounted) {
                            _showLocalColorPicker(
                                ref.read(boardThemeProvider));
                          }
                        });
                      }
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: t.surfaceColor.withOpacity(0.4),
                        border: Border.all(
                            color:
                                t.surfaceBorder.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color:
                                  t.textPrimary.withOpacity(0.7),
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'New Game',
                            style: TextStyle(
                              color:
                                  t.textPrimary.withOpacity(0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Cancel
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: t.textSecondary.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _savedMarbleScore({
    required List<Color> colors,
    required Color hlCol,
    required double hlOp,
    required int score,
    required String label,
    required BoardTheme t,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.35),
              radius: 0.85,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(1, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(-0.3, -0.3),
                child: Container(
                  width: 14,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        hlCol.withOpacity(hlOp * 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 8,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(hlOp * 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: t.textPrimary,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════
  // COLOR PICKER
  // ══════════════════════════════════════

  void _showColorPicker(BoardTheme t) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => _buildColorPickerDialog(
        ctx: ctx,
        t: t,
        title: 'Choose Your Marble',
        subtitle: 'Which side do you want to play?',
        onColorChosen: (player) {
          Navigator.pop(ctx);
          _showDifficultyPicker(t, player);
        },
      ),
    );
  }

  Widget _buildColorPickerDialog({
    required BuildContext ctx,
    required BoardTheme t,
    required String title,
    required String subtitle,
    required void Function(Player) onColorChosen,
  }) {
    final userName = _getUserName() ?? 'You';
    final blackColors = t.blackMarbleColors;
    final whiteColors = t.whiteMarbleColors;
    final blackHlCol = t.blackHighlightColor;
    final blackHlOp = t.blackHighlightOpacity;
    final whiteHlCol = t.whiteHighlightColor;
    final whiteHlOp = t.whiteHighlightOpacity;
    final blackName = _marbleName(t, Player.black);
    final whiteName = _marbleName(t, Player.white);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(28),
            border:
                Border.all(color: t.surfaceBorder.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.accent.withOpacity(0.2),
                      t.accent.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Icon(Icons.sports_esports_rounded,
                    color: t.accent, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: t.textSecondary.withOpacity(0.7),
                  ),
                  children: [
                    TextSpan(
                      text: userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: t.accent,
                      ),
                    ),
                    const TextSpan(text: ', pick your marble'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _MarbleOptionCard(
                      t: t,
                      marbleColors: blackColors,
                      highlightColor: blackHlCol,
                      highlightOpacity: blackHlOp,
                      marbleName: blackName,
                      label: 'Goes First',
                      player: Player.black,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onColorChosen(Player.black);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.surfaceColor.withOpacity(0.5),
                      border: Border.all(
                          color: t.surfaceBorder.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: t.textSecondary.withOpacity(0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MarbleOptionCard(
                      t: t,
                      marbleColors: whiteColors,
                      highlightColor: whiteHlCol,
                      highlightOpacity: whiteHlOp,
                      marbleName: whiteName,
                      label: 'Goes Second',
                      player: Player.white,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onColorChosen(Player.white);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.surfaceColor.withOpacity(0.3),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: t.textSecondary.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDifficultyPicker(BoardTheme t, Player chosenColor) {
    final userName = _getUserName() ?? 'You';
    final marbleColors = chosenColor == Player.black
        ? t.blackMarbleColors
        : t.whiteMarbleColors;
    final chosenMarbleName = _marbleName(t, chosenColor);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: t.surfaceBorder.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.35),
                          radius: 0.85,
                          colors: marbleColors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: t.accent,
                            ),
                          ),
                          TextSpan(text: ' • $chosenMarbleName'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Difficulty',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'How tough should your opponent be?',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 22),
                _DifficultyCard(
                  t: t,
                  title: 'Casual',
                  description: 'Relaxed game, perfect for learning',
                  icon: Icons.videogame_asset_rounded,
                  accentColor: const Color(0xFF4CAF50),
                  bgGradient: [
                    const Color(0xFF4CAF50).withOpacity(0.12),
                    const Color(0xFF4CAF50).withOpacity(0.04),
                  ],
                  difficulty: AiDifficulty.easy,
                  chosenColor: chosenColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    _startGame(AiDifficulty.easy, chosenColor);
                  },
                ),
                const SizedBox(height: 10),
                _DifficultyCard(
                  t: t,
                  title: 'Challenge',
                  description: 'Smart moves, keeps you thinking',
                  icon: Icons.track_changes_rounded,
                  accentColor: const Color(0xFFFF9800),
                  bgGradient: [
                    const Color(0xFFFF9800).withOpacity(0.12),
                    const Color(0xFFFF9800).withOpacity(0.04),
                  ],
                  difficulty: AiDifficulty.medium,
                  chosenColor: chosenColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    _startGame(AiDifficulty.medium, chosenColor);
                  },
                ),
                const SizedBox(height: 10),
                _DifficultyCard(
                  t: t,
                  title: 'Master',
                  description: 'No mercy, pure strategy',
                  icon: Icons.military_tech_rounded,
                  accentColor: const Color(0xFFE53935),
                  bgGradient: [
                    const Color(0xFFE53935).withOpacity(0.12),
                    const Color(0xFFE53935).withOpacity(0.04),
                  ],
                  difficulty: AiDifficulty.hard,
                  chosenColor: chosenColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    _startGame(AiDifficulty.hard, chosenColor);
                  },
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showColorPicker(t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: t.surfaceColor.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded,
                            size: 16,
                            color:
                                t.textSecondary.withOpacity(0.5)),
                        const SizedBox(width: 6),
                        Text(
                          'Change Marble',
                          style: TextStyle(
                            color:
                                t.textSecondary.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startGame(AiDifficulty difficulty, Player chosenColor) {
    GameSaveService.deleteSave(GameMode.vsComputer);
    ref
        .read(gameProvider.notifier)
        .startVsComputer(difficulty, myColor: chosenColor);
    _go(const GameScreen());
  }
}

// ══════════════════════════════════════
// COMPACT GAME CARD — FIXED OVERFLOW
// ══════════════════════════════════════

class _CompactGameCard extends StatefulWidget {
  final BoardTheme t;
  final _GameCardData data;
  final bool compact;
  final bool veryCompact;
  final AnimationController pulseCtrl;

  const _CompactGameCard({
    required this.t,
    required this.data,
    required this.compact,
    required this.veryCompact,
    required this.pulseCtrl,
  });

  @override
  State<_CompactGameCard> createState() => _CompactGameCardState();
}

class _CompactGameCardState extends State<_CompactGameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final data = widget.data;
    final vc = widget.veryCompact;
    final iconSize = vc ? 32.0 : 36.0;
    final fontSize = vc ? 12.0 : 14.0;
    final subSize = vc ? 8.5 : 10.0;
    final pad = vc ? 10.0 : 14.0;

    return GestureDetector(
      onTap: data.onTap,
      onTapDown: (_) {
        _scaleCtrl.animateTo(0.95);
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _scaleCtrl.animateTo(1.0);
        setState(() => _pressed = false);
      },
      onTapCancel: () {
        _scaleCtrl.animateTo(1.0);
        setState(() => _pressed = false);
      },
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (_, child) =>
            Transform.scale(scale: _scaleCtrl.value, child: child),
        child: Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: _pressed
                ? t.cardColor.withOpacity(0.9)
                : t.cardColor.withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed
                  ? data.gradientColors[0].withOpacity(0.5)
                  : data.gradientColors[0].withOpacity(0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: data.gradientColors[0]
                    .withOpacity(_pressed ? 0.15 : 0.06),
                blurRadius: _pressed ? 20 : 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon row — fixed size, not flexible
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: data.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradientColors[0].withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  color: Colors.white,
                  size: vc ? 16 : 18,
                ),
              ),

              // Spacer pushes text to bottom
              const Spacer(),

              // Title + subtitle
              Text(
                data.title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: vc ? 1 : 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: subSize,
                        color: t.textSecondary.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.gradientColors[0].withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 10,
                      color: data.gradientColors[0],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// DATA CLASS
// ══════════════════════════════════════

class _GameCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final String? badge;

  const _GameCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.badge,
  });
}

// ══════════════════════════════════════
// GRID PATTERN PAINTER
// ══════════════════════════════════════

class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const s = 40.0;
    for (double x = 0; x < size.width; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += s) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPatternPainter old) =>
      old.color != color;
}

// ══════════════════════════════════════
// MARBLE OPTION CARD
// ══════════════════════════════════════

class _MarbleOptionCard extends StatefulWidget {
  final BoardTheme t;
  final List<Color> marbleColors;
  final Color highlightColor;
  final double highlightOpacity;
  final String marbleName;
  final String label;
  final Player player;
  final VoidCallback onTap;

  const _MarbleOptionCard({
    required this.t,
    required this.marbleColors,
    required this.highlightColor,
    required this.highlightOpacity,
    required this.marbleName,
    required this.label,
    required this.player,
    required this.onTap,
  });

  @override
  State<_MarbleOptionCard> createState() => _MarbleOptionCardState();
}

class _MarbleOptionCardState extends State<_MarbleOptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    const marbleSize = 50.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        _hoverCtrl.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _hoverCtrl.reverse();
        setState(() => _pressed = false);
      },
      onTapCancel: () {
        _hoverCtrl.reverse();
        setState(() => _pressed = false);
      },
      child: AnimatedBuilder(
        animation: _hoverCtrl,
        builder: (_, child) {
          final scale = 1.0 - _hoverCtrl.value * 0.04;
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? t.surfaceColor.withOpacity(0.8)
                : t.surfaceColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _pressed
                  ? t.accent.withOpacity(0.5)
                  : t.surfaceBorder.withOpacity(0.5),
              width: _pressed ? 2.0 : 1.5,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: t.accent.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: marbleSize,
                height: marbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.35),
                    radius: 0.85,
                    colors: widget.marbleColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(2, 4),
                    ),
                    if (_pressed)
                      BoxShadow(
                        color: t.accent.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(-0.3, -0.3),
                      child: Container(
                        width: 16,
                        height: 9,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              widget.highlightColor.withOpacity(
                                  widget.highlightOpacity * 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: marbleSize * 0.25,
                      top: marbleSize * 0.2,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                              widget.highlightOpacity * 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.marbleName,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: TextStyle(
                  color: t.textSecondary.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// DIFFICULTY CARD
// ══════════════════════════════════════

class _DifficultyCard extends StatefulWidget {
  final BoardTheme t;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> bgGradient;
  final AiDifficulty difficulty;
  final Player chosenColor;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.t,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.bgGradient,
    required this.difficulty,
    required this.chosenColor,
    required this.onTap,
  });

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: _pressed
                ? [
                    widget.accentColor.withOpacity(0.2),
                    widget.accentColor.withOpacity(0.08),
                  ]
                : widget.bgGradient,
          ),
          border: Border.all(
            color: _pressed
                ? widget.accentColor.withOpacity(0.5)
                : widget.accentColor.withOpacity(0.15),
            width: _pressed ? 1.5 : 1.0,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.12),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor
                    .withOpacity(_pressed ? 0.2 : 0.1),
                border: Border.all(
                    color: widget.accentColor.withOpacity(0.2)),
              ),
              child: Center(
                child: Icon(widget.icon,
                    color: widget.accentColor, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.description,
                    style: TextStyle(
                      color: t.textSecondary.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor
                    .withOpacity(_pressed ? 0.25 : 0.1),
              ),
              child: Icon(Icons.play_arrow_rounded,
                  color: widget.accentColor, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}