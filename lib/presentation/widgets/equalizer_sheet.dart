import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/theme/app_colors.dart';
import '../providers/audio_providers.dart';

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  AndroidEqualizer? _equalizer;
  List<AndroidEqualizerBand>? _bands;
  bool _isEnabled = false;
  String _selectedPreset = "Flat";
  
  // State for local message
  String? _message;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _initEqualizer();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _initEqualizer() async {
    final handler = ref.read(audioHandlerProvider) as RhodaAudioHandler;
    _equalizer = handler.equalizer;
    if (_equalizer != null) {
      final parameters = await _equalizer!.parameters;
      _bands = parameters.bands;
      _isEnabled = _equalizer!.enabled;
      setState(() {});
    }
  }

  void _showLocalMessage(String msg) {
    setState(() {
      _message = msg;
    });
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _message = null;
        });
      }
    });
  }

  void _applyPreset(String preset) {
    if (_bands == null) return;

    if (!_isEnabled) {
      _showLocalMessage("Enable the equalizer to use presets");
      return;
    }

    final gains = _getPresetGains(preset);
    for (int i = 0; i < _bands!.length; i++) {
      final double gain = i < gains.length ? gains[i] : 0.0;
      _bands![i].setGain(gain);
    }
    setState(() => _selectedPreset = preset);
  }

  List<double> _getPresetGains(String preset) {
    switch (preset) {
      case "Bass Boost": return [6.0, 4.0, 0.0, 0.0, 0.0];
      case "Rock": return [4.0, 3.0, -1.0, 2.0, 5.0];
      case "Pop": return [-1.0, 2.0, 5.0, 1.0, -2.0];
      case "Electronic": return [5.0, 3.0, 0.0, 3.0, 5.0];
      default: return [0.0, 0.0, 0.0, 0.0, 0.0]; // Flat
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.6.sh,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 30.h),
                    if (_equalizer == null)
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Equalizer is only available on Android",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    else if (_bands == null)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else
                      Expanded(
                        child: Column(
                          children: [
                            _buildPresetSelector(),
                            SizedBox(height: 30.h),
                            Expanded(child: _buildBandSliders()),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _buildMessageOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageOverlay() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      bottom: _message != null ? 30.h : -100.h,
      left: 24.w,
      right: 24.w,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _message != null ? 1.0 : 0.0,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: Colors.white, size: 22.sp),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  _message ?? "",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "EQUALIZER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              "Configure your sound",
              style: TextStyle(color: AppColors.greyBase, fontSize: 12.sp),
            ),
          ],
        ),
        Switch.adaptive(
          value: _isEnabled,
          activeTrackColor: AppColors.primary,
          onChanged: (value) async {
            if (_equalizer != null) {
              await _equalizer!.setEnabled(value);
              setState(() => _isEnabled = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPresetSelector() {
    final presets = ["Flat", "Bass Boost", "Rock", "Pop", "Electronic"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: presets.map((preset) => _PresetChip(
          label: preset,
          isSelected: _selectedPreset == preset,
          onTap: () => _applyPreset(preset),
        )).toList(),
      ),
    );
  }

  Widget _buildBandSliders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _bands!.map((band) => _EqualizerBandSlider(band: band, isEnabled: _isEnabled)).toList(),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.sp,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        showCheckmark: false,
      ),
    );
  }
}

class _EqualizerBandSlider extends StatefulWidget {
  final AndroidEqualizerBand band;
  final bool isEnabled;

  const _EqualizerBandSlider({required this.band, required this.isEnabled});

  @override
  State<_EqualizerBandSlider> createState() => _EqualizerBandSliderState();
}

class _EqualizerBandSliderState extends State<_EqualizerBandSlider> {
  late double _currentGain;

  @override
  void initState() {
    super.initState();
    _currentGain = widget.band.gain;
  }

  @override
  void didUpdateWidget(_EqualizerBandSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.band.gain != _currentGain) {
      setState(() => _currentGain = widget.band.gain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.w,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _currentGain,
                min: -15.0,
                max: 15.0,
                onChanged: widget.isEnabled
                    ? (value) {
                  setState(() => _currentGain = value);
                  widget.band.setGain(value);
                }
                    : null,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          _formatFrequency(widget.band.centerFrequency),
          style: TextStyle(color: AppColors.greyBase, fontSize: 10.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatFrequency(double hz) {
    if (hz >= 1000) {
      return "${(hz / 1000).toStringAsFixed(1)}k";
    }
    return hz.toInt().toString();
  }
}
