package com.osmii.musicvault;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.MenuItem;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.TextView;
import android.widget.Toast;

public final class MainActivity extends Activity {
    private static final String PREFS = "music_vault_car";
    private static final String KEY_URL = "server_url";
    private static final String DEFAULT_URL = "http://100.83.43.110:8788/";
    private static final String TAILSCALE_PACKAGE = "com.tailscale.ipn";

    private FrameLayout root;
    private WebView webView;
    private View errorPanel;
    private TextView errorText;
    private String serverUrl;

    @SuppressLint({"SetJavaScriptEnabled", "ClickableViewAccessibility"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setImmersiveMode();

        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        serverUrl = normalizeUrl(prefs.getString(KEY_URL, DEFAULT_URL));

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(8, 9, 12));

        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(8, 9, 12));
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setLoadsImagesAutomatically(true);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);

        CookieManager cookies = CookieManager.getInstance();
        cookies.setAcceptCookie(true);
        cookies.setAcceptThirdPartyCookies(webView, true);

        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String scheme = uri.getScheme() == null ? "" : uri.getScheme();
                if ("mailto".equalsIgnoreCase(scheme) || "tel".equalsIgnoreCase(scheme)) {
                    try {
                        startActivity(new Intent(Intent.ACTION_VIEW, uri));
                    } catch (ActivityNotFoundException ignored) {
                        Toast.makeText(MainActivity.this, "No app is available for that link.", Toast.LENGTH_SHORT).show();
                    }
                    return true;
                }
                return false;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                hideError();
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request != null && request.isForMainFrame()) {
                    showError("Music Vault could not connect. Make sure Tailscale is connected and your CasaOS server is online.");
                }
            }

            @Override
            public void onReceivedHttpError(WebView view, WebResourceRequest request, android.webkit.WebResourceResponse response) {
                if (request != null && request.isForMainFrame() && response.getStatusCode() >= 500) {
                    showError("Music Vault server returned HTTP " + response.getStatusCode() + ".");
                }
            }
        });

        webView.setDownloadListener((url, userAgent, contentDisposition, mimeType, contentLength) -> {
            try {
                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                startActivity(intent);
            } catch (ActivityNotFoundException ignored) {
                Toast.makeText(this, "No app can open this download.", Toast.LENGTH_SHORT).show();
            }
        });

        root.addView(webView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        buildErrorPanel();
        addMenuButton();

        setContentView(root);
        loadMusicVault();
    }

    private void buildErrorPanel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER);
        panel.setPadding(dp(28), dp(20), dp(28), dp(20));
        panel.setBackgroundColor(Color.rgb(8, 9, 12));

        TextView title = new TextView(this);
        title.setText("MUSIC VAULT");
        title.setTextColor(Color.rgb(217, 189, 122));
        title.setTextSize(22);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        title.setGravity(Gravity.CENTER);

        errorText = new TextView(this);
        errorText.setText("Connecting to your music library…");
        errorText.setTextColor(Color.WHITE);
        errorText.setTextSize(15);
        errorText.setGravity(Gravity.CENTER);
        errorText.setPadding(0, dp(14), 0, dp(18));

        Button retry = makeButton("RETRY");
        retry.setOnClickListener(v -> loadMusicVault());

        Button tailscale = makeButton("OPEN TAILSCALE");
        tailscale.setOnClickListener(v -> openTailscale());

        Button address = makeButton("SERVER ADDRESS");
        address.setOnClickListener(v -> editServerAddress());

        panel.addView(title);
        panel.addView(errorText);
        panel.addView(retry);
        panel.addView(tailscale);
        panel.addView(address);

        errorPanel = panel;
        errorPanel.setVisibility(View.GONE);
        root.addView(errorPanel, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
    }

    private void addMenuButton() {
        TextView menu = new TextView(this);
        menu.setText("⋮");
        menu.setTextColor(Color.WHITE);
        menu.setTextSize(27);
        menu.setGravity(Gravity.CENTER);
        menu.setBackgroundColor(0x990D0F14);
        menu.setPadding(dp(8), 0, dp(8), dp(2));
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(dp(42), dp(44), Gravity.TOP | Gravity.RIGHT);
        params.setMargins(0, dp(5), dp(5), 0);
        root.addView(menu, params);
        menu.setOnClickListener(v -> {
            PopupMenu popup = new PopupMenu(this, menu);
            popup.getMenu().add("Reload Music Vault").setOnMenuItemClickListener(item -> {
                loadMusicVault();
                return true;
            });
            popup.getMenu().add("Change server address").setOnMenuItemClickListener(item -> {
                editServerAddress();
                return true;
            });
            popup.getMenu().add("Open Tailscale").setOnMenuItemClickListener(item -> {
                openTailscale();
                return true;
            });
            popup.getMenu().add("About Music Vault").setOnMenuItemClickListener(item -> {
                new AlertDialog.Builder(this)
                    .setTitle("Music Vault")
                    .setMessage("Car Screen App 1.0.0\nConnects to your private Music Vault server. App content updates from the server.")
                    .setPositiveButton("OK", null)
                    .show();
                return true;
            });
            popup.show();
        });
    }

    private Button makeButton(String label) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextColor(Color.rgb(15, 16, 18));
        button.setTextSize(13);
        button.setAllCaps(false);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setBackgroundTintList(android.content.res.ColorStateList.valueOf(Color.rgb(217, 189, 122)));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, dp(48));
        params.setMargins(dp(5), dp(5), dp(5), dp(5));
        button.setLayoutParams(params);
        return button;
    }

    private void showError(String message) {
        if (errorText != null) errorText.setText(message);
        if (errorPanel != null) errorPanel.setVisibility(View.VISIBLE);
    }

    private void hideError() {
        if (errorPanel != null) errorPanel.setVisibility(View.GONE);
    }

    private void loadMusicVault() {
        if (webView == null) return;
        hideError();
        webView.loadUrl(serverUrl);
    }

    private void editServerAddress() {
        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setText(serverUrl);
        input.setSelectAllOnFocus(true);
        input.setHint("http://your-server:8788/");
        new AlertDialog.Builder(this)
            .setTitle("Music Vault server")
            .setMessage("Enter the address of your Music Vault server.")
            .setView(input)
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Save", (dialog, which) -> {
                String value = normalizeUrl(input.getText().toString());
                if (value == null) {
                    Toast.makeText(this, "Enter a valid http or https address.", Toast.LENGTH_LONG).show();
                    return;
                }
                serverUrl = value;
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_URL, serverUrl).apply();
                loadMusicVault();
            })
            .show();
    }

    private String normalizeUrl(String value) {
        if (value == null) return null;
        String url = value.trim();
        if (url.isEmpty()) return null;
        if (!url.matches("(?i)^https?://.+")) url = "http://" + url;
        if (!url.endsWith("/")) url += "/";
        Uri uri = Uri.parse(url);
        if (uri.getHost() == null || (!"http".equalsIgnoreCase(uri.getScheme()) && !"https".equalsIgnoreCase(uri.getScheme()))) return null;
        return url;
    }

    private void openTailscale() {
        try {
            Intent launch = getPackageManager().getLaunchIntentForPackage(TAILSCALE_PACKAGE);
            if (launch == null) {
                Toast.makeText(this, "Install or open Tailscale, connect to your network, then return to Music Vault.", Toast.LENGTH_LONG).show();
            } else {
                startActivity(launch);
            }
        } catch (Exception ex) {
            Toast.makeText(this, "Open Tailscale and connect, then return to Music Vault.", Toast.LENGTH_LONG).show();
        }
    }

    private void setImmersiveMode() {
        Window window = getWindow();
        window.setStatusBarColor(Color.rgb(8, 9, 12));
        window.setNavigationBarColor(Color.rgb(8, 9, 12));
        View decor = window.getDecorView();
        decor.setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        setImmersiveMode();
        // Keep the WebView instance alive when returning from Tailscale so playback state is not discarded.
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.stopLoading();
            webView.setWebChromeClient(null);
            webView.setWebViewClient(null);
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
