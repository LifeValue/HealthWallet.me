# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.

# Suppress warnings for missing classes that are referenced but not used
# These are optional dependencies from MediaPipe that aren't needed for the app

# MediaPipe proto classes (optional, not used in this app)
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

