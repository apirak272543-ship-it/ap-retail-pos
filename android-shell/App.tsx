import { StatusBar } from "expo-status-bar";
import { useCallback, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Linking,
  SafeAreaView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { WebView, type WebViewNavigation } from "react-native-webview";

const RETAIL_POS_URL = "https://apirak272543-ship-it.github.io/ap-retail-pos/";
const ALLOWED_HOSTS = new Set([
  "apirak272543-ship-it.github.io",
  "abtsctwfkgzciseppach.supabase.co",
]);

function isPermittedInAppNavigation(url: string) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" && ALLOWED_HOSTS.has(parsed.hostname);
  } catch {
    return false;
  }
}

function LoadingLayer({ label }: { label: string }) {
  return (
    <View accessibilityLiveRegion="polite" style={styles.loadingLayer}>
      <ActivityIndicator color="#2563EB" size="large" />
      <Text style={styles.loadingText}>{label}</Text>
    </View>
  );
}

export default function App() {
  const webViewRef = useRef<WebView>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [hasLoadError, setHasLoadError] = useState(false);

  const source = useMemo(() => ({ uri: RETAIL_POS_URL }), []);

  const handleNavigation = useCallback((request: WebViewNavigation) => {
    if (isPermittedInAppNavigation(request.url)) {
      return true;
    }

    void Linking.openURL(request.url).catch(() => undefined);
    return false;
  }, []);

  const retryLoading = useCallback(() => {
    setHasLoadError(false);
    setIsLoading(true);
    webViewRef.current?.reload();
  }, []);

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="dark" />
      <WebView
        ref={webViewRef}
        source={source}
        originWhitelist={["https://*"]}
        onShouldStartLoadWithRequest={handleNavigation}
        onLoadStart={() => {
          setIsLoading(true);
          setHasLoadError(false);
        }}
        onLoadEnd={() => setIsLoading(false)}
        onError={() => {
          setIsLoading(false);
          setHasLoadError(true);
        }}
        javaScriptEnabled
        domStorageEnabled
        sharedCookiesEnabled
        thirdPartyCookiesEnabled
        pullToRefreshEnabled
        startInLoadingState={false}
        allowsBackForwardNavigationGestures
        setSupportMultipleWindows={false}
        style={styles.webView}
      />

      {isLoading && !hasLoadError ? <LoadingLayer label="กำลังเปิด AP Retail POS" /> : null}

      {hasLoadError ? (
        <View accessibilityLiveRegion="assertive" style={styles.errorLayer}>
          <Text style={styles.errorTitle}>ยังเปิดระบบ POS ไม่ได้</Text>
          <Text style={styles.errorBody}>
            ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต แล้วลองใหม่อีกครั้ง
          </Text>
          <TouchableOpacity
            accessibilityLabel="ลองเปิดระบบ POS อีกครั้ง"
            activeOpacity={0.85}
            onPress={retryLoading}
            style={styles.retryButton}
          >
            <Text style={styles.retryLabel}>ลองใหม่</Text>
          </TouchableOpacity>
        </View>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: "#F7FAFF",
    flex: 1,
  },
  webView: {
    backgroundColor: "#F7FAFF",
    flex: 1,
  },
  loadingLayer: {
    alignItems: "center",
    backgroundColor: "#F7FAFF",
    flex: 1,
    gap: 14,
    justifyContent: "center",
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
  },
  loadingText: {
    color: "#365275",
    fontSize: 16,
    fontWeight: "600",
  },
  errorLayer: {
    alignItems: "center",
    backgroundColor: "#F7FAFF",
    flex: 1,
    justifyContent: "center",
    left: 0,
    paddingHorizontal: 28,
    position: "absolute",
    right: 0,
    top: 0,
  },
  errorTitle: {
    color: "#183153",
    fontSize: 22,
    fontWeight: "800",
    marginBottom: 10,
    textAlign: "center",
  },
  errorBody: {
    color: "#526B88",
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 24,
    textAlign: "center",
  },
  retryButton: {
    backgroundColor: "#2563EB",
    borderRadius: 14,
    minWidth: 132,
    paddingHorizontal: 22,
    paddingVertical: 13,
  },
  retryLabel: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "800",
    textAlign: "center",
  },
});
