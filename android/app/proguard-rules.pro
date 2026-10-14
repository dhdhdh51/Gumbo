# TrainerApp release shrinking rules.

# Google Play Billing. The in_app_purchase plugin reflects over these classes,
# and R8 would otherwise strip the listener interfaces.
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.api.**

# flutter_local_notifications serialises scheduled notifications with Gson, so
# the model classes and generic signatures have to survive shrinking.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-dontwarn com.dexterous.**

# Referenced by the desugared java.time backport but not present at runtime.
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**
