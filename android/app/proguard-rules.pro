# ONNX Runtime (flutter_onnxruntime) общается с нативной библиотекой через
# JNI: нативный код ищет Java-классы по точным именам. Сжиматель R8 в
# release-сборке переименовывает/удаляет их → краш "java_class == null".
# Запрещаем R8 трогать эти классы.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**