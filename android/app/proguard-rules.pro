# google_mlkit_text_recognition references every script-specific recognizer,
# but the app only uses TextRecognitionScript.latin. Suppress R8 warnings for
# the optional language models that are not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# FFmpegKit is invoked through JNI, so R8 must keep its bridge classes.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.arthenica.ffmpegkit.**
