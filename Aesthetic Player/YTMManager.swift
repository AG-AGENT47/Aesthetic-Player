//
//  YTMManager.swift
//  Aesthetic Player
//
//  Created by Avyakt Garg on 11/01/26.
//


import SwiftUI
import WebKit

class YTMManager: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var title: String = "Not Playing"
    @Published var artist: String = "Waiting for YTM..."
    @Published var artworkURL: String = ""
    
    var webView: WKWebView!

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        
        // Use a persistent data store. This tells macOS to save cookies
        // to a specific 'session' on the hard drive.
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // This allows the app to remember the login even if the app is
        // deleted and re-installed, or moved to another Mac.
        let contentController = WKUserContentController()
        contentController.add(self, name: "observer")
        config.userContentController = contentController
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        
        // Use the Safari User Agent we discussed
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    
        // 2. Inject the JavaScript "Spy" once the page loads
        let spyScript = """
        function initObserver() {
            const target = document.querySelector('ytmusic-player-bar');
            if (!target) {
                setTimeout(initObserver, 1000);
                return;
            }

            const observer = new MutationObserver(() => {
                const title = document.querySelector('yt-formatted-string.title')?.innerText;
                
                // Get the full subtitle (e.g., "Rahat Fateh Ali Khan • Sanson Ki Mala • 2020")
                const subtitleRaw = document.querySelector('span.subtitle.style-scope.ytmusic-player-bar yt-formatted-string')?.innerText;
                
                // CLEANUP LOGIC:
                // Split by "•" and take the first part (The Artist)
                let artist = "Unknown Artist";
                if (subtitleRaw) {
                     artist = subtitleRaw.split('•')[0].trim();
                }

                const albumArtImg = document.querySelector('img.style-scope.ytmusic-player-bar');
                let artwork = albumArtImg ? albumArtImg.src.split('=')[0] + "=w1200-h1200-l100-rj" : "";
                
                if (title) {
                    window.webkit.messageHandlers.observer.postMessage({
                        title: title,
                        artist: artist, // Now contains ONLY the artist name
                        artwork: artwork
                    });
                }
            });
            
            observer.observe(target, { childList: true, subtree: true, characterData: true });
        }
        initObserver();
        """
        
        let script = WKUserScript(source: spyScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        
        webView.load(URLRequest(url: URL(string: "https://music.youtube.com")!))
    }

    // 3. This function "catches" the push from JavaScript
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "observer", let dict = message.body as? [String: String] {
            DispatchQueue.main.async {
                self.title = dict["title"] ?? ""
                self.artist = dict["artist"] ?? ""
                self.artworkURL = dict["artwork"] ?? ""
            }
        }
    }
}
