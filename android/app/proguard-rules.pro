# Flutter keep rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# CachedNetworkImage / Flutter Cache Manager rules
-keep class com.baseflow.firebase_core.** { *; }
-keep class com.baseflow.pathprovider.** { *; }
-keep class com.baseflow.sqflite.** { *; }
-keep class com.baseflow.sqflite_common.** { *; }

# Prevent R8 from stripping away image decoding classes
-keep class android.graphics.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# Google Play Core (Required for R8 with newer AGP)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }

