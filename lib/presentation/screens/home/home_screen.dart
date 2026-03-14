import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/audio/audio_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../bloc/music_library/music_library_bloc.dart';
import '../../bloc/music_library/music_library_event.dart';
import '../../bloc/music_library/music_library_state.dart';
import '../../bloc/music_scanner/music_scanner_bloc.dart';
import '../../bloc/music_scanner/music_scanner_event.dart';
import '../../bloc/music_scanner/music_scanner_state.dart';
import '../../bloc/music_search/music_search_bloc.dart';
import '../../bloc/music_search/music_search_event.dart';
import '../../bloc/music_search/music_search_state.dart';
import '../../bloc/playlist/playlist_bloc.dart';
import '../../bloc/playlist/playlist_event.dart';
import '../../bloc/playlist/playlist_state.dart';
import '../../providers/audio_providers.dart';
import '../../providers/bloc_providers.dart';
import '../../widgets/background_painter.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/playlist.dart';
import '../player/player_screen.dart';
import '../library/category_detail_screen.dart';

enum LibraryGroupType { artist, album, genre, folder }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late MusicScannerBloc _scannerBloc;
  late MusicLibraryBloc _libraryBloc;
  late MusicSearchBloc _searchBloc;
  late PlaylistBloc _playlistBloc;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _scannerBloc = ref.read(musicScannerBlocProvider);
    _libraryBloc = ref.read(musicLibraryBlocProvider);
    _searchBloc = ref.read(musicSearchBlocProvider);
    _playlistBloc = ref.read(playlistBlocProvider);
    _tabController = TabController(length: 6, vsync: this);

    _scannerBloc.add(ScanMusicEvent());
    _playlistBloc.add(LoadFavouritesAndRecentEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final lagosTime = DateTime.now().toUtc().add(const Duration(hours: 1));
    final hour = lagosTime.hour;

    if (hour >= 0 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _scannerBloc),
        BlocProvider.value(value: _libraryBloc),
        BlocProvider.value(value: _searchBloc),
        BlocProvider.value(value: _playlistBloc),
      ],
      child: BlocListener<MusicScannerBloc, MusicScannerState>(
        listener: (context, state) {
          if (state is MusicScannerSuccess) {
            _libraryBloc.add(LoadLibraryEvent(state.songs));
          }
        },
        child: BlocBuilder<MusicScannerBloc, MusicScannerState>(
          builder: (context, scannerState) {
            final bool isScanning = scannerState is MusicScannerLoading;

            return Scaffold(
              backgroundColor: AppColors.background,
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BackgroundPainter(),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(child: _buildHeader(isScanning)),
                          SliverToBoxAdapter(child: _buildSearchBar(context, isScanning)),
                          if (!_isSearchActive) ...[
                            SliverToBoxAdapter(child: _buildQuickActions(isScanning)),
                            SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabPersistentHeaderDelegate(
                                height: 54.h,
                                child: Container(
                                  color: AppColors.background.withOpacity(0.01),
                                  alignment: Alignment.centerLeft,
                                  child: ClipRRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        color: AppColors.background.withOpacity(0.5),
                                        child: _buildTabMenu(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ];
                      },
                      body: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.2),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                          child: _isSearchActive
                              ? _SearchResultsView()
                              : TabBarView(
                                  controller: _tabController,
                                  physics: isScanning
                                      ? const NeverScrollableScrollPhysics()
                                      : const BouncingScrollPhysics(),
                                  children: [
                                    _SongsTabView(),
                                    _PlaylistsTabView(),
                                    _LibraryGroupView(groupType: LibraryGroupType.artist),
                                    _LibraryGroupView(groupType: LibraryGroupType.album),
                                    _LibraryGroupView(groupType: LibraryGroupType.genre),
                                    _LibraryGroupView(groupType: LibraryGroupType.folder),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MiniPlayer(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isScanning) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.lexendDeca(
                  color: AppColors.greyBase.withOpacity(0.5),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "R h o d a",
                style: GoogleFonts.lexendDeca(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          _buildCircleButton(
            icon: isScanning ? Icons.sync : Icons.refresh_rounded,
            onPressed: isScanning ? () {} : () => _scannerBloc.add(ScanMusicEvent()),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isScanning) {
    return BlocBuilder<PlaylistBloc, PlaylistState>(
      builder: (context, playlistState) {
        int favCount = 0;
        int recentCount = 0;
        List<Song> favSongs = [];
        List<Song> recentSongs = [];

        if (playlistState is PlaylistSuccess) {
          favCount = playlistState.favouriteSongPaths.length;
          recentCount = playlistState.recentSongPaths.length;

          final scannerState = _scannerBloc.state;
          if (scannerState is MusicScannerSuccess) {
            favSongs = scannerState.songs.where((s) => playlistState.favouriteSongPaths.contains(s.id)).toList();
            
            final assetSongs = _getAssetSongs();
            favSongs.addAll(assetSongs.where((s) => playlistState.favouriteSongPaths.contains(s.id)));

            for (var path in playlistState.recentSongPaths) {
              try {
                final allPossibleSongs = [...scannerState.songs, ...assetSongs];
                final song = allPossibleSongs.firstWhere((s) => s.id == path);
                recentSongs.add(song);
              } catch (_) {}
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(top: 16.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFeaturedCard(isScanning),
                SizedBox(width: 16.w),
                _buildActionCard(
                  title: "Favorites",
                  subtitle: "$favCount tracks",
                  icon: Icons.favorite_rounded,
                  color: Colors.redAccent,
                  onTap: isScanning ? () {} : () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(
                      title: "Favorites",
                      songs: favSongs,
                      type: "FAVORITES",
                    )));
                  },
                ),
                SizedBox(width: 16.w),
                _buildActionCard(
                  title: "Recent",
                  subtitle: "$recentCount tracks",
                  icon: Icons.history_rounded,
                  color: Colors.blueAccent,
                  onTap: isScanning ? () {} : () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(
                      title: "Recent Plays",
                      songs: recentSongs,
                      type: "RECENT",
                    )));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Song> _getAssetSongs() {
    return [
      const Song(
        id: 'asset:///assets/music/victor_track.mp3',
        title: 'Remember',
        artist: 'Victor Special',
        album: 'Asset Collection',
        duration: Duration(seconds: 33),
        path: 'asset:///assets/music/victor_track.mp3',
      ),
      const Song(
        id: 'asset:///assets/music/today_denver.mp3',
        title: 'Today',
        artist: 'Victor Special',
        album: 'Asset Collection',
        duration: Duration(seconds: 228),
        path: 'asset:///assets/music/today_denver.mp3',
      ),
    ];
  }

  Widget _buildFeaturedCard(bool isScanning) {
    return GestureDetector(
      onTap: isScanning ? null : () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(
          title: "Victor Special",
          songs: _getAssetSongs(),
          type: "VICTOR SPECIAL",
        )));
      },
      child: Opacity(
        opacity: isScanning ? 0.6 : 1.0,
        child: Container(
          width: 260.w,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      "FOR RHODA",
                      style: GoogleFonts.lexendDeca(
                        color: AppColors.primary, 
                        fontSize: 9.sp, 
                        fontWeight: FontWeight.w700, 
                        letterSpacing: 1.5
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.auto_awesome_rounded, color: AppColors.primary.withOpacity(0.5), size: 20.sp),
                ],
              ),
              SizedBox(height: 20.h),
              Text(
                "VICTOR SPECIAL",
                style: GoogleFonts.outfit(
                  color: Colors.white, 
                  fontSize: 22.sp, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: -0.5
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                "If your name is not Rhoda, you stole this app!",
                style: GoogleFonts.lexendDeca(
                  color: Colors.white.withOpacity(0.4), 
                  fontSize: 12.sp, 
                  fontWeight: FontWeight.w400
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120.w,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.greyBase.withOpacity(0.6), fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabMenu() {
    return Container(
      height: 42.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.greyBase.withOpacity(0.5),
        labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        tabs: const [
          Tab(text: "  Songs  "),
          Tab(text: "  Playlists  "),
          Tab(text: "  Artists  "),
          Tab(text: "  Albums  "),
          Tab(text: "  Genres  "),
          Tab(text: "  Folders  "),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isScanning) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Opacity(
        opacity: isScanning ? 0.6 : 1.0,
        child: TextField(
          controller: _searchController,
          enabled: !isScanning,
          onChanged: (value) {
            final scannerState = _scannerBloc.state;
            if (scannerState is MusicScannerSuccess) {
              _searchBloc.add(SearchQueryChangedEvent(value, scannerState.songs));
            }
          },
          onTap: () => setState(() => _isSearchActive = true),
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: "Search music...",
            hintStyle: TextStyle(color: AppColors.greyBase.withOpacity(0.4), fontSize: 13.sp),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _isSearchActive ? AppColors.primary : AppColors.greyBase.withOpacity(0.4),
              size: 20.sp,
            ),
            suffixIcon: _isSearchActive
                ? IconButton(
              icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20.sp),
              onPressed: () {
                _searchController.clear();
                _searchBloc.add(ClearSearchEvent());
                setState(() => _isSearchActive = false);
                FocusScope.of(context).unfocus();
              },
            )
                : null,

            // Background Styling
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),

            // Border Styling for all states
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26.r),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26.r),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26.r),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26.r),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.02),
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeautifulLoader extends StatefulWidget {
  const _BeautifulLoader();

  @override
  State<_BeautifulLoader> createState() => _BeautifulLoaderState();
}

class _BeautifulLoaderState extends State<_BeautifulLoader> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _rotateController,
                child: Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 2,
                    ),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.1).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Icon(Icons.music_note_rounded, color: AppColors.primary, size: 24.sp),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Text(
            "SYNCING LIBRARY",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<MusicSearchBloc, MusicSearchState>(
      builder: (context, state) {
        if (state.query.isEmpty) {
          return Center(child: Text("Search for your favorite tracks", style: TextStyle(color: AppColors.greyBase.withOpacity(0.5))));
        }
        if (state.isSearching) {
          return const _BeautifulLoader();
        }
        if (state.searchResults.isEmpty) {
          return Center(child: Text("No tracks found", style: TextStyle(color: AppColors.greyBase)));
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 100.h),
          itemCount: state.searchResults.length,
          itemBuilder: (context, index) => SongTile(song: state.searchResults[index], songs: state.searchResults, index: index),
        );
      },
    );
  }
}

class _SongsTabView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<MusicScannerBloc, MusicScannerState>(
      builder: (context, state) {
        if (state is MusicScannerLoading) {
          return const _BeautifulLoader();
        } else if (state is MusicScannerSuccess) {
          if (state.songs.isEmpty) {
            return Center(child: Text("No tracks found", style: TextStyle(color: AppColors.greyBase)));
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 100.h),
            itemCount: state.songs.length,
            itemBuilder: (context, index) => SongTile(song: state.songs[index], songs: state.songs, index: index),
          );
        } else if (state is MusicScannerFailure) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _PlaylistsTabView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistBloc = ref.watch(playlistBlocProvider);
    return BlocBuilder<PlaylistBloc, PlaylistState>(
      bloc: playlistBloc,
      builder: (context, state) {
        if (state is PlaylistLoading) return const _BeautifulLoader();
        final playlists = state is PlaylistSuccess ? state.playlists : <Playlist>[];
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 100.h),
          children: [
            _buildCreatePlaylistButton(context, playlistBloc),
            SizedBox(height: 16.h),
            if (playlists.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: Center(child: Text("No playlists created yet", style: TextStyle(color: AppColors.greyBase.withOpacity(0.3)))),
              )
            else
              ...playlists.map((p) => _PlaylistTile(playlist: p)),
          ],
        );
      },
    );
  }

  Widget _buildCreatePlaylistButton(BuildContext context, PlaylistBloc bloc) {
    return InkWell(
      onTap: () => _showCreateDialog(context, bloc),
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.primary, size: 22.sp),
            SizedBox(width: 8.w),
            Text("Create New Playlist", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13.sp)),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, PlaylistBloc bloc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        title: const Text("New Playlist", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter name",
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: TextStyle(color: AppColors.greyBase, fontSize: 12.sp))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                bloc.add(CreatePlaylistEvent(controller.text));
                Navigator.pop(ctx);
              }
            },
            child: Text("CREATE", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        leading: Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 26.sp),
        ),
        title: Text(playlist.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
        subtitle: Text("${playlist.songPaths.length} tracks", style: TextStyle(color: AppColors.greyBase.withOpacity(0.6), fontSize: 11.sp)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error.withOpacity(0.4), size: 20.sp),
          onPressed: () => ref.read(playlistBlocProvider).add(DeletePlaylistEvent(playlist.id)),
        ),
        onTap: () {
          final scannerState = ref.read(musicScannerBlocProvider).state;
          if (scannerState is MusicScannerSuccess) {
            final songs = scannerState.songs.where((s) => playlist.songPaths.contains(s.id)).toList();
            Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(
              title: playlist.name,
              songs: songs,
              type: "PLAYLIST",
              playlistId: playlist.id,
            )));
          }
        },
      ),
    );
  }
}

class _LibraryGroupView extends StatelessWidget {
  final LibraryGroupType groupType;
  const _LibraryGroupView({required this.groupType});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicLibraryBloc, MusicLibraryState>(
      builder: (context, state) {
        if (state.isLoading) return const _BeautifulLoader();
        Map<String, List<Song>> data;
        switch (groupType) {
          case LibraryGroupType.artist: data = state.artists; break;
          case LibraryGroupType.album: data = state.albums; break;
          case LibraryGroupType.genre: data = state.genres; break;
          case LibraryGroupType.folder: data = state.folders; break;
        }
        final keys = data.keys.toList()..sort();
        if (keys.isEmpty) return Center(child: Text("No items found", style: TextStyle(color: AppColors.greyBase.withOpacity(0.3))));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 100.h),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final key = keys[index];
            final songs = data[key]!;
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                leading: Container(
                  width: 50.w, height: 50.w,
                  decoration: BoxDecoration(
                    color: AppColors.taupeDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(_getIcon(), color: AppColors.taupeLight, size: 24.sp),
                ),
                title: Text(key, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                subtitle: Text("${songs.length} tracks", style: TextStyle(color: AppColors.greyBase.withOpacity(0.6), fontSize: 11.sp)),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 20.sp),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(
                  title: key,
                  songs: songs,
                  type: groupType.name.toUpperCase(),
                ))),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIcon() {
    switch (groupType) {
      case LibraryGroupType.artist: return Icons.person_rounded;
      case LibraryGroupType.album: return Icons.album_rounded;
      case LibraryGroupType.genre: return Icons.style_rounded;
      case LibraryGroupType.folder: return Icons.folder_rounded;
    }
  }
}

class SongTile extends ConsumerWidget {
  final Song song;
  final List<Song>? songs;
  final int? index;
  const SongTile({super.key, required this.song, this.songs, this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final handler = ref.read(audioHandlerProvider) as RhodaAudioHandler;
          final queue = songs ?? [song];
          
          // First tap logic check: Ensure the handler starts immediately
          await handler.setQueueAndPlay(queue.map((s) => s.toMediaItem()).toList(), index ?? 0);

          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerScreen()));
          }
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            height: 50.w, width: 50.w,
            color: AppColors.taupeDark.withOpacity(0.1),
            child: Icon(Icons.music_note_rounded, color: AppColors.primary.withOpacity(0.5), size: 24.sp),
          ),
        ),
        title: Text(song.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(song.artist, style: TextStyle(color: AppColors.greyBase.withOpacity(0.5), fontSize: 11.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _buildTrailingMenu(context, ref),
      ),
    );
  }

  Widget _buildTrailingMenu(BuildContext context, WidgetRef ref) {
    final playlistBloc = ref.watch(playlistBlocProvider);
    return BlocBuilder<PlaylistBloc, PlaylistState>(
      bloc: playlistBloc,
      builder: (context, state) {
        bool isLiked = false;
        if (state is PlaylistSuccess) {
          isLiked = state.favouriteSongPaths.contains(song.id);
        }

        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: Colors.white24, size: 20.sp),
          color: AppColors.surface,
          elevation: 8,
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          onSelected: (value) {
            if (value == 'add') {
              _showPlaylistSelector(context, ref);
            } else if (value == 'toggle_fav') {
              playlistBloc.add(ToggleFavouriteEvent(song.id));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_fav',
              child: Row(
                children: [
                  Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                      color: isLiked ? Colors.redAccent : Colors.white70, size: 18.sp),
                  SizedBox(width: 12.w),
                  Text(isLiked ? "Remove Favorite" : "Add to Favorites", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
             PopupMenuItem(
              value: 'add', 
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 18.sp),
                  SizedBox(width: 12.w),
                  Text("Add to Playlist", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistSelector(BuildContext context, WidgetRef ref) {
    final playlistBloc = ref.read(playlistBlocProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
      builder: (sheetContext) => BlocBuilder<PlaylistBloc, PlaylistState>(
        bloc: playlistBloc,
        builder: (context, state) {
          final playlists = state is PlaylistSuccess ? state.playlists : <Playlist>[];
          return Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select Playlist", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                SizedBox(height: 20.h),
                if (playlists.isEmpty)
                  Padding(padding: EdgeInsets.symmetric(vertical: 30.h), child: Center(child: Text("No playlists available", style: TextStyle(color: Colors.white24, fontSize: 13.sp))))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, idx) {
                        final p = playlists[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.playlist_add_rounded, color: AppColors.primary),
                          title: Text(p.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.sp)),
                          onTap: () {
                            playlistBloc.add(AddSongToPlaylistEvent(p.id, song.id));
                            Navigator.pop(sheetContext);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentItem = ref.watch(currentSongProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final handler = ref.watch(audioHandlerProvider);

    if (currentItem == null) return const SizedBox.shrink();
    final playing = playbackState?.playing ?? false;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerScreen()));
      },
      child: Container(
        height: 70.h,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                height: 44.w, width: 44.w,
                color: AppColors.taupeDark.withOpacity(0.1),
                child: Icon(Icons.music_note_rounded, color: AppColors.primary, size: 22.sp),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                  Text(currentItem.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.greyBase.withOpacity(0.5), fontSize: 11.sp)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => playing ? handler.pause() : handler.play(),
              icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, color: AppColors.primary, size: 36.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _TabPersistentHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
