# Just Audio and Audio Service
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.just_audio.**
-dontwarn com.ryanheise.audioservice.**

# Android Media and Audio Effects
-keep class android.media.audiofx.** { *; }
-keep class android.media.MediaPlayer { *; }
-keep class android.media.AudioTrack { *; }
-keep class android.media.AudioAttributes { *; }
-keep class android.media.audiofx.Equalizer { *; }
-keep class android.media.audiofx.AudioEffect { *; }

# Flutter Platform Channels
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
