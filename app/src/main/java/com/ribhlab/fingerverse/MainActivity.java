package com.ribhlab.fingerverse;

import android.app.Activity;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.biometrics.BiometricPrompt;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.Locale;

public class MainActivity extends Activity implements SensorEventListener {
    private SensorManager sensors;
    private Sensor motionSensor;
    private GLSurfaceView surface;
    private WorldRenderer world;
    private TextView status;
    private TextView hint;
    private TextView worldId;
    private int evolutions = 0;
    private boolean awakened = false;

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);

        world = new WorldRenderer();
        surface = new GLSurfaceView(this);
        surface.setEGLContextClientVersion(2);
        surface.setRenderer(world);
        surface.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(3, 7, 24));
        root.addView(surface, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.VERTICAL);
        top.setPadding(dp(22), dp(34), dp(22), dp(18));
        GradientDrawable shadow = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xDD050819, 0x00050819});
        top.setBackground(shadow);

        TextView brand = label("FINGERVERSE", 31, 0xFFB8EDFF, true);
        brand.setLetterSpacing(0.12f);
        top.addView(brand);
        TextView slogan = label("TOUCH   •   CREATE   •   EVOLVE", 11, 0xFF7B93C7, true);
        slogan.setLetterSpacing(0.13f);
        top.addView(slogan);
        worldId = label("SECTOR 00   /   UNDISCOVERED", 12, 0xFFA9F6FF, false);
        LinearLayout.LayoutParams worldIdParams = new LinearLayout.LayoutParams(-1, -2);
        worldIdParams.topMargin = dp(23);
        top.addView(worldId, worldIdParams);
        FrameLayout.LayoutParams tp = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        root.addView(top, tp);

        LinearLayout bottom = new LinearLayout(this);
        bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setPadding(dp(22), dp(40), dp(22), dp(30));
        bottom.setBackground(new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP,
                new int[]{0xF204091B, 0x0004091B}));

        status = label("YOUR WORLD IS DORMANT", 19, Color.WHITE, true);
        status.setGravity(Gravity.CENTER);
        bottom.addView(status);
        hint = label("A fingerprint can awaken a universe.\nTilt your phone to reshape gravity.", 13,
                0xFF9DB1D4, false);
        hint.setGravity(Gravity.CENTER);
        hint.setLineSpacing(dp(4), 1f);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(-1, -2);
        hp.topMargin = dp(10);
        hp.bottomMargin = dp(22);
        bottom.addView(hint, hp);

        TextView unlock = button("✦   AWAKEN WITH FINGERPRINT", 0xFF1559A9, 0xFF3EE5FF);
        bottom.addView(unlock, new LinearLayout.LayoutParams(-1, dp(56)));
        unlock.setOnClickListener(v -> authenticate());

        TextView demo = button("TRY DEMO WITHOUT BIOMETRICS", 0xFF121C3B, 0xFF9DAFD4);
        LinearLayout.LayoutParams dp = new LinearLayout.LayoutParams(-1, dp(45));
        dp.topMargin = dp(10);
        bottom.addView(demo, dp);
        demo.setOnClickListener(v -> evolve(false));

        FrameLayout.LayoutParams bp = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        root.addView(bottom, bp);
        setContentView(root);

        sensors = (SensorManager) getSystemService(SENSOR_SERVICE);
        motionSensor = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY);
        if (motionSensor == null) motionSensor = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (motionSensor == null) hint.setText("Motion sensor unavailable.\nUse the fingerprint to evolve your world.");
    }

    private TextView label(String value, int size, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(value);
        t.setTextSize(size);
        t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        return t;
    }

    private TextView button(String value, int background, int outline) {
        TextView b = label(value, 13, Color.WHITE, true);
        b.setGravity(Gravity.CENTER);
        b.setLetterSpacing(0.05f);
        GradientDrawable g = new GradientDrawable();
        g.setColor(background);
        g.setCornerRadius(dp(17));
        g.setStroke(dp(1), outline);
        b.setBackground(g);
        return b;
    }

    private int dp(float value) { return (int)(value * getResources().getDisplayMetrics().density + .5f); }

    private void authenticate() {
        try {
            BiometricPrompt prompt = new BiometricPrompt.Builder(this)
                    .setTitle("Awaken your world")
                    .setSubtitle("Confirm your fingerprint to open the portal")
                    .setNegativeButton("CANCEL", getMainExecutor(), (dialog, which) ->
                            status.setText("PORTAL CLOSED"))
                    .build();
            prompt.authenticate(new CancellationSignal(), getMainExecutor(),
                    new BiometricPrompt.AuthenticationCallback() {
                        @Override public void onAuthenticationSucceeded(
                                BiometricPrompt.AuthenticationResult result) {
                            evolve(true);
                        }
                        @Override public void onAuthenticationError(int errorCode, CharSequence message) {
                            status.setText("BIOMETRICS UNAVAILABLE");
                            hint.setText(message + "\nYou can still try the labeled demo.");
                        }
                        @Override public void onAuthenticationFailed() {
                            status.setText("FINGERPRINT NOT RECOGNIZED");
                        }
                    });
        } catch (Exception error) {
            status.setText("BIOMETRIC PROMPT NOT READY");
            hint.setText("Enroll a fingerprint in Android settings.\nDemo mode remains available.");
        }
    }

    private void evolve(boolean verified) {
        awakened = true;
        evolutions++;
        world.awaken(evolutions);
        status.setText(verified ? "✦   WORLD AWAKENED   ✦" : "✦   DEMO WORLD ACTIVE   ✦");
        hint.setText("Tilt the phone to bend orbital gravity.\nAuthenticate again to create another universe.");
        worldId.setText(String.format(Locale.US, "SECTOR %02d   /   %s",
                evolutions, verified ? "BIOMETRIC GATE VERIFIED" : "PREVIEW MODE"));
    }

    @Override public void onSensorChanged(SensorEvent event) {
        if (event.sensor == motionSensor) world.setGravity(event.values[0], event.values[1]);
    }
    @Override public void onAccuracyChanged(Sensor sensor, int accuracy) { }
    @Override protected void onResume() {
        super.onResume();
        if (surface != null) surface.onResume();
        if (sensors != null && motionSensor != null)
            sensors.registerListener(this, motionSensor, SensorManager.SENSOR_DELAY_GAME);
    }
    @Override protected void onPause() {
        if (sensors != null) sensors.unregisterListener(this);
        if (surface != null) surface.onPause();
        super.onPause();
    }
}