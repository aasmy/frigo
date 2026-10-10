# ML Kit text recognition ships optional language models. R8 sees the classes
# for scripts we never call as unused and strips them, which breaks the
# reflective lookup inside the SDK at runtime.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# Only the Latin recogniser is bundled; silence the missing-class warnings for
# the other scripts rather than pulling them all in.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Google Mobile Ads mediation adapters are resolved by name.
-keep class com.google.android.gms.ads.** { *; }

# flutter_local_notifications deserialises scheduled payloads with Gson.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*, Signature
