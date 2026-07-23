# R8 / ProGuard rules for Zyntro.
#
# IMPORTANT: do NOT add blanket `-keep class <pkg>.** { *; }` rules here.
# Firebase, Play Services, AndroidX, OkHttp, Stripe, Facebook, Gson and the
# Flutter embedding all ship their own consumer rules inside their AARs, so
# app-level keeps are redundant — and a blanket keep disables shrinking,
# obfuscation AND optimization for everything it matches. That is what drove
# Play Console's "App optimization: Low" with blank percentages.
#
# Only add a rule here when something is reached reflectively / from JNI /
# from the manifest, and scope it as narrowly as possible.

# ─── Warning suppression ──────────────────────────────────────────────────────
# These do not affect optimization; they only silence references to classes that
# are absent at compile time (optional transitive deps).
-dontwarn com.google.guava.**
-dontwarn com.google.common.**
-dontwarn com.google.errorprone.**
-dontwarn com.google.j2objc.**
-dontwarn org.codehaus.mojo.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Stripe optional push-provisioning module is not bundled.
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# ─── Attributes ───────────────────────────────────────────────────────────────
# Signature + annotations are required for reflection over generic types
# (Gson/Firestore deserialization). SourceFile/LineNumberTable keep crash
# traces deobfuscatable via the mapping file Play receives with the bundle;
# renaming the source file attribute keeps the class names themselves hidden.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ─── Reflection-reached members ───────────────────────────────────────────────
# Enum name/valueOf lookups (used by switch + serialization).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable creators are looked up reflectively by the framework.
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Java serialization hooks.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# JNI entry points.
-keepclasseswithmembernames class * {
    native <methods>;
}

# ─── Gson ─────────────────────────────────────────────────────────────────────
# Generic TypeToken subtypes are resolved reflectively; the signature attribute
# above does the rest. Model classes themselves need no keep because Flutter
# code does not deserialize Java models via Gson.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
