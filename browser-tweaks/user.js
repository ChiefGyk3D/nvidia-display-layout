// Floorp / Firefox Performance Tweaks - Reduce Frame Drops on NVIDIA GPUs
// These settings work identically in both Floorp and Firefox (they share the same engine).
// Optimized for NVIDIA proprietary drivers on X11 with mixed refresh rate monitors.
//
// Install locations:
//   Floorp:  ~/.floorp/<profile>/user.js
//   Firefox: ~/.mozilla/firefox/<profile>/user.js
//   Floorp (Flatpak):  ~/.var/app/one.ablaze.floorp/.floorp/<profile>/user.js
//   Firefox (Flatpak): ~/.var/app/org.mozilla.firefox/.mozilla/firefox/<profile>/user.js
//
// Or run: ./install-browser-tweaks.sh to auto-detect and install.

// === HARDWARE ACCELERATION (NVIDIA) ===
// Force enable hardware acceleration
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.enabled", true);
user_pref("gfx.canvas.accelerated", true);
user_pref("layers.acceleration.force-enabled", true);
user_pref("layers.gpu-process.enabled", true);
user_pref("layers.gpu-process.force-enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);

// NVIDIA-specific: Use EGL instead of GLX for better performance
user_pref("gfx.x11-egl.force-enabled", true);
user_pref("widget.dmabuf.force-enabled", true);

// === COMPOSITOR SETTINGS ===
// Improve frame pacing and reduce stuttering
user_pref("gfx.compositor.glcontext.opaque", true);
user_pref("gfx.vsync.compositor.unobserve-process-busy", false);
user_pref("gfx.webrender.compositor", true);
user_pref("gfx.webrender.compositor.force-enabled", true);

// === VSYNC & FRAME TIMING (Mixed Refresh Rate: 180Hz + 75Hz) ===
// Better vsync handling to reduce tearing and dropped frames
user_pref("gfx.vsync.force-disable-waitforvblank", false);
user_pref("layout.frame_rate", -1); // Auto-detect - IMPORTANT for mixed refresh rates!

// Reduce compositor latency for high refresh rate
user_pref("gfx.webrender.max-partial-present-rects", 1);
user_pref("gfx.webrender.batched-upload-threshold", 262144);

// Multi-monitor mixed refresh rate fixes
user_pref("widget.wayland.vsync.enabled", false); // X11 specific
user_pref("gfx.webrender.all.async-scene-builder", true);
user_pref("gfx.display.max-frame-rate", 180); // Cap at highest monitor

// === VIDEO DECODING (NVIDIA NVDEC) ===
// Offload decoding to GPU via NVDEC
user_pref("image.mem.decode_bytes_at_a_time", 65536);
user_pref("media.ffmpeg.vaapi.enabled", true); // Works with nvidia-vaapi-driver
user_pref("media.av1.enabled", true);
user_pref("media.mediasource.vp9.enabled", true);

// Enable RDD (Remote Data Decoder) process for hardware decode
user_pref("media.rdd-process.enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.rdd-vpx.enabled", true);

// NVIDIA NVDEC support
// Let the browser negotiate the decode pipeline — don't disable ffvpx
// as it's needed for pipeline fallback on newer Gecko versions
user_pref("media.ffvpx.enabled", true);
user_pref("media.navigator.mediadatadecoder_vpx_enabled", true);
user_pref("media.gpu-process-decoder", true);

// === CONTENT PROCESS OPTIMIZATION ===
// Adjust content processes (set based on your RAM - 8 is good for 16GB+)
user_pref("dom.ipc.processCount", 8);
user_pref("dom.ipc.processCount.webIsolated", 4);

// === SCROLLING SMOOTHNESS ===
// Reduce jank during scrolling
user_pref("apz.frame_delay.enabled", false);
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.msdPhysics.enabled", true);
user_pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 250);
user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 400);
user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 400);
user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 120);
user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 5000);

// === MEMORY CACHE ===
// Increase cache to reduce repainting
user_pref("browser.cache.memory.capacity", 524288); // 512MB
user_pref("browser.cache.memory.max_entry_size", 51200); // 50MB max per entry

// === REDUCE REPAINTS ===
// Minimize unnecessary repaints
user_pref("nglayout.initialpaint.delay", 0);
user_pref("nglayout.initialpaint.delay_in_oopif", 0);

// === DISABLE ANIMATIONS THAT CAUSE FRAME DROPS ===
// Comment these out if you prefer animations
// user_pref("toolkit.cosmeticAnimations.enabled", false);
// user_pref("ui.prefersReducedMotion", 1);

// === SESSION RESTORE OPTIMIZATION ===
// Reduce background work
user_pref("browser.sessionstore.interval", 30000); // Save session every 30s instead of 15s

// === TELEMETRY (reduces background CPU usage) ===
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
