# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# Prevent R8 from stripping interface information
-keep public class * implements io.flutter.plugin.* { *; }

# Para conservar información de depuración
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Reglas adicionales para evitar problemas con la VM de Dart
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.vm.** { *; }
-keep class io.flutter.util.PathUtils { *; }
-keep class io.flutter.plugin.common.** { *; }

# Mantener libapp.so y archivos relacionados
-keep class **.libapp.so { *; }
