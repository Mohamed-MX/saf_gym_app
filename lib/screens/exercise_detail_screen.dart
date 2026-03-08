import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../blocs/exercise_detail_bloc.dart';
import '../services/muscle_wiki_service.dart';
import '../theme/app_theme.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final MuscleWikiExercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ExerciseDetailBloc()..add(ExerciseDetailLoad(exercise)),
      child: const _ExerciseDetailView(),
    );
  }
}

// ── Video page widget (manages its own VideoPlayerController) ──────────────

// MuscleWiki requires the API key even for media (images & videos)
const Map<String, String> _apiHeaders = {
  'X-API-Key': 'REDACTED_KEY',
};

class _VideoPage extends StatefulWidget {
  final String? videoUrl;
  final String? thumbnailUrl;

  const _VideoPage({
    required this.videoUrl,
    required this.thumbnailUrl,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  // true = video player ready to render
  bool _videoReady = false;
  // true = init finished (success or failure)
  bool _loadDone = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _loadDone = true);
      return;
    }
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _apiHeaders,
      );
      // 12-second timeout — after this we just show the thumbnail
      await ctrl.initialize().timeout(const Duration(seconds: 12));
      ctrl.setLooping(true);
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _videoReady = true;
          _loadDone = true;
        });
      } else {
        ctrl.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _loadDone = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _isPlaying = false;
      } else {
        ctrl.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background: thumbnail (always shown as base layer) ──────
          if (widget.thumbnailUrl != null)
            Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.cover,
              headers: _apiHeaders,
              errorBuilder: (_, e, st) => _fallbackIcon(),
            )
          else
            _fallbackIcon(),

          // ── Video overlay: covers thumbnail once the mp4 is ready ───
          if (_videoReady && _controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),

          // ── Loading spinner: shown only while still initialising ────
          if (!_loadDone)
            Container(
              color: Colors.black.withValues(alpha: 0.30),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // ── Play / pause button overlay ─────────────────────────────
          if (_loadDone)
            AnimatedOpacity(
              opacity: _isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _videoReady
                        ? Icons.play_arrow_rounded
                        : Icons.image_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),

          // (no label badge)
        ],
      ),
    );
  }

  Widget _fallbackIcon() => Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: const Center(
          child: Icon(Icons.fitness_center, size: 80, color: AppTheme.white),
        ),
      );


} // end _VideoPageState

// ── Main detail view ────────────────────────────────────────────────────────


class _ExerciseDetailView extends StatefulWidget {
  const _ExerciseDetailView();

  @override
  State<_ExerciseDetailView> createState() => _ExerciseDetailViewState();
}

class _ExerciseDetailViewState extends State<_ExerciseDetailView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page, int total) {
    if (page < 0 || page >= total) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    context
        .read<ExerciseDetailBloc>()
        .add(ExerciseDetailVideoPageChanged(page));
  }



  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExerciseDetailBloc, ExerciseDetailState>(
      builder: (context, state) {
        if (state is ExerciseDetailInitial) {
          return const Scaffold(
            backgroundColor: AppTheme.offWhite,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }

        if (state is! ExerciseDetailLoaded) return const SizedBox.shrink();

        final exercise = state.exercise;
        final videos = exercise.videos;
        // Use at least one fallback entry so the header always shows something
        final displayVideos = videos.isNotEmpty
            ? videos
            : [
                <String, String?>{
                  'url': exercise.gifUrl,
                  'og_image': exercise.thumbnailUrl,
                  'gender': null,
                  'angle': null,
                }
              ];
        final totalPages = displayVideos.length;
        final currentPage = state.currentVideoPage.clamp(0, totalPages - 1);

        return Scaffold(
          backgroundColor: AppTheme.offWhite,
          body: CustomScrollView(
            slivers: [
              // ── Expandable video carousel header ──────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppTheme.primaryBlue,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.9),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: const [],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── PageView of videos ───────────────────────────
                      PageView.builder(
                        controller: _pageController,
                        itemCount: totalPages,
                        onPageChanged: (page) {
                          context.read<ExerciseDetailBloc>().add(
                                ExerciseDetailVideoPageChanged(page),
                              );
                        },
                        itemBuilder: (_, index) {
                          final v = displayVideos[index];
                          return _VideoPage(
                            videoUrl: v['url'],
                            thumbnailUrl: v['og_image'],
                          );
                        },
                      ),

                      // ── Left arrow (always visible, grey when on page 0)
                      if (totalPages > 1)
                        Positioned(
                          left: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _ArrowButton(
                              icon: Icons.chevron_left_rounded,
                              active: currentPage > 0,
                              onTap: currentPage > 0
                                  ? () => _goToPage(currentPage - 1, totalPages)
                                  : null,
                            ),
                          ),
                        ),

                      // ── Right arrow (always visible, grey when on last page)
                      if (totalPages > 1)
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _ArrowButton(
                              icon: Icons.chevron_right_rounded,
                              active: currentPage < totalPages - 1,
                              onTap: currentPage < totalPages - 1
                                  ? () => _goToPage(currentPage + 1, totalPages)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Muscle / Difficulty badges ──────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (exercise.muscleSlug != null)
                            _badge(
                              MuscleWikiService.muscleDisplayNames[
                                      exercise.muscleSlug] ??
                                  exercise.muscleSlug!,
                              AppTheme.primaryBlue,
                              AppTheme.white,
                            ),
                          if (exercise.difficulty != null)
                            _badge(
                              exercise.difficulty!,
                              AppTheme.primaryBlue.withValues(alpha: 0.1),
                              AppTheme.primaryBlue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Name ────────────────────────────────────────
                      Text(
                        exercise.name,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Target Muscles ──────────────────────────────
                      if (exercise.primaryMuscles.isNotEmpty) ...[
                        _sectionTitle('Target Muscles'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              exercise.primaryMuscles.map((muscle) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull),
                                border: Border.all(
                                  color: AppTheme.primaryBlue
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle,
                                      size: 8,
                                      color: AppTheme.primaryBlue),
                                  const SizedBox(width: 8),
                                  Text(
                                    muscle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Equipment ───────────────────────────────────
                      if (exercise.category != null &&
                          exercise.category!.isNotEmpty) ...[
                        _sectionTitle('Equipment'),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm),
                                ),
                                child: const Icon(
                                  Icons.fitness_center,
                                  color: AppTheme.primaryBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                exercise.category!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.charcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Instructions (Steps) ────────────────────────
                      if (exercise.steps.isNotEmpty) ...[
                        _sectionTitle('Instructions'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: exercise.steps
                                .asMap()
                                .entries
                                .map((entry) {
                              final stepNum = entry.key + 1;
                              final stepText = entry.value;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      margin: const EdgeInsets.only(
                                          top: 1, right: 14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryBlue,
                                            AppTheme.primaryBlue
                                                .withValues(alpha: 0.75),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$stepNum',
                                          style: const TextStyle(
                                            color: AppTheme.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        stepText,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          height: 1.6,
                                          color: AppTheme.darkGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}

// ── Reusable carousel arrow button ─────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  const _ArrowButton({
    required this.icon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? Colors.black.withValues(alpha: 0.50)
              : Colors.black.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active
              ? Colors.white
              : Colors.white.withValues(alpha: 0.30),
          size: 28,
        ),
      ),
    );
  }
}

