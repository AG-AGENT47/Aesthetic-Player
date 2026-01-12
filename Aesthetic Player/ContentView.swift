//
//  ContentView.swift
//  Aesthetic Player
//
//  Created by Avyakt Garg on 11/01/26.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject var ytm = YTMManager()
    @State private var rotation: Double = 0
    @State private var showBrowser = true
    
    // New: To fix the rotation bug, we track if we are animating
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // --- 1. GLOBAL BACKGROUND ---
            AsyncImage(url: URL(string: ytm.artworkURL)) { img in
                img.resizable()
                    .scaledToFill()
                    .blur(radius: 60)
                    .opacity(0.4)
            } placeholder: {
                Color.black
            }
            .ignoresSafeArea()
            
            // --- 2. MAIN INTERFACE ---
            // GeometryReader is the key: It knows the EXACT screen size
            GeometryReader { geo in
                ZStack {
                    
                    // === LAYER A: VINYL PLAYER (Always Centered) ===
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // 1. The Record
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.gray.opacity(0.1), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: min(geo.size.width * 0.5, 300), height: min(geo.size.width * 0.5, 300)) // Responsive size
                                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                            
                            // Rotating Artwork
                            AsyncImage(url: URL(string: ytm.artworkURL)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: min(geo.size.width * 0.2, 120), height: min(geo.size.width * 0.2, 120))
                            .clipShape(Circle())
                            .rotationEffect(.degrees(rotation))
                            // BUG FIX: Ensure it rotates
                            .onChange(of: ytm.title) { _ in startRotation() }
                            .onAppear { startRotation() }
                            
                            // Pin
                            Circle().fill(.white.opacity(0.2)).frame(width: 8, height: 8)
                        }
                        
                        Spacer().frame(height: 40)
                        
                        // 2. Clean Metadata
                        Text(ytm.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .shadow(radius: 4)
                        
                        Text(ytm.artist) // This is now CLEAN (just artist name)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)

                        Spacer()
                        
                        // 3. Bottom Button (Pinned safely)
                        Button(action: { withAnimation { showBrowser = true } }) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Open Browser")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 50) // Safe padding from bottom edge
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(showBrowser ? 0 : 1) // Hide when browser is open
                    
                    
                    // === LAYER B: BROWSER OVERLAY (Full Screen) ===
                    if showBrowser {
                        ZStack(alignment: .top) {
                            // Background dimmer
                            Color.black.opacity(0.8).ignoresSafeArea()
                            
                            VStack(spacing: 0) {
                                // Top Bar
                                HStack {
                                    Text("YouTube Music")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button("Hide Browser") {
                                        withAnimation { showBrowser = false }
                                        startRotation() // Re-trigger rotation when returning
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                }
                                .padding()
                                .background(Color.black)
                                
                                // Browser - Takes ALL remaining space
                                WebViewContainer(webView: ytm.webView)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .transition(.opacity)
                        .zIndex(2) // Force on top
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600) // Force reasonable default size
    }
    
    // Helper function to handle the rotation bug
    func startRotation() {
        // Stop any existing animation
        withAnimation(.linear(duration: 0)) { rotation = 0 }
        
        // Restart it
        // We use a slight delay to ensure the view engine is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
    // This struct bridges the native AppKit WKWebView into the SwiftUI world
    struct WebViewContainer: NSViewRepresentable {
        // Specify exactly which type of NSView we are representing
        typealias NSViewType = WKWebView
        
        let webView: WKWebView
        
        // Required Method 1: Create the view
        func makeNSView(context: Context) -> WKWebView {
            return webView
        }
        
        // Required Method 2: Update the view (can be empty, but must exist)
        func updateNSView(_ nsView: WKWebView, context: Context) {
            // No update logic needed for now
        }
    }
