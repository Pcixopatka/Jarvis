package com.kozatska.kzads;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.rewarded.RewardItem;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.FormError;
import com.google.android.ump.UserMessagingPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Minimal Google AdMob rewarded ads for the game (Godot singleton "KzAds").
 * Consent goes through Google's User Messaging Platform before the SDK starts.
 * Every SDK call runs on the host (UI) thread; signals are queued to the Godot thread by emitSignal.
 */
public class KzAdsPlugin extends GodotPlugin {
    private static final String TAG = "KzAds";

    // Error codes of our own (the SDK's codes are 0 and up).
    private static final int ERR_NO_ACTIVITY = -1;
    private static final int ERR_NO_CONSENT = -2;
    private static final int ERR_NOT_READY = -3;
    private static final int ERR_EXCEPTION = -4;

    private static final SignalInfo INITIALIZED = new SignalInfo("initialized", Boolean.class);
    private static final SignalInfo LOADED = new SignalInfo("rewarded_loaded");
    private static final SignalInfo FAILED_TO_LOAD = new SignalInfo("rewarded_failed_to_load", Integer.class, String.class);
    private static final SignalInfo SHOWN = new SignalInfo("rewarded_shown");
    private static final SignalInfo EARNED = new SignalInfo("rewarded_earned", String.class, Integer.class);
    private static final SignalInfo DISMISSED = new SignalInfo("rewarded_dismissed");
    private static final SignalInfo FAILED_TO_SHOW = new SignalInfo("rewarded_failed_to_show", Integer.class, String.class);

    private final AtomicBoolean consentStarted = new AtomicBoolean(false);
    private final AtomicBoolean sdkStarted = new AtomicBoolean(false);
    private volatile boolean testMode = false;
    private volatile boolean loading = false;
    private volatile boolean privacyRequired = false;
    // Only touched on the UI thread; one ad object at a time.
    private RewardedAd rewardedAd = null;
    private volatile boolean adReady = false;
    private ConsentInformation consentInformation = null;

    public KzAdsPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "KzAds";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(INITIALIZED);
        signals.add(LOADED);
        signals.add(FAILED_TO_LOAD);
        signals.add(SHOWN);
        signals.add(EARNED);
        signals.add(DISMISSED);
        signals.add(FAILED_TO_SHOW);
        return signals;
    }

    /** Gathers consent (UMP), then starts the Mobile Ads SDK. Emits initialized(canRequestAds). */
    @UsedByGodot
    public void init(boolean testMode) {
        this.testMode = testMode;
        if (!consentStarted.compareAndSet(false, true)) {
            emitSignal(INITIALIZED.getName(), canRequestAds());
            return;
        }
        runOnHostThread(() -> {
            Activity activity = getActivity();
            if (activity == null || activity.isFinishing()) {
                consentStarted.set(false);
                emitSignal(INITIALIZED.getName(), false);
                return;
            }
            try {
                consentInformation = UserMessagingPlatform.getConsentInformation(activity);
                ConsentRequestParameters params = new ConsentRequestParameters.Builder().build();
                consentInformation.requestConsentInfoUpdate(activity, params,
                        () -> {
                            Activity a = getActivity();
                            if (a == null || a.isFinishing()) {
                                startSdk();
                                return;
                            }
                            UserMessagingPlatform.loadAndShowConsentFormIfRequired(a, (FormError formError) -> {
                                if (formError != null) {
                                    Log.w(TAG, "Consent form: " + formError.getErrorCode() + " " + formError.getMessage());
                                }
                                startSdk();
                            });
                        },
                        (FormError requestError) -> {
                            // Offline or misconfigured: an earlier consent may still allow ads.
                            Log.w(TAG, "Consent info update: " + requestError.getErrorCode() + " " + requestError.getMessage());
                            startSdk();
                        });
            } catch (Exception e) {
                Log.e(TAG, "init", e);
                startSdk();
            }
        });
    }

    // Runs on the UI thread (consent callbacks come there).
    private void startSdk() {
        updatePrivacyStatus();
        boolean can = canRequestAds();
        if (!can) {
            emitSignal(INITIALIZED.getName(), false);
            return;
        }
        if (!sdkStarted.compareAndSet(false, true)) {
            emitSignal(INITIALIZED.getName(), true);
            return;
        }
        Activity activity = getActivity();
        if (activity == null) {
            sdkStarted.set(false);
            emitSignal(INITIALIZED.getName(), false);
            return;
        }
        if (testMode) {
            Log.i(TAG, "Test mode: the game asks for Google's sample ad unit");
        }
        try {
            MobileAds.initialize(activity.getApplicationContext(), status -> emitSignal(INITIALIZED.getName(), true));
        } catch (Exception e) {
            Log.e(TAG, "MobileAds.initialize", e);
            sdkStarted.set(false);
            emitSignal(INITIALIZED.getName(), false);
        }
    }

    private boolean canRequestAds() {
        ConsentInformation info = consentInformation;
        return info != null && info.canRequestAds();
    }

    private void updatePrivacyStatus() {
        ConsentInformation info = consentInformation;
        privacyRequired = info != null
                && info.getPrivacyOptionsRequirementStatus() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
    }

    /** Loads one rewarded ad. Ignored while one is loading or ready. */
    @UsedByGodot
    public void loadRewarded(String unitId) {
        runOnHostThread(() -> {
            if (loading || rewardedAd != null) {
                return;
            }
            if (!sdkStarted.get() || !canRequestAds()) {
                emitSignal(FAILED_TO_LOAD.getName(), ERR_NO_CONSENT, "Ads can not be requested yet");
                return;
            }
            Activity activity = getActivity();
            if (activity == null || unitId == null || unitId.isEmpty()) {
                emitSignal(FAILED_TO_LOAD.getName(), ERR_NO_ACTIVITY, "No activity or ad unit");
                return;
            }
            loading = true;
            try {
                RewardedAd.load(activity, unitId, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
                    @Override
                    public void onAdLoaded(@NonNull RewardedAd ad) {
                        loading = false;
                        rewardedAd = ad;
                        adReady = true;
                        emitSignal(LOADED.getName());
                    }

                    @Override
                    public void onAdFailedToLoad(@NonNull LoadAdError error) {
                        loading = false;
                        rewardedAd = null;
                        adReady = false;
                        emitSignal(FAILED_TO_LOAD.getName(), error.getCode(), String.valueOf(error.getMessage()));
                    }
                });
            } catch (Exception e) {
                loading = false;
                Log.e(TAG, "RewardedAd.load", e);
                emitSignal(FAILED_TO_LOAD.getName(), ERR_EXCEPTION, String.valueOf(e.getMessage()));
            }
        });
    }

    @UsedByGodot
    public boolean isRewardedReady() {
        return adReady;
    }

    /** Shows the loaded ad. Ends with rewarded_dismissed or rewarded_failed_to_show. */
    @UsedByGodot
    public void showRewarded() {
        runOnHostThread(() -> {
            RewardedAd ad = rewardedAd;
            Activity activity = getActivity();
            if (ad == null) {
                emitSignal(FAILED_TO_SHOW.getName(), ERR_NOT_READY, "No ad loaded");
                return;
            }
            if (activity == null || activity.isFinishing()) {
                emitSignal(FAILED_TO_SHOW.getName(), ERR_NO_ACTIVITY, "No activity");
                return;
            }
            // An ad object is shown once: the next one is loaded after this one is gone.
            rewardedAd = null;
            adReady = false;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdShowedFullScreenContent() {
                    emitSignal(SHOWN.getName());
                }

                @Override
                public void onAdDismissedFullScreenContent() {
                    emitSignal(DISMISSED.getName());
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    emitSignal(FAILED_TO_SHOW.getName(), error.getCode(), String.valueOf(error.getMessage()));
                }
            });
            try {
                ad.show(activity, (RewardItem reward) ->
                        emitSignal(EARNED.getName(), String.valueOf(reward.getType()), reward.getAmount()));
            } catch (Exception e) {
                Log.e(TAG, "RewardedAd.show", e);
                emitSignal(FAILED_TO_SHOW.getName(), ERR_EXCEPTION, String.valueOf(e.getMessage()));
            }
        });
    }

    /** Whether the user must be offered a way to change consent (EEA, UK and similar regions). */
    @UsedByGodot
    public boolean privacyOptionsRequired() {
        return privacyRequired;
    }

    /** Opens the UMP privacy options form. */
    @UsedByGodot
    public void showPrivacyOptions() {
        runOnHostThread(() -> {
            Activity activity = getActivity();
            if (activity == null || activity.isFinishing()) {
                return;
            }
            try {
                UserMessagingPlatform.showPrivacyOptionsForm(activity, (FormError formError) -> {
                    if (formError != null) {
                        Log.w(TAG, "Privacy options form: " + formError.getErrorCode() + " " + formError.getMessage());
                    }
                    updatePrivacyStatus();
                });
            } catch (Exception e) {
                Log.e(TAG, "showPrivacyOptionsForm", e);
            }
        });
    }
}
