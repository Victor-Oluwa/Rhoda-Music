import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        child: Scaffold(
          resizeToAvoidBottomInset: false, // Prevents layout shifts when keyboard appears
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: BackgroundPainter(),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildSearchBar(context),
                    if (!_isSearchActive) ...[
                      _buildQuickActions(),
                      SizedBox(height: 20.h),
                      _buildTabMenu(),
                    ],
                    Expanded(
                      child: _isSearchActive
                          ? _SearchResultsView()
                          : TabBarView(
                              controller: _tabController,
                              physics: const BouncingScrollPhysics(),
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
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: const MiniPlayer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome To",
                style: TextStyle(
                  color: AppColors.greyBase.withValues(alpha: 0.6),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "Rhoda Music",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          _buildCircleButton(
            icon: Icons.refresh_rounded,
            onPressed: () => _scannerBloc.add(ScanMusicEvent()),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
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
            
            for (var path in playlistState.recentSongPaths) {
              try {
                final song = scannerState.songs.firstWhere((s) => s.id == path);
                recentSongs.add(song);
              } catch (_) {}
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(top: 10.h),
          child: SizedBox(
            height: 120.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFeaturedCard(),
                SizedBox(width: 16.w),
                _buildActionCard(
                  title: "Favorites",
                  subtitle: "$favCount tracks",
                  icon: Icons.favorite_rounded,
                  color: Colors.redAccent,
                  onTap: () {
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
                  onTap: () {
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

  Widget _buildFeaturedCard() {
    return GestureDetector(
      onTap: () async {
        final handler = ref.read(audioHandlerProvider) as RhodaAudioHandler;
        final victorSong = const Song(
          id: 'asset:///assets/music/victor_track.mp3',
          title: 'Candle Light',
          artist: 'Victor Special',
          album: 'Asset Collection',
          duration: Duration(seconds: 33),
          path: 'asset:///assets/music/victor_track.mp3',
        );
        await handler.setQueueAndPlay([victorSong.toMediaItem()], 0);
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerScreen()));
        }
      },
      child: Container(
        width: 240.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.taupeDark.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(Icons.music_note_rounded, size: 120.sp, color: Colors.white.withValues(alpha: 0.1)),
            ),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      "THE FOUNDATION",
                      style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "VICTOR SPECIAL",
                    style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "CANDLE LIGHT",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ],
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
        width: 110.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white38, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabMenu() {
    return Container(
      height: 40.h,
      margin: EdgeInsets.only(bottom: 10.h),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.greyBase.withValues(alpha: 0.4),
        labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        tabs: const [
          Tab(text: "Songs"),
          Tab(text: "Playlists"),
          Tab(text: "Artists"),
          Tab(text: "Albums"),
          Tab(text: "Genres"),
          Tab(text: "Folders"),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 22.sp),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 54.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: _isSearchActive ? AppColors.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                final scannerState = _scannerBloc.state;
                if (scannerState is MusicScannerSuccess) {
                  _searchBloc.add(SearchQueryChangedEvent(value, scannerState.songs));
                }
              },
              onTap: () => setState(() => _isSearchActive = true),
              style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w500),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: "Search track, artist...",
                hintStyle: TextStyle(color: AppColors.greyBase.withValues(alpha: 0.4), fontSize: 14.sp),
                prefixIcon: Icon(Icons.search_rounded, color: _isSearchActive ? AppColors.primary : AppColors.greyBase.withValues(alpha: 0.4), size: 22.sp),
                suffixIcon: _isSearchActive
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _searchBloc.add(ClearSearchEvent());
                          setState(() => _isSearchActive = false);
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14.h),
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

class _BeautifulLoaderState extends State<_BeautifulLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                turns: _controller,
                child: Container(
                  width: 60.w, height: 60.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 4),
                  ),
                ),
              ),
              RotationTransition(
                turns: Tween(begin: 1.0, end: 0.0).animate(_controller),
                child: SizedBox(
                  width: 60.w, height: 60.w,
                  child: CircularProgressIndicator(
                    value: 0.3,
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Icon(Icons.music_note_rounded, color: AppColors.primary, size: 24.sp),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            "SYNCING LIBRARY...",
            style: TextStyle(
              color: AppColors.greyBase.withValues(alpha: 0.5),
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
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
          return Center(child: Text("Start searching...", style: TextStyle(color: AppColors.greyBase.withValues(alpha: 0.5))));
        }
        if (state.isSearching) {
          return const _BeautifulLoader();
        }
        if (state.searchResults.isEmpty) {
          return Center(child: Text("No results found", style: TextStyle(color: AppColors.greyBase)));
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 100.h),
          itemCount: state.searchResults.length,
          itemBuilder: (context, index) => _SongTile(song: state.searchResults[index], songs: state.searchResults, index: index),
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
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 100.h),
            itemCount: state.songs.length,
            itemBuilder: (context, index) => _SongTile(song: state.songs[index], songs: state.songs, index: index),
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
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 100.h),
          children: [
            _buildCreatePlaylistButton(context, playlistBloc),
            SizedBox(height: 20.h),
            if (playlists.isEmpty)
              Center(child: Text("Empty Library", style: TextStyle(color: AppColors.greyBase.withValues(alpha: 0.3))))
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
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22.sp),
            SizedBox(width: 10.w),
            Text("Create New Playlist", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14.sp)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: const Text("New Playlist", style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter name",
            hintStyle: TextStyle(color: Colors.white24),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                bloc.add(CreatePlaylistEvent(controller.text));
                Navigator.pop(ctx);
              }
            },
            child: const Text("CREATE", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: Container(
          width: 54.w,
          height: 54.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 28.sp),
        ),
        title: Text(playlist.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
        subtitle: Text("${playlist.songPaths.length} tracks", style: TextStyle(color: AppColors.greyBase, fontSize: 12.sp)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: Colors.white24, size: 20.sp),
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
        if (keys.isEmpty) return Center(child: Text("Nothing here yet", style: TextStyle(color: AppColors.greyBase.withValues(alpha: 0.3))));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 100.h),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final key = keys[index];
            final songs = data[key]!;
            return Container(
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                leading: Container(
                  width: 54.w, height: 54.w,
                  decoration: BoxDecoration(
                    color: AppColors.taupeDark.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(_getIcon(), color: AppColors.taupeLight, size: 26.sp),
                ),
                title: Text(key, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
                subtitle: Text("${songs.length} tracks", style: TextStyle(color: AppColors.greyBase, fontSize: 12.sp)),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.white12),
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

class _SongTile extends ConsumerWidget {
  final Song song;
  final List<Song>? songs;
  final int? index;
  const _SongTile({required this.song, this.songs, this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        onTap: () async {
          // Explicitly dismiss keyboard before navigation to prevent overflow/screen tear
          FocusScope.of(context).unfocus();
          
          final handler = ref.read(audioHandlerProvider) as RhodaAudioHandler;
          final queue = songs ?? [song];
          await handler.setQueueAndPlay(queue.map((s) => s.toMediaItem()).toList(), index ?? 0);
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerScreen()));
          }
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            height: 52.w, width: 52.w,
            color: AppColors.taupeDark.withValues(alpha: 0.2),
            child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
          ),
        ),
        title: Text(song.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(song.artist, style: TextStyle(color: AppColors.greyBase, fontSize: 11.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          icon: Icon(Icons.more_horiz_rounded, color: Colors.white24),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          onSelected: (value) {
            if (value == 'add') {
              _showPlaylistSelector(context, ref);
            } else if (value == 'toggle_fav') {
              playlistBloc.add(ToggleFavouriteEvent(song.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isLiked ? "Removed from Favorites" : "Added to Favorites"),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_fav',
              child: Row(
                children: [
                  Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                      color: isLiked ? Colors.redAccent : Colors.white70, size: 20),
                  SizedBox(width: 10.w),
                  Text(isLiked ? "Remove Favorite" : "Add to Favorites", style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
             PopupMenuItem(
              value: 'add', 
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 10.w),
                  Text("Add to Playlist", style: TextStyle(fontSize: 13)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
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
                Text("Add to Playlist", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
                SizedBox(height: 20.h),
                if (playlists.isEmpty)
                  Padding(padding: EdgeInsets.symmetric(vertical: 20.h), child: Center(child: Text("No playlists", style: TextStyle(color: Colors.white24))))
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
                          title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          onTap: () {
                            playlistBloc.add(AddSongToPlaylistEvent(p.id, song.id));
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added to ${p.name}"), backgroundColor: AppColors.primary));
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
        height: 72.h,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 25, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                height: 48.w, width: 48.w,
                color: AppColors.taupeDark.withValues(alpha: 0.2),
                child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  Text(currentItem.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.greyBase, fontSize: 11.sp)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => playing ? handler.pause() : handler.play(),
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.primary, size: 32.sp),
            ),
          ],
        ),
      ),
    );
  }
}
