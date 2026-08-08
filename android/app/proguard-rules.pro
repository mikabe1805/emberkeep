# flutter_local_notifications persists its schedule as Gson-serialized
# generics; R8 stripping generic signatures made the boot receiver throw
# "TypeToken must be created with a type argument" and crash every release
# launch (found on the emulator, 2026-08-06). Keep the signatures and the
# Gson/TypeToken machinery intact.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
