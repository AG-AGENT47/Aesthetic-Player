import SwiftUI
import AppKit
import Darwin // Needed for dlopen/dlsym

// --- 1. The Dynamic Loader (No Linking Required) ---
// We define the shape of the C function we want to call
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void

class MediaRemoteLoader {
    // This loads the Private Framework manually when the app runs
    static func getNowPlayingInfo(completion: @escaping ([String: Any]) -> Void) {
        // 1. Open the framework explicitly
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        
        guard handle != nil else {
            print("Error: Could not load MediaRemote framework.")
            return
        }
        
        // 2. Find the symbol (function name)
        let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo")
        
        guard sym != nil else {
            print("Error: Could not find MRMediaRemoteGetNowPlayingInfo symbol.")
            return
        }
        
        // 3. Cast the symbol to a Swift function type
        let function = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        
        // 4. Call it
        function(DispatchQueue.main) { info in
            completion(info)
            // Optional: dlclose(handle) - usually we keep it open for performance
        }
    }
}

// --- 2. The Data Fetcher ---
// --- 2. The Data Fetcher (Anti-Flash Version) ---
class NowPlayingViewModel: ObservableObject {
    @Published var songTitle: String = "Waiting for Music..."
    @Published var artistName: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false
    
    private var timer: Timer?
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.fetchNowPlaying()
        }
    }
    
    func fetchNowPlaying() {
        MediaRemoteLoader.getNowPlayingInfo { info in
            DispatchQueue.main.async {
                // Update Title & Artist
                let newTitle = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? "No Song"
                let newArtist = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? "Unknown Artist"
                
                // Only update text if it changed (optimization)
                if self.songTitle != newTitle { self.songTitle = newTitle }
                if self.artistName != newArtist { self.artistName = newArtist }
                
                // Update Artwork efficiently to prevent flashing
                if let imageData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                    let newImage = NSImage(data: imageData)
                    // Only update if we actually got a valid image
                    if newImage != nil {
                        self.artwork = newImage
                    }
                }
                // NOTE: We intentionally DO NOT set self.artwork = nil if data is missing.
                // This keeps the last known album cover on screen until a new one replaces it.
                
                if let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double {
                    self.isPlaying = rate > 0
                }
            }
        }
    }
}

// --- 3a. The Isolated Vinyl Record Component (Drift-Fixed) ---
struct VinylRecordView: View {
    let artwork: NSImage?
    @State private var isSpinning = false
    
    var body: some View {
        ZStack {
            // LAYER 1: The Static "Platter"
            // This never moves. It is the anchor.
            Circle()
                .fill(Color.black)
                .frame(width: 350, height: 350)
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
            
            // LAYER 2: The Spinning Vinyl
            ZStack {
                // Shiny Texture
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [.black, .gray.opacity(0.3), .black]),
                            center: .center
                        )
                    )
                    .frame(width: 350, height: 350)
                
                // Grooves
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: 330 - CGFloat(i * 20), height: 330 - CGFloat(i * 20))
                }
                
                // Album Art
                if let art = artwork {
                    Image(nsImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 155, height: 155)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 155, height: 155)
                }
                
                // Spindle Hole
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 4, height: 4)
                    .offset(x: 2, y: 2)
            }
            // 1. Strict Frame
            .frame(width: 350, height: 350)
            // 2. Cut off invisible pixels
            .clipped()
            // 3. Rotation logic
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            // 4. ANIMATION FIREWALL
            // We tell SwiftUI: "Only apply this slow animation to the rotation value."
            .animation(
                isSpinning ? .linear(duration: 10).repeatForever(autoreverses: false) : .default,
                value: isSpinning
            )
        }
        // --- THE CRITICAL FIX ---
        // We delay the start by 0.5 seconds.
        // This gives the layout engine time to snap the disk to the center
        // BEFORE the animation system wakes up.
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSpinning = true
            }
        }
    }
}
//// --- 3a. The Isolated Vinyl Record Component (Wobble Fix) ---
//struct VinylRecordView: View {
//    let artwork: NSImage?
//    @State private var rotation: Double = 0
//    
//    var body: some View {
//        ZStack {
//            // LAYER 1: The Static "Platter" & Shadow
//            // This never moves. It anchors the disk to the screen.
//            Circle()
//                .fill(Color.black)
//                .frame(width: 350, height: 350)
//                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
//            
//            // LAYER 2: The Spinning Vinyl
//            // We use a strictly framed container to lock the rotation axis.
//            ZStack {
//                // The Shiny Vinyl Texture
//                Circle()
//                    .fill(
//                        AngularGradient(
//                            gradient: Gradient(colors: [.black, .gray.opacity(0.3), .black]),
//                            center: .center
//                        )
//                    )
//                    .frame(width: 350, height: 350)
//                
//                // The Grooves
//                ForEach(0..<3) { i in
//                    Circle()
//                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
//                        .frame(width: 330 - CGFloat(i * 20), height: 330 - CGFloat(i * 20))
//                }
//                
//                // Album Art (Center Label)
//                if let art = artwork {
//                    Image(nsImage: art)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 155, height: 155)
//                        .clipShape(Circle())
//                        .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
//                } else {
//                    Circle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(width: 155, height: 155)
//                }
//                
//                // Center Spindle Hole
//                ZStack {
//                    Circle()
//                        .fill(Color.black)
//                        .frame(width: 12, height: 12)
//                    
//                    // Highlight (Note: We keep this visually offset, but centered in layout)
//                    Circle()
//                        .fill(Color.white.opacity(0.2))
//                        .frame(width: 4, height: 4)
//                        .offset(x: 2, y: 2)
//                }
//            }
//            // CRITICAL FIX: Force the frame BEFORE rotation.
//            // This ensures the "Axis of Rotation" is exactly the center of this 350x350 box.
//            .frame(width: 350, height: 350, alignment: .center)
//            .rotationEffect(.degrees(rotation))
//            .onAppear {
//                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
//                    rotation = 360
//                }
//            }
//        }
//    }
//}



//// --- 3a. The Isolated Vinyl Record Component (Fixed) ---
//struct VinylRecordView: View {
//    let artwork: NSImage?
//    @State private var rotation: Double = 0
//    
//    var body: some View {
//        ZStack {
//            // LAYER 1: The Static "Platter" (Anchor)
//            // This stays still so the shadow doesn't wobble or spin.
//            Circle()
//                .fill(Color.black)
//                .frame(width: 350, height: 350)
//                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
//            
//            // LAYER 2: The Spinning Vinyl
//            ZStack {
//                // The Shiny Vinyl Texture
//                Circle()
//                    .fill(
//                        AngularGradient(
//                            gradient: Gradient(colors: [.black, .gray.opacity(0.3), .black]),
//                            center: .center
//                        )
//                    )
//                    .frame(width: 350, height: 350)
//                
//                // The Grooves
//                ForEach(0..<3) { i in
//                    Circle()
//                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
//                        .frame(width: 330 - CGFloat(i * 20), height: 330 - CGFloat(i * 20))
//                }
//                
//                // Album Art (Center Label)
//                if let art = artwork {
//                    Image(nsImage: art)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 155, height: 155)
//                        .clipShape(Circle())
//                        .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
//                } else {
//                    Circle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(width: 155, height: 155)
//                }
//                
//                // Center Spindle Hole
//                Circle()
//                    .fill(Color.black)
//                    .frame(width: 12, height: 12)
//                Circle()
//                    .fill(Color.white.opacity(0.2))
//                    .frame(width: 4, height: 4)
//                    .offset(x: 2, y: 2)
//            }
//            // Apply rotation ONLY to Layer 2 (The internal parts)
//            .rotationEffect(.degrees(rotation))
//            .onAppear {
//                // Smooth infinite rotation
//                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
//                    rotation = 360
//                }
//            }
//        }
//        // NOTE: We removed .drawingGroup() to fix the "Square Box" glitch.
//    }
//}

// --- 3b. The Main Interface ---
struct ContentView: View {
    @StateObject var vm = NowPlayingViewModel()
    
    var body: some View {
        ZStack {
            // LAYER 1: Background
            if let art = vm.artwork {
                GeometryReader { geo in
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 50)
                        .opacity(0.5)
                }
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // LAYER 2: Content
            VStack(spacing: 40) {
                
                // Use the Isolated Component here
                VinylRecordView(artwork: vm.artwork)
                
                // Text Info
                VStack(spacing: 12) {
                    Text(vm.songTitle)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .kerning(1.5)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        // This ID forces SwiftUI to treat text updates as instant snapshots
                        // rather than trying to animate the letters changing
                        .id("Title-\(vm.songTitle)")
                    
                    Text(vm.artistName.uppercased())
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .kerning(2.5)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                        .id("Artist-\(vm.artistName)")
                }
            }
            .padding(.bottom, 40)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

//// --- 3. The Aesthetic UI ---
//// --- 3. The Aesthetic UI (Fixes Layout & Scrolling) ---
//struct ContentView: View {
//    @StateObject var vm = NowPlayingViewModel()
//    @State private var rotation: Double = 0
//    
//    var body: some View {
//        ZStack {
//            // LAYER 1: Full Window Blurred Background
//            if let art = vm.artwork {
//                GeometryReader { geo in
//                    Image(nsImage: art)
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .frame(width: geo.size.width, height: geo.size.height)
//                        .blur(radius: 50)
//                        .opacity(0.5)
//                }
//                .ignoresSafeArea()
//            } else {
//                Color.black.ignoresSafeArea()
//            }
//            
//            // LAYER 2: The Content
//            VStack(spacing: 40) {
//                
//                // The Vinyl Record
//                ZStack {
//                    // Dark Vinyl Disc
//                    Circle()
//                        .fill(
//                            AngularGradient(
//                                gradient: Gradient(colors: [.black, .gray.opacity(0.3), .black]),
//                                center: .center
//                            )
//                        )
//                        .frame(width: 350, height: 350)
//                        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
//                    
//                    // The Grooves
//                    ForEach(0..<3) { i in
//                        Circle()
//                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
//                            .frame(width: 330 - CGFloat(i * 20), height: 330 - CGFloat(i * 20))
//                    }
//                    
//                    // Album Art (Center Label)
//                    if let art = vm.artwork {
//                        Image(nsImage: art)
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: 155, height: 155)
//                            .clipShape(Circle())
//                            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
//                    } else {
//                        Circle()
//                            .fill(Color.gray.opacity(0.2))
//                            .frame(width: 155, height: 155)
//                    }
//                    
//                    // Center Spindle Hole
//                    Circle()
//                        .fill(Color.black)
//                        .frame(width: 12, height: 12)
//                    Circle()
//                        .fill(Color.white.opacity(0.2))
//                        .frame(width: 4, height: 4)
//                        .offset(x: 2, y: 2)
//                }
//                // --- THE ANIMATION FIX ---
//                .rotationEffect(.degrees(rotation))
//                .onAppear {
//                    rotation = 360
//                }
//                // This strictly binds the animation to the 'rotation' value only.
//                // It prevents the animation from leaking to the text or window layout.
//                .animation(
//                    .linear(duration: 10).repeatForever(autoreverses: false),
//                    value: rotation
//                )
//                
//                // Text Info
//                VStack(spacing: 12) {
//                    Text(vm.songTitle)
//                        .font(.system(size: 32, weight: .bold, design: .default))
//                        .kerning(1.5)
//                        .foregroundColor(.white)
//                        .multilineTextAlignment(.center)
//                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
//                        .padding(.horizontal)
//                        .id("Title-\(vm.songTitle)") // Prevents text animation glitch
//                    
//                    Text(vm.artistName.uppercased())
//                        .font(.system(size: 18, weight: .medium, design: .monospaced))
//                        .kerning(2.5)
//                        .foregroundColor(.white.opacity(0.8))
//                        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
//                        .id("Artist-\(vm.artistName)")
//                }
//            }
//            .padding(.bottom, 40)
//        }
//        .frame(minWidth: 800, minHeight: 600)
//    }
//}
