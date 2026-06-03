# ─── Flutter / Dart ───────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase core & Auth ─────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ─── Google Play Services (GMS) ───────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Play Core / Play Integrity (Firebase App Check prod provider) ────────────
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

# ─── OkHttp / OkIO (Firebase network layer) ───────────────────────────────────
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── Kotlin ───────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ─── AndroidX ─────────────────────────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**

# ─── Facebook Auth ────────────────────────────────────────────────────────────
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# ─── Stripe ───────────────────────────────────────────────────────────────────
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# ─── Tink (Firebase crypto internals) ────────────────────────────────────────
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ─── Guava / Errorprone (Firebase transitive deps) ────────────────────────────
-dontwarn com.google.guava.**
-dontwarn com.google.common.**
-dontwarn com.google.errorprone.**
-dontwarn com.google.j2objc.**
-dontwarn org.codehaus.mojo.**

# ─── Gson ─────────────────────────────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }
-keep class sun.misc.Unsafe { *; }

# ─── Reflection / Generic type signatures ─────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable

# ─── Enums (R8 can strip their names used in switch expressions) ──────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ─── Parcelable ───────────────────────────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# ─── Serializable ─────────────────────────────────────────────────────────────
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ─── Native methods ───────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}
